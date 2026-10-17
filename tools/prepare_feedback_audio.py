"""Add only missing event sounds; preserve every existing binding and source."""
from pathlib import Path
import hashlib,json,math,random,struct,wave
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'neurons/assets/audio/feedback_20261017'

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    path=ROOT/'neurons/data/audio_bindings.json'
    data=json.loads(path.read_text(encoding='utf-8'))
    existing={a['id'] for a in data['assets']}
    for ident,seconds in [('SFX_KEY',.30),('SFX_ITEM_HANDOFF',.20),('SFX_HIT',.24),('SFX_COMBAT_WINDUP',.38),('SFX_BED_ROLL',.65),('SFX_RACK_CONTACT',.36)]:
        if ident in existing:continue
        rate=48000;rng=random.Random(20261017);samples=[];low=0.0
        for i in range(int(rate*seconds)):
            t=i/rate;noise=rng.uniform(-1,1);low=.94*low+.06*noise
            attack=min(1,t/.006);tail=math.exp(-t*(20 if ident=='SFX_KEY' else 24))
            if ident=='SFX_KEY':v=(math.sin(2*math.pi*1567*t)+.4*math.sin(2*math.pi*2311*t))*.12
            elif ident=='SFX_HIT':v=(math.sin(2*math.pi*(70*t-35*t*t))*.20+low*.5)
            elif ident=='SFX_COMBAT_WINDUP':v=(noise-low)*.09*math.sin(math.pi*min(1,t/seconds))
            elif ident=='SFX_RACK_CONTACT':v=(math.sin(2*math.pi*630*t)*.08+math.sin(2*math.pi*1173*t)*.035+noise*.04)
            elif ident=='SFX_BED_ROLL':v=low*.65+math.sin(2*math.pi*93*t)*.045*(.6+.4*math.sin(2*math.pi*13*t))
            else:v=low*.5+math.sin(2*math.pi*160*t)*.055
            samples.append(int(max(-.8,min(.8,v*attack*tail))*32767))
        target=OUT/(ident.lower()+'_synth_v001.wav')
        with wave.open(str(target),'wb') as w:
            w.setparams((1,2,rate,len(samples),'NONE','not compressed'));w.writeframes(struct.pack('<'+'h'*len(samples),*samples))
        data['assets'].append(dict(id=ident,stream='res://'+target.relative_to(ROOT/'neurons').as_posix(),channel='world',loop=False,source='tools/prepare_feedback_audio.py',source_sha256=digest(Path(__file__)),output_sha256=digest(target),license='本项目离线合成，无第三方录音',status='开发候选；未主观听验',processing=dict(seed=20261017,rate=rate,duration=seconds)))
    source=ROOT/'DOCX/早期音乐素材/音频'
    for ident in ['SFX_UI_SAVE','SFX_UI_REWARD']:
        if ident in existing:continue
        original=source/(ident+'_v001.wav');target=OUT/(ident.lower()+'_dev_v001.wav')
        with wave.open(str(original),'rb') as w:
            channels,width,rate,n=w.getnchannels(),w.getsampwidth(),w.getframerate(),w.getnframes();raw=w.readframes(n)
        values=[]
        for frame in range(n):
            samples=[int.from_bytes(raw[(frame*channels+c)*width:(frame*channels+c+1)*width],'little',signed=True) for c in range(channels)]
            values.append(max(-32768,min(32767,int(sum(samples)/channels)/(2**(8*(width-2))))))
        with wave.open(str(target),'wb') as w:
            w.setparams((1,2,rate,n,'NONE','not compressed'));w.writeframes(struct.pack('<'+'h'*n,*map(int,values)))
        data['assets'].append(dict(id=ident,stream='res://'+target.relative_to(ROOT/'neurons').as_posix(),channel='ui',loop=False,source=original.relative_to(ROOT).as_posix(),source_sha256=digest(original),output_sha256=digest(target),license='用户提供；发布来源授权仍待核',status='保留原始时长，仅16bit单声道处理；未主观听验'))
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(len(data['assets']),'bindings; no existing source or binding overwritten')

if __name__=='__main__':main()
