#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
# Liste les textes de l'interface (qsTr / tr) qui n'ont pas encore de traduction française
# dans gui/include/frenchtranslations.inc. Lancement, depuis la racine du dépôt :
#   python3 scripts/check-translations.py
# Code de sortie 1 s'il en manque (pratique pour une vérification automatique).
import glob
import re
import sys

table = open("gui/include/frenchtranslations.inc", encoding="utf-8").read()
translated = set(re.findall(r'^\s*\{ "((?:[^"\\]|\\.)*)",', table, re.M))

# textes identiques en français : noms techniques, unités, boutons de manette, valeurs
SAME_IN_FRENCH = {
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
missing = {}
files = glob.glob("gui/src/qml/**/*.qml", recursive=True) + glob.glob("gui/src/*.cpp")
for path in sorted(files):
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        for text in pattern.findall(line):
            if text and text not in translated and text not in SAME_IN_FRENCH and not NOT_WORDS.match(text):
                missing.setdefault(text, f"{path}:{number}")

for text, where in sorted(missing.items(), key=lambda item: item[1]):
    print(f"{where}\t{text}")
print(f"\n{len(missing)} texte(s) sans traduction", file=sys.stderr)
sys.exit(1 if missing else 0)
