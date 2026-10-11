"""Original paired score impacts and a rising completed-wind chord.

No external recordings. Deterministic modal/additive synthesis, bounded peak,
stereo 44.1kHz. The two fire cues are separate to match real score installments.
"""
from pathlib import Path
import numpy as np
import wave,json
R=Path(__file__).resolve().parent
O=R/'game/assets/mahjong_night/show/audio'
SR=44100
rng=np.random.default_rng(20261011)
report=[]
def note(buf,offset,midi,amp,decay,pan=0):
    begin=round(SR*offset);t=np.arange(len(buf)-begin)/SR
    freq=440*2**((midi-69)/12)
    envelope=np.minimum(t/.004,1)*np.exp(-t/decay)
    signal=(np.sin(2*np.pi*freq*t)+.13*np.sin(2*np.pi*freq*2*t)*np.exp(-t*7)+.035*np.sin(2*np.pi*freq*2.72*t)*np.exp(-t*22))*envelope*amp
    buf[begin:]+=signal[:,None]*np.sqrt([(1-pan)/2,(1+pan)/2])
for name,duration in [('build_wind_finish',.88),('build_fire_first',.43),('build_fire_finish',.76)]:
    buf=np.zeros((round(SR*duration),2));t=np.arange(len(buf))/SR
    if name=='build_wind_finish':
        for offset,midi,amp in [(0,62,.30),(.075,69,.26),(.15,74,.29),(.22,77,.22),(.27,81,.15)]:
            note(buf,offset,midi,amp,.22,(offset/.27-.5)*.5)
        note(buf,0,50,.16,.16)
    else:
        final=name=='build_fire_finish'
        note(buf,0,38 if final else 50,.43 if final else .34,.13)
        note(buf,.015,62,.24,.18)
        if final:
            note(buf,.044,69,.24,.25,-.22);note(buf,.08,74,.24,.29,.22)
        noise=np.convolve(rng.normal(0,1,len(t)),np.ones(19)/19,mode='same')
        body=.055*noise*np.exp(-t*55)*np.minimum(t/.002,1)
        buf+=body[:,None]
    buf-=buf.mean(axis=0)
    fade=round(.022*SR);buf[:128]*=np.linspace(0,1,128)[:,None];buf[-fade:]*=np.linspace(1,0,fade)[:,None]
    buf*=min(1,.66/max(np.abs(buf).max(),1e-9))
    with wave.open(str(O/(name+'.wav')),'wb') as f:
        f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes(np.round(buf*32767).astype('<i2').tobytes())
    report.append({'name':name,'seconds':duration,'peak':float(np.abs(buf).max()),'rms':float(np.sqrt(np.mean(buf*buf)))})
(R/'welcome-build-audio-source.json').write_text(json.dumps({'source':'Original deterministic modal/additive synthesis. No external samples; measurements do not constitute human hearing approval.','assets':report},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report))
