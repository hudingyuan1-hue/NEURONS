"""Reproducible development playback candidates. Originals remain untouched.
No subjective listening or publication license acceptance is implied.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess, wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'DOCX/早期音乐素材/音频'
OUT=ROOT/'neurons/assets/audio/b1_development'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def inspect(p):
    with wave.open(str(p),'rb') as w:
        channels,rate,width,frames=w.getnchannels(),w.getframerate(),w.getsampwidth(),w.getnframes()
        raw=np.frombuffer(w.readframes(frames),np.uint8).reshape(-1,3).astype(np.int32)
    x=raw[:,0]+(raw[:,1]<<8)+(raw[:,2]<<16)
    x=np.where(x>=8388608,x-16777216,x)/8388608.0
    active=np.flatnonzero(np.abs(x)>10**(-55/20))
    return dict(sample_rate=rate,channels=channels,bits=width*8,duration=frames/rate,
                peak=float(np.max(np.abs(x))),rms=float(np.sqrt(np.mean(x*x))),
                leading_below_minus55_db_seconds=float(active[0]/channels/rate) if active.size else frames/rate)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--ffmpeg',required=True);a=ap.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    assets=[]
    originals=['MUS_MENU','MUS_ROOM','AMB_FAN','SFX_UI_CONFIRM','SFX_UI_BACK','SFX_UI_DENIED','SFX_DOOR_OPEN','SFX_DOOR_CLOSE']
    for id in originals:
        src=SRC/(id+'_v001.wav');music=id.startswith('MUS_') or id.startswith('AMB_')
        path=OUT/(id.lower()+'_dev_v001'+('.ogg' if music else '.wav'))
        args=[a.ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(src)]
        args+=['-c:a','libvorbis','-q:a','5'] if music else ['-c:a','pcm_s16le']
        if id.startswith('SFX_DOOR'):args+=['-ac','1']
        subprocess.run(args+[str(path)],check=True)
        assets.append(dict(id=id,stream='res://'+path.relative_to(ROOT/'neurons').as_posix(),
            channel='music' if id.startswith('MUS_') else 'ambience' if id.startswith('AMB_') else 'ui' if id.startswith('SFX_UI') else 'world',
            loop=False,source=src.relative_to(ROOT).as_posix(),source_sha256=digest(src),output_sha256=digest(path),
            license='用户提供；仅开发播放候选，作者/发布许可待核',status='未主观听验；仅链路验证',
            processing=dict(codec='vorbis-q5' if music else 'pcm_s16le',trim='none',channels='mono' if id.startswith('SFX_DOOR') else 'preserve',tool='tools/prepare_b1_audio.py'),analysis=inspect(src),loop_points='未听验；不默认无缝循环'))
    rate=48000;rng=np.random.default_rng(20261015)
    for id,kind,duration in [('SFX_FOOTSTEP','step',.22),('SFX_SEARCH_CLOTH','cloth',.32),('SFX_SEARCH_PAPER','paper',.6),('SFX_SKIN','scratch',.5),('SFX_GUT','gut',1.2),('SFX_DRAWER','wood',.4),('SFX_COLD','air',.7)]:
        n=int(rate*duration);t=np.arange(n)/rate;noise=rng.normal(0,1,n)
        smooth=np.convolve(noise,np.ones(24)/24,mode='same')
        env=np.sin(np.pi*np.arange(n)/(n-1))**2
        if kind=='step':x=(smooth*.6+np.sin(2*np.pi*72*t)*np.exp(-t*25))*.3*np.exp(-t*12)
        elif kind=='gut':x=(smooth+.3*np.sin(2*np.pi*(48*t+8*t*t)))*env*.22
        elif kind=='air':x=noise*env*.025
        elif kind=='paper':x=(noise-smooth)*env*(.5+.5*np.sin(2*np.pi*13*t))*.04
        elif kind=='scratch':x=(noise-smooth)*env*np.maximum(0,np.sin(2*np.pi*8*t))*.05
        elif kind=='wood':x=(smooth*.6+.18*np.sin(2*np.pi*(140*t-60*t*t)))*env*.18
        else:x=smooth*env*.25
        x=np.clip(x,-.95,.95)
        path=OUT/(id.lower()+'_synth_v001.wav')
        with wave.open(str(path),'wb') as w:
            w.setparams((1,2,rate,len(x),'NONE','not compressed'));w.writeframes((x*32767).astype('<i2').tobytes())
        assets.append(dict(id=id,stream='res://'+path.relative_to(ROOT/'neurons').as_posix(),channel='world',loop=False,
            source='tools/prepare_b1_audio.py',source_sha256=digest(Path(__file__)),output_sha256=digest(path),
            license='本项目Codex离线合成，无第三方录音；开发候选',status='未主观听验；材质区别需耳验',
            processing=dict(seed=20261015,kind=kind,duration=duration,rate=rate)))
    (ROOT/'neurons/data/audio_bindings.json').write_text(json.dumps(dict(schema=2,assets=assets,
        release_approved=False,listening_verified=False,contract='开发链路候选；原件/处理副本分开，来源待核，不代表音频完成'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(assets)} development bindings; not listening acceptance')

if __name__=='__main__':main()
