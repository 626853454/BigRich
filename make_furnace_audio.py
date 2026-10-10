"""Original ascending bronze ember cue, no external recordings."""
from pathlib import Path
import numpy as np, wave, json
R=Path(__file__).resolve().parent; sr=44100;t=np.arange(round(sr*.62))/sr
rng=np.random.default_rng(731)
noise=rng.normal(0,1,len(t));noise=np.convolve(noise,np.ones(19)/19,mode='same')
envelope=np.minimum(t*45,1)*np.exp(-t*8)*np.minimum((.62-t)*90,1)
phase=2*np.pi*(146.832*t+32*t*t)
body=(np.sin(phase)*.31+np.sin(phase*2.41)*.07+noise*.16)*envelope
ping=np.sin(2*np.pi*587.33*t)*.09*np.exp(-t*10)*np.minimum(t*1000,1)
x=np.stack([body+ping,np.roll(body,11)+ping],axis=1);x[:128]*=np.linspace(0,1,128)[:,None];x[-882:]*=np.linspace(1,0,882)[:,None]
path=R/'game/assets/mahjong_night/show/audio/furnace_charge.wav'
with wave.open(str(path),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes(np.round(x*32767).astype('<i2').tobytes())
(R/'furnace-audio-source.json').write_text(json.dumps({'file':path.name,'duration':.62,'peak':float(abs(x).max()),'source':'Original deterministic filtered noise + swept bronze modes, authored here, no external sample.'},indent=2),encoding='utf8')
print(path.name)
