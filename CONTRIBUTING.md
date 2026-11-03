# Contribuer à Mac'n'Play

Merci de votre intérêt ! Quelques repères pour que les contributions restent cohérentes.

## Avant de commencer

- Lisez [`ARCHITECTURE.md`](ARCHITECTURE.md) : organisation MVC, rôle de chaque fichier, journal.
- Pour fabriquer l'appli et lancer les tests : [`BUILDING.md`](BUILDING.md).
- Pour un bug, ouvrez d'abord un [ticket](https://github.com/Fr0gzilla/Mac-n-Play/issues/new?template=probleme.md) avec le journal.

## Règles du code

- **Une classe, un rôle.** Un nouveau besoin qui ne relève d'aucun contrôleur existant mérite le sien.
- **Pas de règle métier dans le QML.** Une vue affiche et transmet ; une règle va dans un contrôleur,
  et si possible dans `gui/include/macnplayrules.h`, **avec un test** dans `gui/tests/rulestest.cpp`.
- **Un commentaire en tête de chaque fichier** pour dire son rôle ; les commentaires expliquent
  *pourquoi*, les noms disent *quoi*.
- **Journaliser les étapes importantes** avec la catégorie du domaine (`qCInfo(logConsoles) << …`),
  en français. Jamais de jeton ni de mot de passe dans le journal.
- **Textes de l'interface** : écrits en anglais dans `qsTr()`, traduits en français dans
  `gui/include/frenchtranslations.inc`. Une phrase entière par texte (pas de morceaux à recoller).
  `python3 scripts/check-translations.py` liste les textes sans traduction (les noms techniques,
  comme « Lanczos » ou « HDR10 », n'en ont pas besoin).
- **Mise en forme** : `gui/.clang-format` (4 espaces, accolades sur leur propre ligne) pour les
  fichiers propres à Mac'n'Play.
- **Nouveaux fichiers** : en-tête `// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL`.
- Le moteur réseau (`lib/`) et le rendu vidéo (`gui/src/qmlmainwindow.cpp`) viennent de
  [chiaki-ng](https://github.com/streetpea/chiaki-ng) : n'y touchez qu'avec une bonne raison.

## Commits et propositions

- Messages de commit en français, à l'impératif ou en résumé court : « Consoles : … ».
- Une proposition (pull request) = un sujet. Les tests doivent passer (ils tournent tout seuls sur GitHub).
- Ajoutez une ligne à [`CHANGELOG.md`](CHANGELOG.md) pour tout changement visible.

## Licence

En contribuant, vous acceptez que votre code soit distribué sous la licence du projet,
[GNU AGPL v3](COPYING) avec l'exception OpenSSL.
