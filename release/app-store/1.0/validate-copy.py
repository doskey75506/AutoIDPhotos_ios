#!/usr/bin/env python3
"""Validate the exact App Store text files without changing their content."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent
LIMITS = {'name': 30, 'subtitle': 30, 'promotional-text': 170, 'keywords': 100, 'description': 4000, 'whats-new': 4000}
report = {}
for locale in ['en-GB', 'zh-Hans']:
    report[locale] = {}
    for field, limit in LIMITS.items():
        text = (ROOT / locale / f'{field}.txt').read_text(encoding='utf-8')
        if field == 'whats-new':
            assert not text, f'{locale}: first-release What’s New must remain empty'
        else:
            assert text, f'{locale}/{field}: empty'
        if field == 'name':
            assert len(text) >= 2, f'{locale}: name too short'
        assert text == text.strip(), f'{locale}/{field}: unintended surrounding whitespace'
        assert not re.search(r'护照|签证|英国|passport|visa|\bUK\b', text, re.I), f'{locale}/{field}: excluded scenario'
        characters = len(text)
        utf8_bytes = len(text.encode('utf-8'))
        value = utf8_bytes if field == 'keywords' else characters
        assert value <= limit, f'{locale}/{field}: {value} exceeds {limit}'
        if field == 'keywords':
            words = text.split(',')
            assert all(len(word) > 2 for word in words), f'{locale}: keyword too short'
            assert len(words) == len(set(word.casefold() for word in words)), f'{locale}: repeated keywords'
            assert all(word == word.strip() for word in words), f'{locale}: spaces around separators'
        report[locale][field] = {
            'characters': characters,
            'utf8_bytes': utf8_bytes,
            'utf16_code_units': len(text.encode('utf-16-le')) // 2,
            'limit': limit,
            'limit_unit': 'UTF-8 bytes' if field == 'keywords' else 'characters',
            'status': 'not available for first release; empty intentionally' if field == 'whats-new' and not text else 'within limit',
        }
(ROOT / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(report, ensure_ascii=False, indent=2))
