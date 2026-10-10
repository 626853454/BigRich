"""Original porcelain split / two-click seating cues. No recordings or samples."""
from pathlib import Path
import numpy as np,wave,json
R=Path(__file__).resolve().parent;sr=44100;rng=np.random.default_rng(1010);records=[]
for name,duration,land in [('reshape_open',.48,False),('reshape_land',.40,True)]:
 t=np.arange(round(sr*duration))/sr;x=np.zeros((len(t),2))
 for j,offset in enumerate([0,.095] if land else [0,.055,.11]):
  u=np.maximum(t-offset,0);env=(t>=offset)*np.minimum(u*1600,1)*np.exp(-u*(20 if land else 12))
  f=(1174.66 if land else 698.456)*([1,1.5,2][j]);phase=2*np.pi*(f*u+(0 if land else 120*u*u))
  noise=np.convolve(rng.normal(0,1,len(t)),np.ones(5)/5,mode='same')
  sound=(np.sin(phase)*.14+np.sin(phase*2.73)*.04+noise*(.095 if land else .035))*env
  x[:,j%2]+=sound;x[:,1-j%2]+=sound*.76
 x[-882:]*=np.linspace(1,0,882)[:,None]
 path=R/'game/assets/mahjong_night/show/audio'/f'{name}.wav'
 with wave.open(str(path),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes(np.round(x*32767).astype('<i2').tobytes())
 records.append({'file':path.name,'duration':duration,'peak':float(abs(x).max()),'source':'Original deterministic porcelain modes + filtered noise, no external samples.'})
(R/'reshape-audio-source.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(records))
