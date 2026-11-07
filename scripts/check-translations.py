#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
# Vérifie les traductions de l'interface (gui/include/translations/<langue>.inc) :
#   - les textes de qsTr() / tr() qui n'ont pas de traduction, langue par langue ;
#   - les traductions qui perdent un %1 ou un retour à la ligne du texte anglais.
# Lancement, depuis la racine du dépôt :
#   python3 scripts/check-translations.py
# Code de sortie 1 s'il y a un problème (pratique pour une vérification automatique).
import collections
import glob
import os
import re
import sys

ENTRY = re.compile(r'^\s*\{ "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)" \},\s*$', re.M)
PLACEHOLDER = re.compile(r"%\d")

# textes qui peuvent rester identiques : noms techniques, unités, boutons de manette, valeurs
SAME_EVERYWHERE = {
    "Auto", "Bob", "Bt2390", "Bt2446a", "Bwdif", "Catmull Rom", "chiaki-ng", "chiaki-ng ", "Cie_y", "Consoles",
    "Digital Cinema Distribution Master (SDR)", "EwaLanczos", "EwaLanczosSharp", "EwaLanczosSharpest", "FSR",
    "FSRCNNX x2 16-0-4-1", "FSRCNNX x2 8-0-4-1", "Gamma", "H264", "H265 HDR", "Hable", "HDR10", "HDR10 Plus",
    "Hermite", "Horizontal", "IEC 61966-2-4 sRGB (SDR)", "ITU-R BT.2100 HLG / ARIB STD-B67 (HDR)",
    "ITU-R BT.2100 PQ / SMPTE ST2048 (HDR)", "ITU-R Rec. BT.1886 (SDR)", "L1", "L2", "L3", "Lanczos", "Local",
    "MENUS", "Mitchell", "Mobius", "OK", "OpenGL", "Options", "Panasonic V-Log (HDR)", "Placebo",
    "ProPhoto RGB (SDR)", "PS", "PS4", "PS5", "R1", "R2", "R3", "Reinhard", "Saturation", "Share",
    "Sony S-Log1 (HDR)", "Sony S-Log2 (HDR)", "Spline", "St-2094-10", "St2094-40", "Triangle", "Vertical",
    "Volume", "Vulkan", "Weave", "Yadif", "Zoom", "--profile=",
}
# valeurs sans mot à traduire : nombres, unités, résolutions, « (1.0) », « %1 ms »…
NOT_WORDS = re.compile(r"^[\s\d.,%()+\-x:=/]*(?:%\d|\d)[\s\d.,%()+\-x:=/]*(?:dB|ms|mm|nits|Mbps|fps|p)?\)?$|^\s*\(?%?\d?\s*(?:Mbps|ms|nits)\)?$|^\((?:Auto|EwaLanczos|Hermite|Spline|Vulkan|Yadif|L1\+R1\+L3\+R3|%1 Mbps)\)$|^ \(%1 Mbps\)$")

pattern = re.compile(r'\b(?:qsTr|tr)\(\s*"((?:[^"\\]|\\.)*)"')
used = {}
files = glob.glob("gui/src/qml/**/*.qml", recursive=True) + glob.glob("gui/src/*.cpp")
for path in sorted(files):
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        for text in pattern.findall(line):
            if text and text not in SAME_EVERYWHERE and not NOT_WORDS.match(text):
                used.setdefault(text, f"{path}:{number}")

problems = 0
for table_path in sorted(glob.glob("gui/include/translations/*.inc")):
    language = os.path.splitext(os.path.basename(table_path))[0]
    entries = ENTRY.findall(open(table_path, encoding="utf-8").read())
    translated = {source for source, _ in entries}
    missing = sorted((where, text) for text, where in used.items() if text not in translated)
    for where, text in missing:
        print(f"[{language}] sans traduction\t{where}\t{text}")
    # une traduction doit garder les %1, %2… et les retours à la ligne du texte anglais
    broken = 0
    for source, translation in entries:
        same_placeholders = collections.Counter(PLACEHOLDER.findall(source)) == collections.Counter(PLACEHOLDER.findall(translation))
        if not same_placeholders or source.count("\\n") != translation.count("\\n"):
            print(f"[{language}] %N ou retour à la ligne différent\t{source}\t{translation}")
            broken += 1
    print(f"{language} : {len(entries)} textes, {len(missing)} sans traduction, {broken} abîmé(s)", file=sys.stderr)
    problems += len(missing) + broken

sys.exit(1 if problems else 0)
