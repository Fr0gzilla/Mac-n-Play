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

pattern = re.compile(r'\b(?:qsTr|tr)\(\s*"((?:[^"\\]|\\.)*)"')
missing = {}
files = glob.glob("gui/src/qml/**/*.qml", recursive=True) + glob.glob("gui/src/*.cpp")
for path in sorted(files):
    for number, line in enumerate(open(path, encoding="utf-8"), 1):
        for text in pattern.findall(line):
            if text and text not in translated:
                missing.setdefault(text, f"{path}:{number}")

for text, where in sorted(missing.items(), key=lambda item: item[1]):
    print(f"{where}\t{text}")
print(f"\n{len(missing)} texte(s) sans traduction", file=sys.stderr)
sys.exit(1 if missing else 0)
