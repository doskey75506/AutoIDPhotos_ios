#!/usr/bin/env python3
"""Copy only completed screenshot batches; never overwrite existing artwork."""
import json
from pathlib import Path

source = Path(__file__).resolve().parent
destination = Path('/Users/jialishen/Work/MobileSoft/Projects/AutoIDPhoto')
files = {}
for manifest in source.glob('Screenshots-Manifest-v*.json'):
    data = json.loads(manifest.read_text())
    if data.get('status') not in ('captured', 'partial') or not data.get('screenshots'):
        continue
    files[manifest.name] = manifest
    for screenshot in data['screenshots']:
        name = screenshot['file']
        if Path(name).name != name or not name.startswith('Screenshot-') or not name.endswith('.png'):
            raise ValueError(f'Unexpected screenshot filename: {name}')
        path = source / name
        if not path.is_file():
            raise FileNotFoundError(path)
        files[name] = path
if not files:
    raise SystemExit('尚无已完成的 PNG 截图，未复制阻碍记录或生成图片。')
for name, path in files.items():
    target = destination / name
    if target.exists() and target.read_bytes() != path.read_bytes():
        raise FileExistsError(f'Existing output retained: {target}')
destination.mkdir(parents=True, exist_ok=True)
for name, path in files.items():
    target = destination / name
    if not target.exists():
        with target.open('xb') as file:
            file.write(path.read_bytes())
    print(target)
