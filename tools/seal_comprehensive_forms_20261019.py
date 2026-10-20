from pathlib import Path
import hashlib,json,shutil,zipfile
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables/comprehensive_forms_20261019'
DEST=Path('C:/Users/23623/Desktop/NEW/最终表单')
names=['03_全项目美术资产总表_含已有素材_可分享.html','04_UI与功能界面表_可分享.html']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'delivery_manifest.json').read_text(encoding='utf-8'))
verified=json.loads((OUT/'form_verification.json').read_text(encoding='utf-8'))
assert verified['failed']==0
manifest.update(browser_verified=True,verification_checks=verified['passed'],vector_pose_guides=len(list((OUT/'pose_guides').glob('*.svg'))),sha256={n:sha(OUT/n) for n in names})
for n in names:assert sha(DEST/n)==manifest['sha256'][n]
(OUT/'delivery_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
archive=OUT/'NEURONS_完整美术表单_含已有素材_20261019.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n in names+['使用说明.txt','delivery_manifest.json','form_verification.json']:z.write(OUT/n,n)
 for p in (OUT/'data').glob('*.json'):
  if p.name!='comprehensive_assets.json':z.write(p,'审查与修订依据/'+p.name)
 for p in (OUT/'pose_guides').glob('*.svg'):z.write(p,'行走姿态参照/'+p.name)
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert len(z.namelist())==len(set(z.namelist()))
shutil.copy2(archive,DEST/archive.name)
assert sha(archive)==sha(DEST/archive.name)
print(json.dumps({'pages':names,'items':manifest['items'],'verified':verified['passed'],'zip_bytes':archive.stat().st_size,'sha256_zip':sha(archive),'game_unchanged':manifest['source_art_and_game_unchanged']},ensure_ascii=False))
