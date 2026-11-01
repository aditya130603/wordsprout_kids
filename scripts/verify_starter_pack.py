#!/usr/bin/env python3
"""Require first-install PNG sequence assets in every release build.

The one-time 14 MB archive must be at assets/content/starter_pack.zip.
GitHub Actions can only publish a release that contains the supplied
52 animation sequences, with 00007 as the clear recognition still.
"""
import json
import sys
import zipfile
from pathlib import Path

p=Path('assets/content/starter_pack.zip')
if not p.is_file():
    print('ERROR: Missing assets/content/starter_pack.zip',file=sys.stderr)
    print('Upload the one-time WordSprout starter_pack.zip to that path in GitHub.',file=sys.stderr)
    sys.exit(1)

with zipfile.ZipFile(p) as archive:
    entries=set(archive.namelist())
    if 'words.json' not in entries:
        raise ValueError('words.json missing from bundled pack')
    data=json.loads(archive.read('words.json'))
    words=data['words']
    assert len(words)>=130, 'Expected A–Z starter curriculum'
    sequences=[w for w in words if len(w.get('animation_frames',[]))==8]
    assert len(sequences)==52, f'Expected 52 PNG sequences, found {len(sequences)}'
    assert len({w['id'] for w in words})==len(words), 'Duplicated IDs'
    for i,w in enumerate(words):
        if i<130 and w['letter']!=chr(65+i//5):
            raise ValueError('Starter order wrong for '+w['word'])
        if len(w['facts'])!=3:
            raise ValueError('Must have 3 facts: '+w['word'])
        if w['image'].startswith('media/') and w['image'] not in entries:
            raise ValueError('Missing '+w['image'])
        for frame in w.get('animation_frames',[]):
            if frame not in entries:
                raise ValueError('Missing '+frame)
        if w in sequences:
            last=w['animation_frames'][-1]
            if not last.endswith('00007.png'):
                raise ValueError('Wrong final frame: '+last)
            if archive.read(w['image'])!=archive.read(last):
                raise ValueError('Still does not match final frame: '+w['word'])
    print(f'PASS: {len(words)} words; {len(sequences)} sequences; PNG 00007 final still; {p.stat().st_size:,} bytes')
