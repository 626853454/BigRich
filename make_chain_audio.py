from pathlib import Path
import numpy as np,wave,json
R=Path(__file__).resolve().parent
sr=44100;t=np.arange(round(sr*.68))/sr;x=np.zeros((len(t),2));rng=np.random.default_rng(1011)
for j,(offset,freq) in enumerate([(0,523.251),(.085,783.991),(.17,1046.502)]):
 u=np.maximum(0,t-offset);env=(t>=offset)*np.minimum(u*1200,1)*np.exp(-u*(10+j*2))
 noise=np.convolve(rng.normal(0,1,len(t)),np.ones(7)/7,mode='same')
 signal=(.16*np.sin(2*np.pi*freq*u)+.055*np.sin(2*np.pi*freq*2.71*u)+.032*noise)*env
 x[:,j%2]+=signal;x[:,1-j%2]+=signal*.75
x[-882:]*=np.linspace(1,0,882)[:,None]
p=R/'game/assets/mahjong_night/show/audio/chain_land.wav'
with wave.open(str(p),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes(np.round(x*32767).astype('<i2').tobytes())
metadata={'file':p.name,'seconds':.68,'peak':float(abs(x).max()),'source':'Original authored modal porcelain chord with filtered noise, no external samples; synchronized to physical secondgroup landing.'}
(R/'chain-audio-source.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf8')
print(metadata)
