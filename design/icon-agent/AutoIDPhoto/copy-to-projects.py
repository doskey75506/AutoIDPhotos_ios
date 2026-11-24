#!/usr/bin/env python3
"""Copy the completed icon set to MobileSoft without overwriting existing files."""
from pathlib import Path

source = Path(__file__).resolve().parent
destination = Path('/Users/jialishen/Work/MobileSoft/Projects/AutoIDPhoto')
names = ['AppIcon-Master-v2.png', 'AppIcon-1024-v2.png', 'AppIcon-Preview-128-v2.png', 'AppIcon-Prompt-v2.txt']
for name in names:
    if not (source / name).is_file():
        raise FileNotFoundError(source / name)
    target = destination / name
    if target.exists() and target.read_bytes() != (source / name).read_bytes():
        raise FileExistsError(f'Existing output retained: {target}')
destination.mkdir(parents=True, exist_ok=True)
for name in names:
    target = destination / name
    if not target.exists():
        with target.open('xb') as file:
            file.write((source / name).read_bytes())
    print(target)
