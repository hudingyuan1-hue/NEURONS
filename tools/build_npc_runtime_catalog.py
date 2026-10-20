"""Explicit identity bindings and technical texture metadata, never gameplay facts."""
import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
N = 'CHR_OTHER_NPCS_'
BINDINGS = {
    '1': {'father': N+'FATHER', 'mother': N+'MOTHER', 'dog': N+'DOG', 'cat': N+'CAT'},
    '2': {'guide': N+'N20', 'wheelchair': N+'N09', 'porter': N+'N03', 'doctor': N+'N33',
          'assistant': N+'N34', 'archivist': N+'N18', 'guard': N+'N42', 'nurse': N+'N07',
          'pharmacist': N+'N21', 'patient': N+'N41'},
    '3': {'ordinary_orderly': N+'N02', 'registration_nurse': N+'N04', 'doctor': N+'N36',
          'assistant': N+'N14', 'pharmacist': N+'N28', 'med_nurse': N+'N22', 'archivist': N+'N43',
          'guard': N+'N37', 'patient': N+'N41', 'head_nurse': N+'N05', 'porter': N+'N23',
          'transport_patient': N+'N10', 'postop_patient': N+'N11', 'informer': N+'N44',
          'therapist': N+'N38', 'speaker': N+'N24', 'isolation_orderly': N+'N15',
          'cleaner': N+'N29', 'corner_patient': N+'N08', 'supervisor': N+'N25', 'labor_patient': N+'N30'},
    '4': {'backward': N+'N06', 'stitched': N+'N31', 'blindfold': N+'N39', 'repeater': N+'N45',
          'misaligned': N+'N16', 'dual_head': N+'N35', 'twitch': N+'N13', 'faceless': N+'N27',
          'reverse': N+'N17', 'face_press': N+'N40', 'double_face': N+'N19'},
    'hidden': {'hunter': 'CHR_HUNTER'},
}


def main():
    registry = json.loads((ROOT/'neurons/data/npc_visual_registry.json').read_text(encoding='utf8'))
    for chapter, name in [('5', 'combat_chapter.json'), ('6', 'street_chapter.json')]:
        content = json.loads((ROOT/'neurons/data'/name).read_text(encoding='utf8'))
        BINDINGS[chapter] = {a['id']: a['identity_id'] for a in content['actors']}
    assets = {}
    for key, item in registry['assets'].items():
        path = item.get('production_texture')
        if not path:
            continue
        file = ROOT/'neurons'/path.removeprefix('res://')
        with Image.open(file) as source:
            assert source.mode == 'RGBA'
            alpha = source.getchannel('A')
            bounds = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
            assert bounds and alpha.getextrema()[0] == 0
            size = list(source.size)
        variant = next((v for v in item['variants'] if v['sha256'] == item['selected_sha256']), {})
        assets[key] = {
            'identity_id': item['identity_id'], 'state': item['state'],
            'direction': item['direction'], 'texture': path, 'canvas_px': size,
            'bbox_px': list(bounds), 'body_height_px': bounds[3]-bounds[1],
            'foot_anchor_px': item.get('production_ground_anchor_px', [(bounds[0]+bounds[2])*.5, bounds[3]]),
            'sha256': hashlib.sha256(file.read_bytes()).hexdigest(),
            'original_sha256': item['selected_sha256'], 'source_approval': item['source_approval'],
            'source_original_unchanged': True,
            'source_alpha_exact_copy': bool(variant.get('production_copy') == path),
            'render_ready': False,
            'motion_ready': False,
            'note': 'Prepared transparent source; binding/contact and motion must be verified separately. No aesthetic reassessment.',
        }
    target = ROOT/'neurons/data/npc_runtime_catalog.json'
    previous = json.loads(target.read_text(encoding='utf8')) if target.exists() else {}
    for key, previous_item in previous.get('assets', {}).items():
        if key not in assets or previous_item.get('sha256') != assets[key]['sha256']:
            continue
        for field in ['render_ready', 'motion_ready', 'foot_anchor_px', 'body_height_px', 'rig', 'action_bindings', 'evidence']:
            if field in previous_item:
                assets[key][field] = previous_item[field]
    result = {
        'schema': 1, 'enabled': previous.get('enabled', False),
        'policy': ['Exact stable role mapping, including distinct L2/L3 doctors, nurses and assistants.',
                   'No missing face or back view is invented from a different identity.',
                   'A numbered authored pose is not assumed to be animation frame order.',
                   'Prepared pixels are not automatically a completed motion or physical contact.',
                   'Revised altered drawings are used as delivered, without a new aesthetic review.'],
        'bindings': BINDINGS, 'assets': assets,
        'heights_m': {N+'FATHER': 1.78, N+'MOTHER': 1.62, N+'DOG': .70, N+'CAT': .48},
    }
    temporary = target.with_suffix('.json.writing')
    temporary.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
    temporary.replace(target)
    print(json.dumps({'role_bindings': sum(len(x) for x in BINDINGS.values()), 'transparent_components': len(assets),
                      'render_ready': sum(x['render_ready'] for x in assets.values()),
                      'source_registry_unchanged': True}))


if __name__ == '__main__':
    main()
