"""Original short target-crossing sting, compatible with the existing D-minor stems."""
from pathlib import Path
import numpy as np, wave, json
R=Path(__file__).resolve().parent;SR=44100;duration=.82
x=np.zeros((round(SR*duration),2));rng=np.random.default_rng(907)
for k,(offset,midi,amp) in enumerate([(0,62,.27),(.08,69,.20),(.16,74,.25),(.25,77,.21),(.32,81,.18)]):
 start=round(offset*SR);t=np.arange(len(x)-start)/SR;f=440*2**((midi-69)/12)
 attack=np.minimum(1,t*800);decay=np.exp(-t/(.22 if k<3 else .29))
 tone=np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*2*t)*np.exp(-t*12)+.06*np.sin(2*np.pi*f*2.76*t)*np.exp(-t*30)
 tone*=amp*attack*decay
 pan=(k-2)*.11;x[start:]+=tone[:,None]*np.sqrt(np.array([(1-pan)/2,(1+pan)/2]))
t=np.arange(len(x))/SR
# A low wooden impact anchors the porcelain notes; noise is short and filtered.
noise=rng.normal(0,1,len(x));noise=np.convolve(noise,np.ones(11)/11,mode='same')
body=(.15*np.sin(2*np.pi*(92*t+1.8*(1-np.exp(-t*20))))+.025*noise)*np.exp(-t*30)*np.minimum(t*1000,1)
x+=body[:,None];x-=x.mean(axis=0);x[:128]*=np.linspace(0,1,128)[:,None];x[-1764:]*=np.linspace(1,0,1764)[:,None]
x*=min(1,.65/max(np.max(np.abs(x)),1e-9))
target=R/'game/assets/mahjong_night/show/audio/breakthrough.wav'
with wave.open(str(target),'wb') as w:
 w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR);w.writeframes(np.round(x*32767).astype('<i2').tobytes())
report={'file':target.name,'duration':duration,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'source':'original additive/modal D-minor porcelain arpeggio and filtered wooden impact; no external samples'}
(R/'breakthrough-audio-source.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(report))
