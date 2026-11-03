# Fabriquer Mac'n'Play

Ce guide fabrique l'appli sur un Mac avec puce Apple. Les mêmes étapes sont exécutées
automatiquement par GitHub dans [`.github/workflows/build-macos-arm.yml`](.github/workflows/build-macos-arm.yml),
qui fait foi en cas de doute.

## 1. Outils

- Les outils de développement d'Apple : `xcode-select --install`.
- [Homebrew](https://brew.sh), puis :

```sh
brew install qt@6 ffmpeg pkgconfig opus openssl@3.6 cmake ninja nasm protobuf@29 \
  speexdsp libplacebo python-setuptools json-c miniupnpc libevent sdl3
pip3 install --user 'protobuf>=5,<6' --break-system-packages
```

> **OpenSSL : prenez `openssl@3.6`, pas `openssl@3`.** Chez Homebrew, `openssl@3` désigne
> la 3.5, avec laquelle les certificats des serveurs de Sony ne sont plus vérifiés
> (profil PSN, consoles PS5). Les en-têtes et la bibliothèque doivent venir de la même version :
>
> ```sh
> brew unlink openssl@4 openssl@3 ; brew link --force --overwrite openssl@3.6
> ```

## 2. Récupérer le code

```sh
git clone --recursive https://github.com/Fr0gzilla/Mac-n-Play.git
cd Mac-n-Play
```

(Déjà cloné sans `--recursive` : `git submodule update --init --recursive`.)

## 3. Compiler

```sh
BREW=$(brew --prefix)
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DCHIAKI_ENABLE_CLI=OFF -DMACNPLAY_VERSION=1.1.0-local \
  -DOPENSSL_ROOT_DIR="$BREW/opt/openssl@3.6" \
  -DCMAKE_PREFIX_PATH="$BREW/opt/openssl@3.6;$BREW/opt/qt@6;$BREW/opt/protobuf@29"
CPATH="$BREW/opt/ffmpeg/include" cmake --build build --target chiaki
```

L'appli se trouve dans `build/gui/chiaki.app`. Elle se lance telle quelle sur le Mac qui l'a
fabriquée (elle utilise les bibliothèques de Homebrew) :

```sh
build/gui/chiaki.app/Contents/MacOS/chiaki
```

> Si le compilateur se plaint du SDK (`SDK … cannot be read`), forcez un SDK lisible :
> `export SDKROOT=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk | sort -V | tail -1)`
> avant les commandes `cmake`.

## 4. Tests

Les règles métier (`gui/include/macnplayrules.h`) ont leurs tests, compilables seuls :

```sh
cmake -S gui/tests -B build-tests -G Ninja -DCMAKE_PREFIX_PATH="$(brew --prefix)/opt/qt@6"
cmake --build build-tests && ctest --test-dir build-tests --output-on-failure
```

Ils tournent aussi sur GitHub à chaque envoi ([`tests.yml`](.github/workflows/tests.yml)).

## 5. Fabriquer une appli à distribuer (.dmg)

Une appli qui marche sur d'autres Mac doit embarquer ses bibliothèques. C'est l'étape
« Package » de la [fabrication GitHub](.github/workflows/build-macos-arm.yml), en résumé :

1. `macdeployqt` copie Qt et les bibliothèques Homebrew dans l'appli ;
2. MoltenVK et SDL (chargé à l'exécution par sdl2-compat) sont ajoutés à la main ;
3. l'icône au format macOS 26 (`gui/AppIcon.icon`) est compilée avec `actool`, qui demande Xcode 26 ;
4. l'appli est signée « ad hoc » (sans compte développeur Apple), puis mise dans un .dmg.

Le plus simple pour obtenir un .dmg est de lancer la fabrication GitHub : onglet **Actions** ›
**Fabrication Mac'n'Play** › **Run workflow**. Le fichier est joint au résultat.

> Une appli fabriquée sur macOS 26 ne marche que sur macOS 26 (les bibliothèques de Homebrew
> suivent la version du système). La fabrication GitHub utilise macOS 15, pour que l'appli
> marche à partir de macOS 15.

## Publier une version

Poser une étiquette `vX.Y.Z` sur `main` et l'envoyer : la fabrication GitHub crée la page de
téléchargement avec le .dmg et le texte de `RELEASE_NOTES.md`. Une étiquette avec un tiret
(`v1.2.0-beta`) est publiée en pré-version. Pour une version définitive, la fabrication met
aussi à jour la recette Homebrew ([`Casks/macnplay.rb`](Casks/macnplay.rb) : version et empreinte).
