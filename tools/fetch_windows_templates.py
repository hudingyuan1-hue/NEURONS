"""Fetch only official Windows x64 Godot 4.7.2 templates via verified ZIP ranges.

Run with --destination DIRECTORY. Does not edit a project or replace other versions.
The original ZIP CRC is checked by zipfile; EXE signatures must be checked before use.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import time
import zipfile

URL = ('https://downloads.godotengine.org/?version=4.7.2&flavor=stable'
       '&slug=export_templates.tpz&platform=templates')
NAMES = ['version.txt', 'windows_debug_x86_64.exe',
         'windows_debug_x86_64_console.exe', 'windows_release_x86_64.exe',
         'windows_release_x86_64_console.exe']


class OfficialZip(io.RawIOBase):
    def __init__(self, cache):
        self.url = URL
        self.cache = cache.resolve()
        self.cache.mkdir(parents=True, exist_ok=True)
        self.request_number = 0
        self.position = 0
        self.received = 0
        self.tail, self.length = self.get_range(None, 65536)
        self.tail_start = self.length - len(self.tail)

    def get_range(self, start, count):
        limit = f'bytes=-{count}' if start is None else f'bytes={start}-{start+count-1}'
        last = None
        for attempt in range(3):
            try:
                self.request_number += 1
                base = self.cache/str(self.request_number)
                header, body = base.with_suffix('.headers'), base.with_suffix('.bin')
                span = f'-{count}' if start is None else f'{start}-{start+count-1}'
                # curl uses the working system TLS/proxy setup, also used for
                # the official engine download; no shell string is evaluated.
                result = subprocess.run(['curl.exe', '-sS', '-L', '--fail',
                    '--connect-timeout', '12', '--max-time', '35', '--range', span,
                    '--max-filesize', str(count+1), '-D', str(header),
                    '-o', str(body), self.url], capture_output=True, text=True)
                if result.returncode:
                    raise RuntimeError(f'curl failed ({result.returncode})')
                headers = header.read_text(encoding='utf-8-sig')
                matches = re.findall(r'(?i)content-range:\s*bytes (\d+)-(\d+)/(\d+)', headers)
                if not matches:
                    raise RuntimeError('Server ignored Range; refusing full archive')
                lo, hi, total = map(int, matches[-1])
                data = body.read_bytes()
                if len(data) != count or hi-lo+1 != count or (start is not None and lo != start):
                    raise RuntimeError('Incomplete or unexpected ZIP range')
                redirects = re.findall(r'(?im)^location:\s*(https://[^\r\n]+)', headers)
                if redirects:
                    self.url = redirects[-1].strip()
                self.received += len(data)
                return data, total
            except Exception as error:
                last = error
                time.sleep(0.3*(attempt+1))
        raise RuntimeError(f'Cannot retrieve ZIP range {limit}: {last}')

    def seekable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = offset if whence == 0 else self.position+offset if whence == 1 else self.length+offset
        return self.position

    def tell(self):
        return self.position

    def read(self, size=-1):
        size = min(self.length-self.position, size if size >= 0 else self.length)
        if size <= 0:
            return b''
        result = []
        while size:
            count = min(size, 4*1024*1024)
            if self.position >= self.tail_start:
                data = self.tail[self.position-self.tail_start:self.position-self.tail_start+count]
            else:
                count = min(count, self.tail_start-self.position)
                data, total = self.get_range(self.position, count)
                if total != self.length:
                    raise RuntimeError('Archive changed during download')
            result.append(data)
            self.position += len(data)
            size -= len(data)
        return b''.join(result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    source = OfficialZip(args.destination/'download_cache')
    records = []
    with zipfile.ZipFile(source) as archive:
        for name in NAMES:
            content = archive.read('templates/'+name)  # CRC check before any file write.
            if name == 'version.txt' and content.decode().strip() != '4.7.2.stable':
                raise RuntimeError('Unexpected template version')
            target = args.destination/name
            if target.exists() and target.read_bytes() != content:
                raise RuntimeError(f'Refusing to replace different existing file: {target}')
            target.write_bytes(content)
            records.append({'filename': name, 'bytes': len(content),
                            'sha256': hashlib.sha256(content).hexdigest()})
            print('VERIFIED ZIP CRC', name, len(content), flush=True)
    report = {'source': URL, 'range_download_bytes': source.received,
              'full_archive_bytes': source.length, 'files': records}
    (args.destination/'download_record.json').write_text(
        json.dumps(report, indent=2), encoding='utf-8')
    print('WINDOWS_TEMPLATE_FETCH_OK', source.received, flush=True)


if __name__ == '__main__':
    main()
