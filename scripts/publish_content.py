#!/usr/bin/env python3
"""Publish a validated DATA-ONLY WordSprout content pack.

Run: python3 scripts/publish_content.py ./edited_pack ./public/wordsprout
Input contains words.json and optional media/... PNGs. Never ships code.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from zipfile import ZipFile, ZIP_DEFLATED

SAFE = re.compile(r"^(words[.]json|media/[a-z0-9_-]+/(still|frame_[0-9]{5})[.]png)$")
ID = re.compile(r"^[a-z0-9_]+$")

def publish(source: Path, output: Path):
    source = source.resolve()
    data = json.loads((source / "words.json").read_text(encoding="utf-8"))
    if data.get("schema_version") != 1:
        raise ValueError("schema_version must be 1")
    words = data.get("words")
    if not isinstance(words, list) or not (130 <= len(words) <= 1000):
        raise ValueError("Expected between 130 and 1000 words")
    seen = set()
    for i, w in enumerate(words):
        if not ID.fullmatch(w["id"]) or w["id"] in seen:
            raise ValueError("Duplicate or unsafe word ID")
        seen.add(w["id"])
        if i < 130 and w["letter"] != chr(65+i//5):
            raise ValueError("First 130 starter words must keep A-Z positions")
        if len(w["facts"]) != 3 or not all(isinstance(f,str) and f.strip() for f in w["facts"]):
            raise ValueError("All words need three facts")
        image = w["image"]
        if image.startswith("media/") and not (source/image).is_file():
            raise ValueError("Missing picture: "+image)
        for frame in w.get("animation_frames",[]):
            if not (source/frame).is_file():
                raise ValueError("Missing frame: "+frame)

    version = data.get("content_version")
    if not isinstance(version,str) or not re.fullmatch(r"[a-zA-Z0-9._-]{1,64}",version):
        raise ValueError("Unsafe content_version")
    output.mkdir(parents=True, exist_ok=True)
    archive_path = output / "wordsprout_pack.zip"
    size = 0
    with ZipFile(archive_path,"w",ZIP_DEFLATED,compresslevel=6) as archive:
        for f in sorted(source.rglob("*")):
            if not f.is_file():
                continue
            relative = f.relative_to(source).as_posix()
            if not SAFE.fullmatch(relative):
                raise ValueError("Unsupported content file "+relative)
            if f.stat().st_size > 2*1024*1024:
                raise ValueError("Individual media file is too large "+relative)
            size += f.stat().st_size
            if size > 110*1024*1024:
                raise ValueError("Uncompressed pack is too large")
            archive.write(f,relative)
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    data = {
        "schema_version":1,
        "content_version":version,
        "pack_url":"wordsprout_pack.zip",
        "size_bytes":archive_path.stat().st_size,
        "sha256":digest,
    }
    (output/"manifest.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf8")
    print("Ready:",output)
    print("Size:",data["size_bytes"],"SHA256:",digest)
    print("Upload manifest.json and wordsprout_pack.zip to the same HTTPS directory.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input",type=Path,help="Folder with words.json and media files")
    parser.add_argument("output",type=Path,help="Public HTTPS directory staging folder")
    args = parser.parse_args()
    publish(args.input,args.output)
