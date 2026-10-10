from pathlib import Path
import wave,math,struct,json
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/audio';O.mkdir(parents=True,exist_ok=True)
rate=44100
def bell(t,f,duration):
 return (math.sin(math.tau*f*t)*math.exp(-t*18)+.29*math.sin(math.tau*f*2.02*t)*math.exp(-t*31)+.09*math.sin(math.tau*f*4.08*t)*math.exp(-t*48))*min(t*600,1)*(1-min(max((t-duration+.018)/.018,0),1))
report=[]
for name,duration in [('chip',.105),('multiply',.22),('hu',.70)]:
 samples=[]
 for i in range(int(rate*duration)):
  t=i/rate
  if name=='chip':value=bell(t,740,duration)*.24
  elif name=='multiply':value=(bell(t,659,duration)+bell(max(0,t-.065),988,duration-.065)*.65 if t>=.065 else bell(t,659,duration))*.19
  else:
   value=sum(bell(t,f,duration)*a for f,a in [(130.81,.25),(261.63,.24),(392,.16),(523.25,.14),(783.99,.08)])
   value+=.09*math.sin(math.tau*(65*t+12*t*t))*math.exp(-t*10)
  samples.append(max(-.95,min(.95,value)))
 with wave.open(str(O/(name+'.wav')),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(struct.pack('<h',round(v*32767)) for v in samples))
 report.append({'file':name+'.wav','seconds':duration,'peak':max(abs(v) for v in samples),'source':'original additive synthesis; bounded chime, no external samples'})
(R/'audio-sources.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(report)
