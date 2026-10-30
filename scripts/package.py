#!/usr/bin/env python3
"""Create a local source/sideload bundle. Never includes signing keys or credentials."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[1]

def main():
    app=ROOT/'build/GolfApp.prg'
    if not app.is_file():raise SystemExit('Build GolfApp.prg first.')
    archive=ROOT/'build/GolfApp-venu2.zip'
    paths=[ROOT/'README.md',ROOT/'manifest.xml',ROOT/'monkey.jungle',ROOT/'monkey-tests.jungle',ROOT/'.gitignore',app]
    for folder in ('source','tests','resources','scripts','data','docs'):
        paths.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '__pycache__' not in p.parts)
    excluded={'.pem','.der','.pyc'}
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED) as z:
        for p in sorted(set(paths)):
            if p.suffix in excluded:continue
            z.write(p,Path('GolfApp')/p.relative_to(ROOT))
    manifest={'target':'venu2','app':app.name,'appSha256':hashlib.sha256(app.read_bytes()).hexdigest(),'bundle':archive.name,'bundleSha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'status':'prototype; runtime and physical-device verification pending'}
    (ROOT/'build/delivery.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))

if __name__=='__main__':main()
