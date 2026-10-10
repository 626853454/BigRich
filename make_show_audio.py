"""Original deterministic modal percussion and four-bar score. No external samples.
SFX are deliberately short; quiet music has no extra voices and wraps its decay tails.
"""
from pathlib import Path
import numpy as np, math,wave,json
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/show/audio';O.mkdir(parents=True,exist_ok=True)
SR=44100;rng=np.random.default_rng(1009);report=[]
def modal(t,f,decay=.22,bright=.18):
 return (np.sin(2*np.pi*f*t)*np.exp(-t/decay)+bright*np.sin(2*np.pi*f*2.756*t)*np.exp(-t/(decay*.40))+.085*np.sin(2*np.pi*f*5.401*t)*np.exp(-t/(decay*.20)))*np.minimum(t*900,1)
def pluck(t,f,decay=.42):
 v=sum((.62/(k*k))*np.sin(2*np.pi*f*k*t+.035*np.exp(-t*20)*k)*np.exp(-t/(decay/(k**.35))) for k in range(1,6))
 return v*np.minimum(t*1100,1)
def pad(t,f):return (np.sin(2*np.pi*f*t)+.22*np.sin(2*np.pi*f*2*t))*.09
def pan(x,p):return np.stack([x*math.sqrt((1-p)/2),x*math.sqrt((1+p)/2)],axis=1)
def empty(seconds):return np.zeros((round(SR*seconds),2),np.float64)
def note(dst,offset,midi,duration,amp=.4,p=0,kind='pluck',wrap=False):
 n=round(SR*duration);t=np.arange(n)/SR;freq=440*2**((midi-69)/12)
 x=(pluck(t,freq) if kind=='pluck' else modal(t,freq,decay=.30))*amp
 x*=np.minimum((duration-t)/.018,1);st=pan(x,p);start=round(offset*SR)
 if wrap:np.add.at(dst,(np.arange(n)+start)%len(dst),st)
 elif start<len(dst):dst[start:min(start+n,len(dst))]+=st[:max(0,min(n,len(dst)-start))]
def write(name,data,limit=.64,folder=O):
 peak=float(np.max(np.abs(data)));data=data*min(1,limit/max(peak,1e-9));data-=np.mean(data,axis=0,keepdims=True)
 # Short cross-fades remove DC/end cuts for one-shots; loop tails are wrapped instead.
 if not name.startswith('music_'):
  fade=min(512,len(data)//4);data[:fade]*=np.linspace(0,1,fade)[:,None];data[-fade:]*=np.linspace(1,0,fade)[:,None]
 pcm=np.round(np.clip(data,-.98,.98)*32767).astype('<i2')
 with wave.open(str(folder/(name+'.wav')),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
 report.append({'file':name+'.wav','seconds':len(data)/SR,'peak':float(np.max(np.abs(data))),'rms':float(np.sqrt(np.mean(data*data))),'source':'original modal/additive synthesis and authored notes; no external samples'})
def ceramic(name,duration,weight=1):
 t=np.arange(round(duration*SR))/SR;noise=rng.uniform(-1,1,len(t));body=.40*np.sin(2*np.pi*(175*t+10*(1-np.exp(-t*60))))*np.exp(-t*38)
 click=.15*noise*np.exp(-t*220)+.25*modal(t,1820,.033,.24)+.10*modal(t,2780,.024,.12)
 write(name,pan((body+click)*weight,0))
ceramic('tile_pick',.13,.57);ceramic('tile_land',.22,1);ceramic('chip',.095,.40)
for name,notes,spacing,duration,amp in [
 ('group_land',[62,69,74],.055,.47,.47),('reveal',[62,67,69],.075,.52,.32),
 ('lamp',[74,77,81,86],.090,.91,.48),('multiply',[74,81],.044,.25,.39),
 ('repeat',[69,69,81],.070,.36,.34),('total',[62,69,74],.027,.36,.46),
 ('hu',[50,62,65,69,74,81,86],.048,1.22,.55),
 ('overkill',[50,57,62,69,74,77,81,86],.063,1.58,.51),
 ('loss',[69,65,62],.12,.74,.27),('purchase',[74,81,86],.067,.51,.34),
 ('charge',[62,69,74,81],.078,.58,.35),('select',[74],0,.075,.16)]:
 d=empty(duration)
 for i,n in enumerate(notes):note(d,i*spacing,n,min(.55,duration-i*spacing),amp,(i%3-1)*.16,'modal')
 if name in ['hu','overkill']:
  t=np.arange(len(d))/SR;d+=pan(.18*np.sin(2*np.pi*(53*t+8*(1-np.exp(-t*8))))*np.exp(-t*9),0)
 write(name,d)
for name,up in [('recall',True),('relay',False)]:
 d=empty(.46);t=np.arange(len(d))/SR;noise=rng.uniform(-1,1,len(t));filtered=np.convolve(noise,np.ones(9)/9,mode='same')
 d+=pan(filtered*.16*np.sin(np.pi*t/.46)**2, -.22 if up else .22)
 note(d,.04,69 if up else 74,.36,.28,-.18,'modal');note(d,.15,81 if up else 77,.28,.25,.18,'modal');write(name,d)
# 16-beat, 84BPM loop: restrained celesta/koto-like minor pentatonic with warm bass.
B=60/84;duration=16*B;calm=empty(duration);groove=empty(duration)
chords=[[50,57,62,65,69],[46,53,58,62,65],[48,55,60,65,67],[50,57,62,65,69]]
melody=[74,None,77,81,None,79,77,None,74,72,None,69,72,None,74,None]
for bar,chord in enumerate(chords):
 for j,midi in enumerate(chord):note(calm,bar*4*B+j*.10,midi,2.6,.18 if j==0 else .085,(j-2)*.12,'pluck',True)
 for beat in [0,2]:note(groove,(bar*4+beat)*B,chord[0]-12,.7,.3,0,'pluck',True)
for i,midi in enumerate(melody):
 if midi is not None:note(calm,i*B+.03,midi,.82,.14,math.sin(i)*.30,'pluck',True)
for beat in range(32):
 n=round(SR*.075);t=np.arange(n)/SR;noise=rng.uniform(-1,1,n);x=np.convolve(noise,np.ones(4)/4,mode='same')*.028*np.exp(-t*55)*np.minimum(t*1200,1)
 np.add.at(groove,(np.arange(n)+round(beat*.5*B*SR))%len(groove),pan(x,(-1 if beat%2 else 1)*.22))
write('music_calm',calm,.40);write('music_groove',groove,.40)
(R/'show-audio-sources.json').write_text(json.dumps({'sample_rate':SR,'composition':'original four-bar D-minor pentatonic / 84BPM; wrapped note tails','assets':report},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'assets':len(report),'max_peak':max(x['peak'] for x in report),'total_seconds':sum(x['seconds'] for x in report)}))
