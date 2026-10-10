"""Original two short invitation/earned-prize cues. No external recordings."""
from pathlib import Path
import numpy as np, wave, json, math
R=Path(__file__).resolve().parent;O=R/'game/assets/mahjong_night/show/audio';SR=44100
report=[]
for name,duration,notes in [('encore_accept',.70,[(0,62,.20),(.11,69,.22),(.25,74,.30)]),('encore_clear',1.02,[(0,62,.25),(.07,74,.22),(.15,77,.24),(.23,81,.28),(.36,86,.32)])]:
 x=np.zeros((round(SR*duration),2))
 for index,(offset,midi,amp) in enumerate(notes):
  n=min(round(SR*.59),len(x)-round(offset*SR));t=np.arange(n)/SR;f=440*2**((midi-69)/12)
  modal=(np.sin(2*np.pi*f*t)*np.exp(-t/0.20)+.13*np.sin(2*np.pi*f*2.756*t)*np.exp(-t/.07)+.04*np.sin(2*np.pi*f*5.4*t)*np.exp(-t/.04))
  modal*=amp*np.minimum(1,t*1000)*np.minimum(1,(n/SR-t)/.020)
  pan=(index%3-1)*.2;start=round(offset*SR)
  x[start:start+n]+=modal[:,None]*np.array([math.sqrt((1-pan)/2),math.sqrt((1+pan)/2)])
 # A soft wooden body on the actual seal/prize contact, bounded below bright notes.
 t=np.arange(len(x))/SR
 body=.13*np.sin(2*np.pi*(100*t+10*(1-np.exp(-t*22))))*np.exp(-t*28)*np.minimum(t*1000,1)
 x+=body[:,None];x-=x.mean(axis=0);x[:128]*=np.linspace(0,1,128)[:,None];x[-882:]*=np.linspace(1,0,882)[:,None]
 peak=float(np.max(np.abs(x)));x*=min(1,.64/max(peak,1e-9))
 with wave.open(str(O/(name+'.wav')),'wb') as out:
  out.setnchannels(2);out.setsampwidth(2);out.setframerate(SR);out.writeframes(np.round(x*32767).astype('<i2').tobytes())
 report.append({'file':name+'.wav','duration':duration,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'source':'original modal/additive porcelain notes and wooden transient; D-minor compatible; no external samples'})
(R/'encore-audio-sources.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report))
