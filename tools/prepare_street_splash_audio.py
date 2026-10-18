"""One project-owned, offline transient for the actual liquid-release event."""
from pathlib import Path
import hashlib,io,json,math,random,struct,wave
ROOT=Path(__file__).resolve().parents[1]
def digest(data):return hashlib.sha256(data).hexdigest()
def main():
 rate=48000;seconds=.28;rng=random.Random(2026101801);low=0.0;values=[]
 for i in range(int(rate*seconds)):
  t=i/rate;noise=rng.uniform(-1,1);low=.87*low+.13*noise
  envelope=min(1,t/.003)*math.exp(-t*15)*min(1,(seconds-t)/.03)
  wet=(noise-low)*.36+low*.7
  for start,hz in [(0.012,930),(0.047,650),(0.092,480)]:
   dt=t-start
   if dt>=0:wet+=.14*math.sin(2*math.pi*(hz*dt-1200*dt*dt))*math.exp(-dt*70)
  values.append(wet*envelope)
 peak=max(map(abs,values));gain=.25/peak;pcm=[round(v*gain*32767) for v in values]
 memory=io.BytesIO()
 with wave.open(memory,'wb') as f:f.setparams((1,2,rate,len(pcm),'NONE','not compressed'));f.writeframes(struct.pack('<'+'h'*len(pcm),*pcm))
 target=ROOT/'neurons/assets/audio/street_20261018/sfx_splash_synth_v001.wav';target.parent.mkdir(exist_ok=True)
 raw=memory.getvalue()
 if target.exists():assert target.read_bytes()==raw,'Preserve existing version; use a new filename for different PCM.'
 else:target.write_bytes(raw)
 path=ROOT/'neurons/data/audio_bindings.json';bindings=json.loads(path.read_text(encoding='utf-8-sig'));ident='SFX_SPLASH'
 rms=math.sqrt(sum((v/32768)**2 for v in pcm)/len(pcm));first=next(i for i,v in enumerate(pcm) if abs(v/32768)>10**(-55/20))
 entry=dict(id=ident,stream='res://'+target.relative_to(ROOT/'neurons').as_posix(),channel='world',loop=False,source='tools/prepare_street_splash_audio.py',source_sha256=digest(Path(__file__).read_bytes()),output_sha256=digest(raw),license='本项目离线合成；无第三方录音/付费服务',status='普通泼洒短音开发候选；未主观听验/最终混音',processing=dict(seed=2026101801,rate=rate,duration=seconds,channels=1,bits=16,peak_db=20*math.log10(.25),rms_db=20*math.log10(rms),leading_below_minus55_db_seconds=first/rate),usage_contexts=['actual_street_pharmacist_release'])
 old=next((v for v in bindings['assets'] if v['id']==ident),None)
 if old is None:bindings['assets'].append(entry)
 else:assert old==entry,'Preserve existing binding.'
 path.write_text(json.dumps(bindings,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'id':ident,'file':str(target),'peak_db':entry['processing']['peak_db'],'rms_db':entry['processing']['rms_db'],'leading_seconds':first/rate,'total_assets':len(bindings['assets'])}))
if __name__=='__main__':main()
