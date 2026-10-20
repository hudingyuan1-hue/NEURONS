"""Register one native imagegen cutout, preserving source and generated pixels."""
import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    temporary = path.with_suffix(path.suffix + '.writing')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('request', type=Path)
    args = parser.parse_args()
    request_path = args.request.resolve()
    request = json.loads(request_path.read_text(encoding='utf-8'))
    registry_path = ROOT / 'neurons/data/npc_visual_registry.json'
    registry = json.loads(registry_path.read_text(encoding='utf-8'))
    asset = registry['assets'][request['asset_id']]
    source = ROOT / request['source_path']
    assert sha(source) == asset['selected_sha256'], 'Request must use the selected exact source'
    generated = Path(request['generated_path'])
    target_dir = ROOT / 'neurons/assets/production/characters' / asset['identity_id']
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / (request['asset_id'] + '_cutout_' + sha(generated)[:12] + '.png')
    if target.exists():
        assert sha(target) == sha(generated), 'Never replace a different output'
    else:
        shutil.copy2(generated, target)
    with Image.open(target) as image:
        assert image.mode == 'RGBA', 'Opaque source is not a transparent delivery'
        alpha = image.getchannel('A')
        extrema = alpha.getextrema()
        assert extrema[0] == 0 and extrema[1] >= 250
        histogram = alpha.histogram()
        bbox = alpha.point(lambda a: 255 if a >= 8 else 0).getbbox()
        assert bbox and min(bbox[0], bbox[1]) > 0 and bbox[2] < image.width and bbox[3] < image.height
        size = list(image.size)
        fraction = histogram[0] / (image.width * image.height)
        assert fraction > .20
    texture = 'res://' + target.relative_to(ROOT / 'neurons').as_posix()
    result = {
        **request,
        'registered_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
        'source_sha256': sha(source),
        'output_sha256': sha(target),
        'production_texture': texture,
        'pixel_size': size,
        'alpha_bbox': list(bbox),
        'alpha_bbox_threshold': 8,
        'transparent_fraction': fraction,
        'ground_anchor_px': [round((bbox[0] + bbox[2]) * .5, 2), bbox[3]],
        'source_original_unchanged': True,
        'generated_pixels_unchanged': True,
        'identity_view_pose_technical_comparison': 'checked; no aesthetic reassessment',
        'runtime_binding_enabled': False,
        'status': 'transparent_source_prepared_pending_runtime_contact_and_motion',
    }
    result_path = request_path.with_name(request_path.stem.replace('_request', '_result') + '.json')
    write(result_path, result)
    asset.update(
        production_texture=texture, production_sha256=result['output_sha256'],
        production_pixel_size=size, production_alpha_bbox=list(bbox),
        production_ground_anchor_px=result['ground_anchor_px'],
        production_provenance_path=result_path.relative_to(ROOT).as_posix(),
        technical_state=result['status'],
    )
    write(registry_path, registry)
    print(json.dumps({'asset_id': request['asset_id'], 'texture': texture, 'alpha_bbox': bbox}, ensure_ascii=False))


if __name__ == '__main__':
    main()
