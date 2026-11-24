#!/usr/bin/env python3
"""Install the prepared screen agent without overwriting existing user files."""
from pathlib import Path
import os
import tomllib

SOURCE = Path(__file__).resolve().parent / 'screen.toml'
IOS = Path('/Users/jialishen/Coding/IOS')
PERSONAL = Path('/Users/jialishen/.codex/agents')


def install(ios=IOS, personal=PERSONAL):
    raw = SOURCE.read_bytes()
    config = tomllib.loads(raw.decode())
    assert config['name'] == 'screen' and config['description'] and config['developer_instructions']
    canonical = ios / '.codex/agents/screen.toml'
    package = ios / 'release-agents/screen.toml'
    entry = ios / 'screen'
    link = personal / 'screen.toml'
    entry_text = '# screen agent 任务入口\n\n' + config['developer_instructions'] + '\n'
    files = [(canonical, raw), (package, raw), (entry, entry_text.encode())]
    # Check all existing files before writing any installation targets.
    for path, contents in files:
        if path.exists() or path.is_symlink():
            if not path.is_file() or path.read_bytes() != contents:
                raise FileExistsError(f'Existing configuration differs; retained: {path}')
    if link.exists() or link.is_symlink():
        if not link.is_symlink() or os.readlink(link) != str(canonical):
            raise FileExistsError(f'Existing registration retained: {link}')
    for path, contents in files:
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            with path.open('xb') as file:
                file.write(contents)
    personal.mkdir(parents=True, exist_ok=True)
    if not link.is_symlink():
        link.symlink_to(canonical)
    for path in [canonical, package, entry, link]:
        print(path)
    return canonical, package, entry, link


if __name__ == '__main__':
    install()
