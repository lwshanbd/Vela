#!/usr/bin/env python3
"""Check shipping translations; optionally cross-check Xcode's extracted keys."""
import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Vela/Resources/Localizable.xcstrings'
TOKEN = re.compile(r'%(?:(\d+)\$)?(lld|ld|d|@|f|s)')


def placeholders(value):
    # Ignore escaped percent signs; preserve argument positions and types.
    return Counter((int(position) if position else i, kind)
                   for i, (position, kind) in enumerate(TOKEN.findall(value.replace('%%', '')), 1))


def units(node):
    if 'stringUnit' in node:
        yield node['stringUnit']
    for variants in node.get('variations', {}).values():
        for variant in variants.values():
            yield from units(variant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stringsdata', type=Path, help='Xcode Objects-normal/arm64 directory')
    args = parser.parse_args()
    catalog = json.loads(CATALOG.read_text())
    errors = []
    assert catalog['sourceLanguage'] == 'en'
    for key, entry in catalog['strings'].items():
        if entry.get('shouldTranslate') is False:
            continue
        for locale in ('en', 'zh-Hans'):
            localized = list(units(entry.get('localizations', {}).get(locale, {})))
            if not localized:
                errors.append(f'{locale}: missing translation for {key!r}')
            for unit in localized:
                if unit.get('state') != 'translated' or not unit.get('value'):
                    errors.append(f'{locale}: unfinished translation for {key!r}')
                if placeholders(key) != placeholders(unit.get('value', '')):
                    errors.append(f'{locale}: placeholder mismatch for {key!r}')
    for locale in ('en', 'zh-Hans'):
        permission = ROOT / f'Vela/Resources/{locale}.lproj/InfoPlist.strings'
        if '"NSBluetoothAlwaysUsageDescription" = "' not in permission.read_text():
            errors.append(f'{locale}: missing Bluetooth permission text')
    if args.stringsdata:
        extracted = list(args.stringsdata.glob('*.stringsdata'))
        if not extracted:
            errors.append(f'No compiler extraction files in {args.stringsdata}')
        for path in extracted:
            for entry in json.loads(path.read_text()).get('tables', {}).get('Localizable', []):
                if entry['key'] not in catalog['strings']:
                    errors.append(f'{path.name}: uncatalogued key {entry["key"]!r}')
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    count = sum(e.get('shouldTranslate') is not False for e in catalog['strings'].values())
    print(f'PASS: {count} bilingual entries, placeholders, permission strings'
          + (', and compiler-extracted key coverage' if args.stringsdata else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
