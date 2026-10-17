"""Apply only the user's selected audio2 delivery; preserve all original WAVs.

Intake sources are retained under DOCX, never imported as runtime assets.
The archive's sole changed confirmation WAV retains its original filename;
the processed replacement is explicitly named _new and provenance is recorded.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'DOCX/早期音乐素材/音频2'
OUT = ROOT / 'neurons/assets/audio/audio2_20261017'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ffmpeg', required=True)
    ap.add_argument('--include-confirm', action='store_true',
                    help='Bind the updated archive confirmation as a separate _new runtime copy.')
    args = ap.parse_args()
    path = ROOT / 'neurons/data/audio_bindings.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    lookup = {entry['id']: entry for entry in data['assets']}
    OUT.mkdir(parents=True, exist_ok=True)
    deliveries = [
        ('MUS_HOSPITAL', 'MUS_HOSPITAL_v001.wav', 'mus_hospital_v001.ogg', 0,
         ['hospital_exploration', 'asylum_exploration', 'cortex_exploration', 'deep_exploration']),
        ('MUS_END', 'MUS_ENDING_E2_v001.wav', 'mus_ending_e2_v001.ogg', -1,
         ['ending_E2', 'ending_E3', 'origin_planet_epilogue']),
        ('MUS_DANGER', 'MUS_DANGER_v001.wav', None, 0,
         ['cortex_battle', 'deep_chase', 'street_existing', 'hidden_street_existing']),
    ]
    if args.include_confirm:
        deliveries.append(('SFX_UI_CONFIRM', 'SFX_UI_CONFIRM_v001.wav',
                           'sfx_ui_confirm_v001_new.wav', -1, ['ui_confirm']))
    for ident, name, runtime_name, gain_db, contexts in deliveries:
        original = SOURCE / name
        assert original.is_file(), original
        previous = lookup.get(ident, {})
        if runtime_name is None:
            # This delivery's danger WAV is byte-identical to the previous
            # original. Reuse its already imported runtime, not another encode.
            assert previous['source_sha256'] == digest(original)
            runtime = ROOT / 'neurons' / previous['stream'].removeprefix('res://')
            assert digest(runtime) == previous['output_sha256']
            processing = dict(previous['processing'])
            processing['reuse'] = 'New delivery WAV equals prior source SHA256; existing processed asset retained.'
        else:
            runtime = OUT / runtime_name
            command = [args.ffmpeg, '-v', 'error', '-nostdin', '-y', '-i', str(original)]
            if gain_db:
                command += ['-af', f'volume={gain_db}dB']
            command += ['-c:a', 'libvorbis', '-q:a', '5'] if ident.startswith('MUS_') else ['-c:a', 'pcm_s16le']
            subprocess.run(command + [str(runtime)], check=True)
            processing = dict(codec='vorbis-q5' if ident.startswith('MUS_') else 'pcm_s16le',
                              trim='none', channels='preserve', gain_db=gain_db,
                              tool='tools/prepare_audio2_delivery.py')
        entry = dict(id=ident, stream='res://' + runtime.relative_to(ROOT / 'neurons').as_posix(),
                     channel='music' if ident.startswith('MUS_') else 'ui', loop=False,
                     source=original.relative_to(ROOT).as_posix(), source_sha256=digest(original),
                     output_sha256=digest(runtime), license='用户提供并指定用途；作者及发布授权信息沿原记录待核',
                     status='已按用户指定绑定；未主观听验/最终混音',
                     processing=processing, usage_contexts=contexts,
                     loop_points='保持原非循环；未确认无缝接缝，不强行循环')
        if ident == 'SFX_UI_CONFIRM':
            entry['source_filename_note'] = '用户明确确认：音频2.zip内同名SFX_UI_CONFIRM_v001.wav就是新版；运行副本另存为_new。'
        if previous:
            history = previous.get('history', []).copy()
            if previous.get('source_sha256') != entry['source_sha256'] or previous.get('stream') != entry['stream']:
                history.append({k: v for k, v in previous.items() if k != 'history'})
            if history:
                entry['history'] = history
            data['assets'][data['assets'].index(previous)] = entry
        else:
            data['assets'].append(entry)
        lookup[ident] = entry
    data['last_delivery'] = dict(source='音频2.zip', scope='2026-10-17 user-selected music and confirmation only',
                                 confirm_replacement_applied=args.include_confirm)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Applied: ' + ', '.join(item[0] for item in deliveries))


if __name__ == '__main__':
    main()
