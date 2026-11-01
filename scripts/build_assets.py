#!/usr/bin/env python3
"""Create all illustrated word assets before a Flutter build.

Standard subjects: Twemoji SVG artwork, CC BY 4.0, jdecked/twemoji.
Less-common concepts: hand-authored WordSprout vectors.
The app never downloads artwork at runtime.
"""
from pathlib import Path
import hashlib
import json
import re
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "assets" / "content" / "words_v1.json"
TARGET = ROOT / "assets" / "words"
TARGET.mkdir(parents=True, exist_ok=True)
BASE = "https://raw.githubusercontent.com/jdecked/twemoji/main/assets/svg/"
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">'
FOOT = '</svg>'
BACKGROUND = '<circle cx="128" cy="128" r="116" fill="#F3F9E5"/><ellipse cx="128" cy="223" rx="95" ry="10" fill="#DEDDBF"/>'
CUSTOM = {
 "igloo": """<path d="M29 203 A99 99 0 0 1 227 203Z" fill="#EAF7FF" stroke="#83BBD7" stroke-width="6"/>
<path d="M128 104v99M49 158h158M75 119l22 37M182 118l-23 40" stroke="#A1C9DB" stroke-width="4" fill="none"/>
<path d="M95 206v-41a33 33 0 0 1 66 0v41" fill="#5E94B2" stroke="#87B3CE" stroke-width="6"/>
<path d="M9 217h237" stroke="#BFE4ED" stroke-width="7" stroke-linecap="round"/>""",
 "iron": """<path d="M43 188h173c14 0 22 13 14 25H37c-10-11-7-25 6-25Z" fill="#6DADCF" stroke="#4A86A8" stroke-width="6"/>
<path d="M65 112q-25 27-28 76h193q-16-43-45-71Z" fill="#EAF4F4" stroke="#779BA9" stroke-width="7"/>
<path d="M88 115q5-49 57-49t58 51" fill="none" stroke="#6B8991" stroke-width="17" stroke-linecap="round"/>
<path d="M111 122h62" stroke="#B2D7DC" stroke-width="7" stroke-linecap="round"/><circle cx="73" cy="162" r="7" fill="#EDAE6B"/>
<path d="M101 51q-12-13 0-25M132 44q12-12 1-22M162 49q-12-13 0-25" fill="none" stroke="#C5D6D9" stroke-width="5" stroke-linecap="round"/>""",
 "queen": """<path d="M63 218q4-70 65-70 60 0 66 70Z" fill="#B888D8" stroke="#9865BD" stroke-width="5"/>
<path d="M108 154l20 20 19-20" fill="#EFD4A6"/><ellipse cx="128" cy="105" rx="47" ry="56" fill="#E8AC7F"/>
<path d="M75 118q-22-69 30-92 57-23 75 44l-6 46-9-43q-17-18-25-18-30 31-62 25Z" fill="#6D4B34"/>
<path d="M80 81l-10-57 31 23 27-31 27 31 31-23-11 57Z" fill="#F9CB52" stroke="#DC9D32" stroke-width="5" stroke-linejoin="round"/>
<circle cx="101" cy="48" r="6" fill="#62A6DD"/><circle cx="127" cy="39" r="6" fill="#EF6D7B"/><circle cx="154" cy="48" r="6" fill="#62A6DD"/>
<circle cx="112" cy="112" r="5" fill="#473729"/><circle cx="144" cy="112" r="5" fill="#473729"/>
<path d="M114 136q14 12 28 0" fill="none" stroke="#A4674D" stroke-width="4" stroke-linecap="round"/><circle cx="128" cy="191" r="7" fill="#F8E1A9"/>""",
 "quilt": """<rect x="31" y="48" width="194" height="155" rx="15" fill="#FCFCF5" stroke="#B08065" stroke-width="7"/>
<g><rect x="43" y="61" width="55" height="43" fill="#EBA985"/><rect x="101" y="61" width="55" height="43" fill="#91CDCB"/><rect x="159" y="61" width="54" height="43" fill="#D4BBEB"/>
<rect x="43" y="107" width="55" height="43" fill="#ADD57C"/><rect x="101" y="107" width="55" height="43" fill="#F8D36A"/><rect x="159" y="107" width="54" height="43" fill="#F1ACB8"/>
<rect x="43" y="153" width="55" height="39" fill="#B5C9EE"/><rect x="101" y="153" width="55" height="39" fill="#EFAD88"/><rect x="159" y="153" width="54" height="39" fill="#9FDAC9"/></g>
<path d="M42 107h173M42 153h173M100 61v132M158 61v132" stroke="#FFFCF2" stroke-width="4" stroke-dasharray="5 5"/>
<path d="M31 204q26-16 48 0t49 0 49 0 48 0" fill="none" stroke="#B08065" stroke-width="6"/>""",
 "quail": """<path d="M80 122q-7-52 32-64 40-13 66 21l10 55-17 42H80q-45-18-40-51Z" fill="#C99065" stroke="#8B6245" stroke-width="6"/>
<path d="M107 64q-18-32-8-45M119 59q4-28 23-35" fill="none" stroke="#8B6245" stroke-width="7" stroke-linecap="round"/>
<path d="M64 99q-23-28-43-14l17 24" fill="#B67B57"/><path d="M182 111l33 16-34 16" fill="#E9B86E" stroke="#B98A50" stroke-width="4"/>
<circle cx="160" cy="101" r="7" fill="#332E2C"/><path d="M95 106q26 25 15 55" stroke="#EAB28A" stroke-width="17" fill="none" stroke-linecap="round"/>
<path d="M106 169l-13 44M156 170l8 42M89 215h27M145 214h27" stroke="#997052" stroke-width="7" stroke-linecap="round"/>
<path d="M74 145q-31 0-50 18" stroke="#B3825D" stroke-width="9" stroke-linecap="round"/>""",
 "quill": """<path d="M66 211L187 47" stroke="#986339" stroke-width="8" stroke-linecap="round"/>
<path d="M86 166q-74-69 3-118 55-31 120-8-2 64-50 104-33 31-73 22Z" fill="#8EBDD6" stroke="#568CA7" stroke-width="5"/>
<path d="M87 161L201 44M90 145l13-51M121 131l-2-63M145 107l31-48" stroke="#D1EAF4" stroke-width="5" stroke-linecap="round"/>
<path d="M58 199l7 26 15-17" fill="#B78B57" stroke="#956E48" stroke-width="3"/>
<rect x="164" y="177" width="61" height="44" rx="8" fill="#566D95"/><path d="M174 177v-12h41v12" fill="none" stroke="#4D6382" stroke-width="8"/><ellipse cx="194" cy="185" rx="20" ry="5" fill="#334365"/>""",
 "ukulele": """<g transform="rotate(17 128 128)"><path d="M129 155q-38 5-43 33-8 52 42 59 53-6 42-59-4-19-28-29l-3-46h-12Z" fill="#DDA15C" stroke="#996139" stroke-width="6"/>
<rect x="123" y="29" width="16" height="136" rx="7" fill="#9D673E"/><rect x="117" y="23" width="27" height="46" rx="7" fill="#B67D48"/>
<circle cx="130" cy="177" r="21" fill="#9F6741" stroke="#EBC68B" stroke-width="4"/><path d="M104 211h52" stroke="#865334" stroke-width="10" stroke-linecap="round"/>
<path d="M126 33v174M130 33v174M134 33v174M138 33v174" stroke="#F6E5C4" stroke-width="1.3"/>
<g fill="#F3D0A0"><circle cx="117" cy="33" r="4"/><circle cx="145" cy="33" r="4"/><circle cx="117" cy="57" r="4"/><circle cx="145" cy="57" r="4"/></g></g>""",
 "xylophone": """<g transform="rotate(-12 128 128)"><rect x="40" y="62" width="174" height="26" rx="10" fill="#EF8F78"/><rect x="44" y="92" width="166" height="25" rx="9" fill="#F2BD56"/><rect x="49" y="121" width="156" height="25" rx="9" fill="#8FCE78"/><rect x="54" y="150" width="145" height="25" rx="9" fill="#80C9C9"/><rect x="60" y="179" width="135" height="25" rx="9" fill="#A99BDD"/>
<path d="M63 54l20 162M187 56l-19 162" fill="none" stroke="#946D58" stroke-width="6"/><g fill="#FCF8EE"><circle cx="60" cy="74" r="4"/><circle cx="193" cy="74" r="4"/><circle cx="62" cy="191" r="4"/><circle cx="178" cy="191" r="4"/></g></g>
<path d="M191 42l40 88M222 29l-45 94" stroke="#A3734E" stroke-width="6" stroke-linecap="round"/><circle cx="191" cy="42" r="11" fill="#F4C55A"/><circle cx="223" cy="30" r="11" fill="#F4C55A"/>""",
 "yak": """<path d="M55 119L34 83l25 10 8-28 20 46M182 112l20-47 8 26 22-7-26 39" fill="#E2C698" stroke="#A18467" stroke-width="5"/>
<path d="M57 111q-16-26 5-42 30-20 70-15 52-9 66 26l-6 84q-10 45-64 49-56 0-78-37Z" fill="#876344" stroke="#694A32" stroke-width="6"/>
<path d="M60 167q-9 35 13 47l17-6 12 10 17-12 17 10 18-13 16 10q28-18 22-51" fill="#6F513A"/>
<ellipse cx="127" cy="141" rx="48" ry="39" fill="#B79168"/><ellipse cx="106" cy="126" rx="8" ry="11" fill="#312A26"/><ellipse cx="152" cy="126" rx="8" ry="11" fill="#312A26"/><ellipse cx="128" cy="150" rx="19" ry="13" fill="#78543B"/><circle cx="123" cy="149" r="4" fill="#36261D"/><circle cx="133" cy="149" r="4" fill="#36261D"/>
<path d="M90 197l-8 27M169 197l10 27" stroke="#664A36" stroke-width="8" stroke-linecap="round"/>""",
 "zipper": """<path d="M71 30v187M185 30v187" stroke="#729FC2" stroke-width="18" stroke-linecap="round"/><path d="M83 35h29M83 56h29M83 77h29M83 98h29M83 119h29M83 140h29M83 161h29M83 182h29M83 203h29" stroke="#EBE9DD" stroke-width="10"/>
<path d="M145 35h28M145 56h28M145 77h28M145 98h28M145 119h28M145 140h28M145 161h28M145 182h28M145 203h28" stroke="#EBE9DD" stroke-width="10"/>
<rect x="104" y="90" width="50" height="59" rx="10" fill="#F5C762" stroke="#B5853E" stroke-width="5"/><path d="M127 131v43" stroke="#C29248" stroke-width="8" stroke-linecap="round"/><ellipse cx="127" cy="187" rx="12" ry="19" fill="#E6AC57" stroke="#B5853E" stroke-width="5"/>""",
 "zoo": """<path d="M48 217V104q80-36 160 0v113" fill="#F8D994" stroke="#BF8E53" stroke-width="9"/><path d="M62 98q66-56 132 0" fill="#A1D076" stroke="#5A9B59" stroke-width="8"/><rect x="72" y="124" width="112" height="90" rx="11" fill="#DFF4CC"/><path d="M94 214v-89M162 214v-89" stroke="#BF8E53" stroke-width="7"/>
<circle cx="127" cy="167" r="32" fill="#F0B65B"/><circle cx="105" cy="150" r="10" fill="#D69B4D"/><circle cx="149" cy="150" r="10" fill="#D69B4D"/><ellipse cx="127" cy="176" rx="20" ry="16" fill="#FFE0A1"/><circle cx="115" cy="166" r="4" fill="#563B27"/><circle cx="140" cy="166" r="4" fill="#563B27"/><path d="M123 182q4 5 8 0" stroke="#563B27" stroke-width="3" fill="none"/>
<rect x="86" y="48" width="84" height="40" rx="12" fill="#72B95C" stroke="#4D914D" stroke-width="5"/><text x="128" y="76" font-family="Arial,sans-serif" font-weight="bold" font-size="25" fill="white" text-anchor="middle">ZOO</text>""",
 "zigzag": """<path d="M25 180l47-99 52 99 53-98 52 99" fill="none" stroke="#C6D3D0" stroke-width="34" stroke-linejoin="round" stroke-linecap="round"/>
<path d="M25 180l47-99 52 99 53-98 52 99" fill="none" stroke="#F1B94E" stroke-width="24" stroke-linejoin="round" stroke-linecap="round"/>
<path d="M25 180l47-99 52 99 53-98 52 99" fill="none" stroke="#FFEBA6" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"/>
<circle cx="25" cy="180" r="9" fill="#E8846B"/><circle cx="229" cy="181" r="9" fill="#6DB5B8"/>"""
}
def custom_art(word):
    key = word.lower()
    if key not in CUSTOM:
        raise ValueError("Custom art not defined for " + word)
    return HEAD + BACKGROUND + CUSTOM[key] + FOOT

def codepoint_name(emoji):
    return "-".join(format(ord(c), "x") for c in emoji if ord(c) not in (0xfe0f, 0xfe0e))

def validated_svg(svg, word):
    if not svg.lstrip().startswith("<svg") or "</svg>" not in svg:
        raise ValueError("Invalid SVG for " + word)
    if "<script" in svg.lower() or "http://" in svg.lower().replace('http://www.w3.org/2000/svg',''):
        raise ValueError("Unsafe SVG for " + word)
    return svg

def download_svg(emoji, word):
    url = BASE + codepoint_name(emoji) + ".svg"
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent":"WordSprout-AssetBuilder/1.0"})
            with urllib.request.urlopen(req, timeout=25) as response:
                return validated_svg(response.read().decode("utf-8"), word)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))
    raise RuntimeError("unreachable")

def build():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    assert data["schema_version"] == 1
    words = data["words"]
    if len(words) != 130 or len(set(w["id"] for w in words)) != 130:
        raise AssertionError("Expected 130 unique words")
    manifest = {}
    for entry in words:
        name = entry["word"]
        if len(entry["facts"]) != 3:
            raise AssertionError("Expected three facts for " + name)
        path = ROOT / entry["image"]
        if not str(path.resolve()).startswith(str(TARGET.resolve())):
            raise AssertionError("Unexpected asset path")
        if path.exists():
            svg = validated_svg(path.read_text(encoding="utf-8"), name)
            source = "WordSprout custom" if entry["emoji"] == "custom" else "Twemoji CC BY 4.0"
        elif entry["emoji"] == "custom":
            svg = validated_svg(custom_art(name), name)
            path.write_text(svg, encoding="utf-8")
            source = "WordSprout custom"
        else:
            svg = download_svg(entry["emoji"], name)
            path.write_text(svg, encoding="utf-8")
            source = "Twemoji CC BY 4.0"
        manifest[entry["id"]] = {"image":entry["image"],"source":source,
                                 "sha256":hashlib.sha256(svg.encode("utf-8")).hexdigest()}
        print(name, "=>", path.relative_to(ROOT), source)
    output = ROOT / "assets/content/artwork_manifest.json"
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    print("Validated and bundled",len(manifest),"individual illustrations")

if __name__ == "__main__":
    build()
