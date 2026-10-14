"""Read-only source extraction. Copies only extracted review intermediates to tmp."""
from pathlib import Path
from zipfile import ZipFile
from lxml import etree
from pypdf import PdfReader
import json, hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'tmp' / 'source_review'
OUT.mkdir(parents=True, exist_ok=True)
sources = [Path(r'C:/Users/23623/Desktop') / (n + '.docx') for n in ['游玩体验 需求','人物','关卡 周目 环境']]
sources += list(Path(r'C:/Users/23623/Desktop/OTS/OTS.STUDY/OTS游戏开发 策划 视觉/视觉').glob('*.pdf'))
ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
manifest=[]
for src in sources:
    dst=OUT/src.stem
    dst.mkdir(exist_ok=True)
    lines=[]
    images=[]
    if src.suffix=='.docx':
        with ZipFile(src) as z:
            root=etree.fromstring(z.read('word/document.xml'))
            body=root.find('w:body',ns)
            for i, el in enumerate(body):
                if el.tag.endswith('}p'):
                    txt=''.join(el.xpath('.//w:t/text()',namespaces=ns))
                    if txt: lines.append(f'B{i:04d} P {txt}')
                elif el.tag.endswith('}tbl'):
                    for j,row in enumerate(el.findall('w:tr',ns)):
                        cells=[' / '.join(''.join(p.xpath('.//w:t/text()',namespaces=ns)) for p in c.findall('.//w:p',ns)) for c in row.findall('w:tc',ns)]
                        lines.append(f'B{i:04d} T{j:03d} '+ ' | '.join(cells))
            for name in z.namelist():
                if name.startswith('word/media/'):
                    image=dst/Path(name).name
                    image.write_bytes(z.read(name)); images.append(image.name)
            (dst/'document.xml').write_bytes(z.read('word/document.xml'))
    else:
        pdf=PdfReader(src)
        for i,p in enumerate(pdf.pages):
            lines.append(f'PAGE {i+1}\n{p.extract_text()}')
    (dst/'text.txt').write_text('\n'.join(lines),encoding='utf-8')
    manifest.append({'file':str(src),'sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'lines':len(lines),'chars':sum(map(len,lines)),'images':images,'extracted':str(dst)})
(OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest,ensure_ascii=False,indent=2))
