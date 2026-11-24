#!/usr/bin/env python3
"""Add confirmed page-agent defaults without replacing existing task instructions."""
import argparse
import json
from pathlib import Path
import re
import tomllib

BLOCK = '''## 默认开发者与支持信息
开发者名称：Mobile Soft
支持邮箱：shenok.smth@gmail.com
以上由用户明确确认，作为本 iOS 工作区 page agent 的默认值，适用于当前及后续项目。生成支持页和隐私政策时直接使用，不再询问；仅在用户明确为某项目指定其他值时覆盖。'''

def add_defaults(text):
    marker = '## 默认开发者与支持信息'
    if marker in text:
        # Only update our dedicated section, preserving all other instructions.
        start = text.index(marker)
        end = text.find('\n## ', start + len(marker))
        return text[:start] + BLOCK + '\n' + (text[end:] if end >= 0 else '')
    return text.rstrip() + '\n\n' + BLOCK + '\n'

def update(path, dry_run=False):
    original = path.read_text()
    if path.suffix == '.toml':
        parsed = tomllib.loads(original)
        instructions = add_defaults(parsed['developer_instructions'])
        # The workspace uses a single-line TOML basic string for this field.
        # Preserve all unrelated settings and formatting.
        pattern = r'^developer_instructions\s*=\s*"(?:[^"\\\n]|\\.)*"\s*$'
        replacement = 'developer_instructions = ' + json.dumps(instructions, ensure_ascii=False)
        result, count = re.subn(pattern, lambda _: replacement, original, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f'Unsupported instruction string format; no file changed: {path}')
        assert tomllib.loads(result)['developer_instructions'] == instructions
    else:
        result = add_defaults(original)
    if not dry_run and result != original:
        path.write_text(result)
    print(('CHECKED ' if dry_run else 'UPDATED ') + str(path))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--workspace', type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    paths = [args.workspace / '.codex/agents/page.toml', args.workspace / 'page',
             args.workspace / 'release-agents/page.toml']
    for path in paths:
        if path.is_file(): update(path, args.dry_run)
    print('Developer: Mobile Soft; support: shenok.smth@gmail.com')

if __name__ == '__main__':
    main()
