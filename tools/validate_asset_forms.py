"""Check the production handoff for loss of IDs, fields, or alias targets."""
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'deliverables/NEURONS_2D_资产需求_20261015'
results={}
for kind,name,old_key in [('art','01_全游戏提示词表单.html','asset-data'),('audio','01_音频需求表.html','data')]:
    payload=json.loads((OUT/'data'/f'{kind}_requirements.json').read_text(encoding='utf8'))
    rows=payload['rows'];byid={r['id']:r for r in rows}
    old=(OUT/'history'/name).read_text(encoding='utf-8-sig')
    legacy=json.loads(re.search(r'<script[^>]*id="'+old_key+r'"[^>]*>([\s\S]*?)</script>',old)[1])
    assert len(byid)==len(rows),'duplicate stable ID'
    assert {r['id'] for r in legacy}<=set(byid),'legacy ID dropped'
    for r in rows:
        for f in ['id','name','description','category','scope','rooms','batch','quantity','spec','filename','prompt','requirement','source','proposal','pending','existing_paths','status','delivery','acceptance','reuse_scope']:
            assert f in r,(r['id'],f)
        assert r['description'] and r['acceptance'],r['id']
        assert len(r['prompt'])<=140,(r['id'],'prompt should remain concise')
        assert not {'triangles','topology','save_filename','form_filename'}&set(r),r['id']
        if r['alias_of']:assert r['alias_of'] in byid and r['alias_of']!=r['id'],r['id']
        if r['status']=='停用':assert r['quantity']=='0' and not r['prompt']
        if kind=='audio':
            for f in ['duration','loop','speaker','authorization','sound_layers','performance_notes']:assert f in r,(r['id'],f)
        if r['animation']:
            for f in ['directions','frames_per_direction','duration','loop','foot_anchor','hand_anchor','contact']:assert f in r['animation'],(r['id'],f)
    current=(OUT/name).read_text(encoding='utf8')
    embedded=json.loads(re.search(r'<script[^>]*id="requirements"[^>]*>([\s\S]*?)</script>',current)[1])
    assert embedded==payload,'HTML and JSON disagree'
    results[kind]={'rows':len(rows),'legacy_ids_retained':len(legacy),'description_present':len(rows),'max_prompt_chars':max(len(r['prompt']) for r in rows),'alias_records':sum(bool(r['alias_of']) for r in rows),'retired':sum(r['status']=='停用' for r in rows)}
dest=ROOT/'docs/validation/assets_20261015';dest.mkdir(parents=True,exist_ok=True)
(dest/'contract_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(results,ensure_ascii=False))
