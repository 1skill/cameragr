#!/usr/bin/env python3
"""Merges the Traditional Chinese, Japanese and Korean translations in
tools/i18n/ into the string catalogs and film notes. Machine-made by the
developer, so every entry is marked needs_review until a native speaker
has read it. Re-running is safe."""
import json, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
LANGS = ["zh-Hant", "ja", "ko"]

import re, sys
ui = json.load(open(root / "tools/i18n/ui.json"))
# Check everything before writing anything: three languages each, same placeholders.
ph = lambda t: sorted(m[1] for m in re.findall(r"%(\d+\$)?(lld|ld|d|@|f)", t))
bad = [k for k, v in ui.items() if len(v) != 3 or any(ph(x) != ph(k) for x in v)]
if bad:
    sys.exit(f"translations with a wrong count or placeholders: {bad}")
p = root / "Shared/Localizable.xcstrings"
cat = json.load(open(p))
missing = []
for key, entry in cat["strings"].items():
    if not key.strip() or entry.get("shouldTranslate") is False:
        continue
    if key not in ui:
        missing.append(key); continue
    loc = entry.setdefault("localizations", {})
    for lang, value in zip(LANGS, ui[key]):
        loc[lang] = {"stringUnit": {"state": "needs_review", "value": value}}
json.dump(cat, open(p, "w"), indent=2, ensure_ascii=False, sort_keys=True)

plist = {
    "NSCameraUsageDescription": ["用於取景和拍照。", "撮影時の構図確認と撮影に使用します。", "구도를 잡고 사진을 찍는 데 사용합니다."],
    "NSPhotoLibraryUsageDescription": ["用於把拍好的相片存入 Koco 相簿，以及匯入相片套用底片效果。", "撮った写真をKocoアルバムに保存し、写真を読み込んでフィルムを試すために使用します。", "찍은 사진을 Koco 앨범에 저장하고, 사진을 가져와 필름을 입혀 보는 데 사용합니다."],
    "NSPhotoLibraryAddUsageDescription": ["用於把拍好的相片存入照片。", "撮った写真を写真に保存するために使用します。", "찍은 사진을 사진 앱에 저장하는 데 사용합니다."],
    "CFBundleDisplayName": ["Koco", "Koco", "Koco"],
}
p = root / "Shared/InfoPlist.xcstrings"
cat = json.load(open(p))
for key, values in plist.items():
    loc = cat["strings"][key].setdefault("localizations", {})
    for lang, value in zip(LANGS, values):
        loc[lang] = {"stringUnit": {"state": "needs_review", "value": value}}
json.dump(cat, open(p, "w"), indent=2, ensure_ascii=False, sort_keys=True)

notes = json.load(open(root / "tools/i18n/notes.json"))
p = root / "cameragr/Resources/Films/film_notes.json"
data = json.load(open(p))
for film, langs in notes.items():
    data[film]["text"].update(langs)
json.dump(data, open(p, "w"), indent=2, ensure_ascii=False)

if missing:
    sys.exit(f"no translation for: {missing}")
print("merged; every string has zh-Hant, ja and ko")
