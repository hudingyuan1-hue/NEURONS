"""Short wrap crossfades for sustained playback; original audio is read-only.

This is reproducible processing of delivered recordings, not new music and not
subjective listening approval. The once-only cue() path keeps its original.
"""
from pathlib import Path
import argparse, hashlib, json, math, subprocess, wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'neurons/assets/audio/loops_20261019'
OVERLAP={'MUS_HOSPITAL':.20,'MUS_DANGER':.20,'AMB_FAN':.12}

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def read_pcm(path):
 with wave.open(str(path),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();width=w.getsampwidth();data=w.readframes(w.getnframes())
 if width==3:
  b=np.frombuffer(data,np.uint8).reshape(-1,3).astype(np.int32)
  x=b[:,0]|b[:,1]<<8|b[:,2]<<16
  x=np.where(x&0x800000,x-0x1000000,x).astype(np.float64)/8388608
 elif width==2:x=np.frombuffer(data,'<i2').astype(np.float64)/32768
 else:raise ValueError('Unsupported PCM width '+str(width))
 return x.reshape(-1,channels),rate,channels

def metrics(x,rate):
 db=lambda v:round(20*math.log10(max(float(v),1e-12)),3)
 active=np.flatnonzero(np.max(np.abs(x),axis=1)>10**(-55/20));n=int(rate*.05)
 return {'duration_s':round(len(x)/rate,6),'leading_below_minus55_s':round(int(active[0])/rate,6) if len(active) else len(x)/rate,'trailing_below_minus55_s':round((len(x)-int(active[-1])-1)/rate,6) if len(active) else len(x)/rate,'head_50ms_rms_dbfs':db(np.sqrt(np.mean(x[:n]**2))),'tail_50ms_rms_dbfs':db(np.sqrt(np.mean(x[-n:]**2))),'wrap_jump_peak':round(float(np.max(np.abs(x[-1]-x[0]))),9),'wrap_jump_dbfs':db(np.max(np.abs(x[-1]-x[0]))),'peak_dbfs':db(np.max(np.abs(x)))}

def main(ffmpeg):
 bindings=json.loads((ROOT/'neurons/data/audio_bindings.json').read_text(encoding='utf-8-sig'))
 assets={a['id']:a for a in bindings['assets']};rows=[];OUT.mkdir(parents=True,exist_ok=True)
 for id,overlap in OVERLAP.items():
  entry=assets[id];source=ROOT/entry['source'];before=digest(source)
  if before!=entry['source_sha256']:raise RuntimeError('Source delivery hash mismatch: '+id)
  x,rate,channels=read_pcm(source);n=round(rate*overlap)
  # Keep the recording interior and blend the last n samples into its first
  # n samples. The loop seam then joins adjacent original samples n-1 -> n.
  # Convex cosine weights avoid added gain/limiting and preserve channel phase.
  t=(.5-.5*np.cos(np.linspace(0,np.pi,n)))[:,None]
  bridge=x[-n:]*(1-t)+x[:n]*t
  y=np.concatenate((x[n:-n],bridge),axis=0).astype('<f4')
  path=OUT/(id+'_loop.ogg')
  cmd=[ffmpeg,'-hide_banner','-loglevel','error','-y','-f','f32le','-ar',str(rate),'-ac',str(channels),'-i','pipe:0','-map_metadata','-1','-c:a','libvorbis','-q:a','5','-fflags','+bitexact','-flags:a','+bitexact',str(path)]
  subprocess.run(cmd,input=y.tobytes(),check=True)
  decoded=subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','pipe:1'],check=True,stdout=subprocess.PIPE).stdout
  actual=np.frombuffer(decoded,'<f4').reshape(-1,channels)
  if digest(source)!=before:raise RuntimeError('Original source changed during processing')
  rows.append({'id':id,'stream':'res://'+path.relative_to(ROOT/'neurons').as_posix(),'source':entry['source'],'source_sha256':before,'output_sha256':digest(path),'overlap_s':overlap,'source_analysis':metrics(x,rate),'processed_pcm_analysis':metrics(y,rate),'decoded_ogg_analysis':metrics(actual,rate),'processing':'Cosine convex tail-to-head overlap. Recording interior and channel count retained; duration shortens only by overlap, no full musical phrase removed. Original binding and once-only stream unchanged.'})
 data={'schema':1,'tool':'tools/build_audio_loops_20261019.py','tool_sha256':digest(Path(__file__)),'ffmpeg':subprocess.run([ffmpeg,'-version'],stdout=subprocess.PIPE,text=True,check=True).stdout.splitlines()[0],'variants':rows,'listening_verified':False,'release_approved':False,'scope':'Sustained-only technical loop variants for three delivered recordings. No new manual music order; no claim of seamless musical phrasing or final mixing.'}
 (ROOT/'neurons/data/audio_loop_variants.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({'variants':[{k:r[k] for k in ['id','overlap_s','output_sha256','decoded_ogg_analysis']} for r in rows]},ensure_ascii=True))

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--ffmpeg',default='ffmpeg');main(p.parse_args().ffmpeg)
