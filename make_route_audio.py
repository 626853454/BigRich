"""Three original build-family cues: bell/bamboo, warm furnace, paired strings."""
from pathlib import Path
import numpy as np,wave,json,math
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/show/audio';SR=44100
rng=np.random.default_rng(991037);report=[]
def tone(t,f,decay,harmonics):
 return sum(a*np.sin(2*np.pi*f*ratio*t)*np.exp(-t/(decay/math.sqrt(ratio))) for ratio,a in harmonics)*np.minimum(t*1300,1)
def add(d,start,f,length,amp,p,kind):
 t=np.arange(round(SR*length))/SR
 shape=([(1,.7),(2.76,.12),(5.4,.027)],.24) if kind=='bell' else ([(1,.67),(2,.16),(3,.055),(4,.019)],.24)
 x=tone(t,f,shape[1],shape[0])*amp*np.minimum((length-t)/.025,1)
 pos=round(start*SR);n=min(len(x),len(d)-pos)
 d[pos:pos+n]+=np.stack([x[:n]*math.sqrt((1-p)/2),x[:n]*math.sqrt((1+p)/2)],axis=1)
for name,duration in [('wind_score',.35),('coal_score',.31),('relay_score',.38),('tea_pour',.48),('tea_fill',.36)]:
 d=np.zeros((round(duration*SR),2),dtype=np.float64);t=np.arange(len(d))/SR
 if name=='wind_score':
  add(d,0,587.329,.32,.49,-.16,'bell');add(d,.048,880,.28,.22,.16,'bell')
  body=.19*np.sin(2*np.pi*221*t)*np.exp(-t*56)*np.minimum(t*1600,1);d+=body[:,None]
 elif name=='coal_score':
  add(d,0,146.832,.29,.61,0,'string');add(d,.02,293.665,.23,.32,.06,'bell')
  noise=np.convolve(rng.uniform(-1,1,len(t)),np.ones(15)/15,mode='same')
  d+=(noise*.17*np.exp(-t*55)*np.minimum(t*1700,1))[:,None]
 elif name=='relay_score':
  add(d,0,440,.30,.49,-.27,'string');add(d,.086,587.329,.27,.44,.27,'string')
 else:
  length=duration
  noise=np.convolve(rng.uniform(-1,1,len(t)),np.ones(21)/21,mode='same')
  water=noise*.20*np.sin(np.pi*t/length)**2
  water+=.075*np.sin(2*np.pi*(640*t+35*np.sin(t*11)))*np.sin(np.pi*t/length)**2*np.exp(-t*4)
  d+=water[:,None]
  for i,frequency in enumerate([659.25,783.991] if name=='tea_fill' else [523.25,392.0]):add(d,.025+i*.082,frequency,min(.22,length-.025-i*.082),.12,(-1 if i==0 else 1)*.18,'bell')
 d-=np.mean(d,axis=0,keepdims=True);fade=220;d[:fade]*=np.linspace(0,1,fade)[:,None];d[-fade:]*=np.linspace(1,0,fade)[:,None]
 peak=float(np.abs(d).max());d*=min(1,.56/max(peak,1e-9))
 with wave.open(str(O/(name+'.wav')),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes(np.round(d*32767).astype('<i2').tobytes())
 report.append({'name':name,'seconds':duration,'peak':float(np.abs(d).max()),'rms':float(np.sqrt((d*d).mean()))})
(R/'route-audio-sources.json').write_text(json.dumps({'source':'Original additive/modal synthesis; no external samples. Route-specific cues, not subjective hearing approval.','assets':report},indent=2),encoding='utf8')
print(json.dumps(report))
