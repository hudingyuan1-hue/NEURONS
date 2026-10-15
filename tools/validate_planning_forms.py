"""Validate the planning deliverables without importing or running Godot."""
from pathlib import Path
import collections
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'deliverables/NEURONS_2D_资产需求_20261015/data'
H=D.parent/'history/before_planning_20261015'
checks=[]
def check(name,condition):
    checks.append({'name':name,'passed':bool(condition)})
    if not condition:raise AssertionError(name)

all_groups={}
for kind in ['art','audio']:
    current=json.loads((D/f'{kind}_requirements.json').read_text('utf-8'))
    old=json.loads((H/f'data/{kind}_requirements.json').read_text('utf-8'))
    rows=current['rows'];groups=current['groups'];ids=[r['id'] for r in rows];gids=[g['id'] for g in groups]
    all_groups.update({g['id']:g for g in groups})
    check(kind+' stable leaf IDs unchanged',ids==[r['id'] for r in old['rows']])
    check(kind+' IDs globally unique',len(set(ids+gids))==len(ids)+len(gids))
    flat=[i for g in groups for i in g['children']]
    check(kind+' each leaf assigned exactly once',collections.Counter(flat)==collections.Counter(ids))
    check(kind+' aliases resolve',all(not r.get('alias_of') or r['alias_of'] in ids for r in rows))
    check(kind+' all source paths exist',all((ROOT/p).is_file() for r in rows for p in r.get('existing_paths',[])))
    check(kind+' ownership method and progress explicit',all(g.get('owner') and g.get('method') and g.get('status') for g in groups))
    check(kind+' human delivery fields complete',all(all(g.get(k) for k in ['id','name','scope','description','quantity','batch','filename','prompt','spec_id','source','validation']) for g in groups if g['owner']=='我们'))
    check(kind+' common specs resolve',all(g['spec_id'] in current['common_specs'] for g in groups))
    check(kind+' copied prompts short',all(len(current['common_specs'][g['spec_id']]['prompt']+'\n'+g['prompt'])<350 for g in groups))
    check(kind+' prompts contain no engine/file instructions',not any(re.search(r'保存|导出|Godot|Tripo|GLB|拓扑|面数|蒙皮|绑定|上传',g['prompt'],re.I) for g in groups if g['owner']=='我们'))
    check(kind+' original filled file/license/notes retained',all(all(r.get(k,'')==o.get(k,'') for k in ['file','license','notes']) for r,o in zip(rows,old['rows'])))
    check(kind+' original completion status retained',all(r['status']==o['status'] for r,o in zip(rows,old['rows'])))
    if kind=='audio':
        check('original scripts and random alternatives retained',all(r.get('original_text','')==o.get('original_text','') for r,o in zip(rows,old['rows'])))
        check('human audio only music',all(g['spec_id']=='MUSIC' for g in groups if g['owner']=='我们'))
        check('all SFX/ambience assigned Codex',all(r['owner']=='Codex' for r in rows if r['category'] in ['音效','环境','角色非语言']))
    else:
        check('five retired forms not restored',sum(r['status']=='停用' and 'CHR_PLAYER_01_05_' in r['id'] for r in rows)==5)
        check('UI/common effects Codex',all(r['owner']=='Codex' for r in rows if r['id'].startswith(('SYS_','UI_SKILL_','FX_','UI_ICONS_','UI_GLYPH_'))))
    html=(D.parent/('01_全游戏提示词表单.html' if kind=='art' else '01_音频需求表.html')).read_text('utf-8')
    embedded=json.loads(re.search(r'<script id="requirements" type="application/json">(.*?)</script>',html,re.S)[1])
    check(kind+' HTML exactly matches requirement JSON',embedded==current)
    check(kind+' self-contained offline',not re.search(r'<script[^>]+src=|<link[^>]+href="https',html))

plan=json.loads((D/'production_plan.json').read_text('utf-8'))
check('event asset refs resolve',all(i in all_groups for e in plan['events'] for i in e['assets']))
check('room refs resolve',all(r['asset_group'] in all_groups for r in plan['rooms']))
check('45 distinct Street identities',len(plan['identities'])==len({n['identity_id'] for n in plan['identities']})==45)
check('12 skills unique',len(plan['skills'])==len({s['id'] for s in plan['skills']})==12)
check('150 source-driven search points',collections.Counter(p['level'] for p in plan['search_points'])=={'L1':11,'L2':32,'L3':45,'L4':62})
check('batch dependencies valid',all(d in {b['id'] for b in plan['batches']} for b in plan['batches'] for d in b['depends']))
for s in plan['sources']:
    check('source hash unchanged '+s['path'],hashlib.sha256((ROOT/s['path']).read_bytes()).hexdigest()==s['sha256'])
limits={Path(s['path']).name:s['paragraphs'] for s in plan['sources']}
limits_by_tag=dict(zip(['S1','S2','S3','S4','R1','体验','人物','环境','纠错','Doctor'],[s['paragraphs'] for s in plan['sources']]))
check('event paragraph ranges valid',all(not (m:=re.fullmatch(r'(S[1-4]|R1|体验):P(\d+)–(\d+)',e['source'])) or 1<=int(m[2])<=int(m[3])<=limits_by_tag[m[1]] for e in plan['events']))
cue=json.loads((D/'dialogue_cues.json').read_text('utf-8'))['cues']
check('script cue IDs unique',len(cue)==len({c['id'] for c in cue}))
check('progress JSON unchanged', (D/'progress.json').read_bytes()==(H/'data/progress.json').read_bytes())
hist=json.loads((H/'manifest.json').read_text('utf-8'))
check('previous versions immutable',all(hashlib.sha256((H/p).read_bytes()).hexdigest()==h for p,h in hist.items()))
before=json.loads((ROOT/'docs/validation/planning_20261015/runtime_before.json').read_text('utf-8'))
after={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'neurons').rglob('*') if p.is_file() and '.godot' not in p.parts}
check('runtime sources/scenes/assets/config unchanged this turn',before==after)
out=ROOT/'docs/validation/planning_20261015'
(out/'validation.json').write_text(json.dumps({'checks':checks,'passed':len(checks),'failed':0,'runtime_file_count':len(after),'runtime_unchanged':True},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'passed':len(checks),'failed':0,'runtime_files_unchanged':len(after)},ensure_ascii=False))
