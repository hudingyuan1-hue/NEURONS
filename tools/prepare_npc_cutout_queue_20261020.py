"""Read-only selected-source queue and native-tool requests; no image editing."""
import hashlib
import json
import runpy
from collections import Counter
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/validation/asset_production_20261020/characters'
REGISTRY = ROOT / 'neurons/data/npc_visual_registry.json'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def prompt_for(asset):
    return (
        'Use case: background-extraction. Technical image edit, one existing game character sprite. '
        'The attached image is the exact edit target, not a loose style reference. '
        'Change only the empty gray/beige background to genuine PNG alpha transparency. '
        'Preserve the exact character identity, face, expression, hair silhouette, hair strands, '
        'skin colors, clothes and all small accessories, brushwork, body proportions, pose, '
        'view direction, original composition and canvas aspect ratio. '
        'Do not redraw, beautify, reinterpret, add animation or invent missing limbs/supports. '
        'Keep white/light clothes and shoes fully opaque; do not treat them as background. '
        'Keep intentional worn or held accessories already present, but add no new object. '
        'Remove only the background and external floor/drop shadow, with no halo or gray matte. '
        'Retain natural semi-transparent anti-aliased edge pixels and tiny hair details. '
        'No ground plane, no background color, no checkerboard graphic, no new shadow, '
        'no text or watermark. Output one clean full-body transparent RGBA sprite, '
        'keeping the source pose and its existing margins. '
        f'Asset identity for bookkeeping only: {asset["asset_id"]}; '
        f'authored state: {asset["state"]}; authored view: {asset["direction"]}. '
        'These labels do not request any visual change.'
    )


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    registry = json.loads(REGISTRY.read_text(encoding='utf8'))
    bindings = runpy.run_path(str(ROOT/'tools/build_npc_runtime_catalog.py'))['BINDINGS']
    early = {identity for ch in ['2','3'] for identity in bindings[ch].values()}
    requested_missing = sorted(early - registry['assets'].keys())
    records = []
    for key, item in registry['assets'].items():
        source = ROOT / item['selected_source']
        source_hash = sha(source)
        assert source_hash == item['selected_sha256'], f'Exact selected source changed: {key}'
        with Image.open(source) as image:
            existing_alpha = 'A' in image.getbands() and image.getchannel('A').getextrema()[0] == 0
        production = item.get('production_texture')
        production_file = ROOT/'neurons'/production.removeprefix('res://') if production else None
        prepared = bool(production_file and production_file.exists())
        if prepared:
            with Image.open(production_file) as image:
                assert image.mode == 'RGBA' and image.getchannel('A').getextrema()[0] == 0
        early_identity = item['identity_id'] in early
        is_mother = key == item['identity_id']
        is_back = 'BACK' in key
        priority = (0 if early_identity and is_mother else
                    1 if early_identity and is_back else
                    2 if item['state'] == 'altered' else
                    3 if is_mother else 4)
        status = 'prepared' if prepared else 'exact_alpha_copy_available' if existing_alpha else 'native_background_extraction_pending'
        request = OUT / (key+'_cutout_request.json')
        if not prepared and not request.exists():
            write(request, {'asset_id':key, 'source_path':item['selected_source'],
                            'source_sha256':source_hash, 'tool':'image_gen.imagegen',
                            'transparent_background':True, 'prompt':prompt_for(item),
                            'generated_path':None})
        records.append({'asset_id':key,'identity_id':item['identity_id'],
                        'state':item['state'],'direction':item['direction'],
                        'selected_source':item['selected_source'],'selected_sha256':source_hash,
                        'priority':priority,'status':status,'request':request.relative_to(ROOT).as_posix(),
                        'production_texture':production})
    records.sort(key=lambda x:(x['priority'],x['asset_id']))
    counts = dict(Counter(item['status'] for item in records))
    snapshot = {'captured_at':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
                'registry_components':len(records),'counts':counts,
                'missing_exact_early_normal_ids':requested_missing,
                'policy':'Selected exact hashes only. Existing alpha is copied without regeneration. Altered user revisions receive no aesthetic reevaluation. Prepared alpha is not motion/contact acceptance.',
                'records':records}
    write(OUT/'technical_cutout_queue.json', snapshot)
    print(json.dumps({'components':len(records),'counts':counts,'missing_ids':requested_missing,
                      'next':[item['asset_id'] for item in records if item['status']!='prepared'][:12]}))


if __name__ == '__main__':
    main()
