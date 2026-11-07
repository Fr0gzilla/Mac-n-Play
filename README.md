<p align="center">
  <img src="assets/readme/icone.png" width="128" alt="Icône de Mac'n'Play">
</p>

<h1 align="center">Mac'n'Play</h1>

<p align="center">
  Jouez à votre PS4 ou PS5 sur votre Mac, avec votre manette.<br>
  <a href="#english">English version below</a>
</p>

<p align="center">
  <a href="https://github.com/Fr0gzilla/Mac-n-Play/releases/latest"><img src="https://img.shields.io/github/v/release/Fr0gzilla/Mac-n-Play?label=version" alt="Dernière version"></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-blue" alt="macOS 15 ou plus récent">
  <img src="https://img.shields.io/badge/Mac-puce%20Apple-lightgrey" alt="Mac avec puce Apple">
  <a href="COPYING"><img src="https://img.shields.io/badge/licence-AGPL%20v3-green" alt="Licence AGPL v3"></a>
</p>

<p align="center">
  <a href="https://github.com/Fr0gzilla/Mac-n-Play/releases/latest"><b>⬇ Télécharger la dernière version</b></a>
</p>

---

**Sommaire** : [Ce que fait l'appli](#ce-que-fait-lappli) · [Ce qu'il faut](#ce-quil-faut) · [Installation](#installation) · [Premiers pas](#premiers-pas) · [Utilisation](#utilisation) · [Raccourcis](#raccourcis) · [Mises à jour](#mises-à-jour) · [Vie privée](#vie-privée) · [En cas de problème](#en-cas-de-problème) · [Désinstaller](#désinstaller) · [État du projet](#état-du-projet) · [Contribuer](#fabriquer-lappli-et-contribuer) · [Licence](#licence-et-crédits)

## Ce que fait l'appli

Mac'n'Play affiche l'écran de votre PlayStation sur votre Mac (Remote Play) et transmet votre manette à la console. C'est une version pensée pour macOS, basée sur le projet libre [chiaki-ng](https://github.com/streetpea/chiaki-ng).

- **Accueil à la manette** : la carte de votre console, son état (allumée, en veille), et un appui sur ✕ pour jouer.
- **Votre compte PSN** sur la carte de vos consoles : avatar, pseudo, niveau et trophées, gardés sur le Mac pour s'afficher même hors ligne.
- **Réglages automatiques** adaptés à votre console et à votre connexion, modifiables à tout moment.
- **Menu en jeu** : volume, micro, zoom, qualité d'image, retour à l'accueil.
- **Baisse de qualité en pleine partie** si votre connexion a du mal, sans réduire la taille de l'image.
- **Jusqu'à deux consoles**, chacune avec ses propres réglages.
- **Assistant d'ajout de console** en trois étapes, avec les explications à chaque écran.
- **Jeu hors de chez soi** par Internet : la qualité s'adapte toute seule à la connexion (par exemple 360p sur un partage de connexion de téléphone) et baisse d'un cran si l'image saccade.
- **« Tester ma connexion »** : l'appli vérifie le réseau du Mac, Internet, le compte PSN et la console, et explique en clair ce qui ne va pas.
- **Nouvelles versions signalées** sur l'accueil, avec un bouton pour les télécharger.
- **Journal** à copier en un clic pour signaler un problème, avec vos adresses et votre pseudo masqués.
- En français ou en anglais, selon la langue de votre Mac.

## Ce qu'il faut

- Un **Mac avec puce Apple** (M1, M2, M3, M4 ou M5) sous **macOS 15 Sequoia ou plus récent**.
- Une **PS4 ou PS5** avec la lecture à distance activée.
- Un **compte PlayStation Network** (celui utilisé sur la console).
- Une **manette** : DualShock 4 (PS4) ou DualSense (PS5), en Bluetooth ou par câble. Le clavier et la souris marchent aussi.
- Pour un bon résultat, le Mac et la console sur le **même réseau**, de préférence la console branchée en câble.

> Les Mac Intel et les versions de macOS antérieures à la 15 ne sont pas pris en charge : macOS refuse alors d'ouvrir l'appli.

## Installation

1. Téléchargez le fichier `Mac-n-Play-….dmg` depuis la [page des versions](https://github.com/Fr0gzilla/Mac-n-Play/releases/latest).
2. Ouvrez-le, puis glissez **Mac'n'Play** dans le dossier **Applications**.
3. Lancez l'appli depuis Applications.

### Ou avec Homebrew

Si vous utilisez [Homebrew](https://brew.sh) :

```sh
brew tap fr0gzilla/macnplay https://github.com/Fr0gzilla/Mac-n-Play
brew trust fr0gzilla/macnplay
brew install --cask macnplay
```

La deuxième ligne indique à Homebrew que vous faites confiance à ce dépôt : il l'exige pour toute appli qui ne vient pas de son catalogue officiel.

### « Apple n'a pas pu vérifier… » : c'est normal

L'appli est gratuite et n'est pas enregistrée auprès d'Apple (ce qui coûte 99 € par an). Au premier lancement, macOS la bloque. Pour l'autoriser, une seule fois :

1. Essayez d'ouvrir Mac'n'Play, puis cliquez sur **OK** dans le message.
2. Ouvrez **Réglages Système** › **Confidentialité et sécurité**.
3. Tout en bas, à côté de « Mac'n'Play a été bloquée », cliquez sur **Ouvrir quand même**, puis confirmez avec votre mot de passe.

<details>
<summary>Autre méthode, avec le Terminal</summary>

Collez cette ligne dans l'appli Terminal, puis appuyez sur Entrée :

```sh
xattr -dr com.apple.quarantine "/Applications/Mac'n'Play.app"
```
</details>

Au premier lancement, macOS demande aussi l'accès au **micro** : il sert au chat vocal des jeux. Vous pouvez refuser, tout le reste marche.

## Premiers pas

1. **Préparez la console**
   - PS4 : Paramètres › Paramètres de connexion de la lecture à distance › cochez *Activer la lecture à distance*.
   - PS5 : Paramètres › Système › Lecture à distance › activez *Activer la lecture à distance*.
2. **Connectez votre compte PSN** dans l'appli (Paramètres › Tous les réglages › À distance) : une page de connexion PlayStation s'ouvre.
3. **Ajoutez la console** avec le bouton **+** en haut de l'accueil (ou R3 à la manette). L'assistant vous demande un code à 8 chiffres : il s'affiche sur la console, dans *Ajouter un appareil* (même menu que l'étape 1).
4. **Appuyez sur ✕** sur la carte de la console pour jouer. Si elle est en veille, l'appli la réveille.

## Utilisation

### L'accueil

Chaque console a sa carte : son nom, son état (allumée, en veille, injoignable) et, sur vos consoles, votre compte PSN. L'appli montre aussi les PlayStation qu'elle voit sur votre Wi-Fi sans qu'elles soient associées (celle d'un proche, par exemple) : leur carte sert à les ajouter, et n'affiche pas votre compte.

### Les Paramètres

- **L'essentiel** : les réglages utiles à tous (qualité d'image, fluidité, rendu, fenêtre de jeu, ce que fait la console quand vous quittez). Ils s'appliquent à la console affichée en haut ; avec deux consoles, △ passe de l'une à l'autre.
- **Tous les réglages** : le détail, en onglets (Général, Vidéo, Streaming, Audio/Wi-Fi, Consoles, Touches, Manettes, À distance, Configuration). L1 et R1 changent d'onglet à la manette.
- **Connexion automatique** (onglet Consoles) : si elle est cochée, l'appli lance la partie sur cette console dès son ouverture, sans attendre que vous appuyiez sur Jouer.

### Le menu en jeu

Il s'ouvre par-dessus la partie avec **L1 + R1 + L3 + R3** (ou au clavier, voir [Raccourcis](#raccourcis)) :

- **Jeu** : revenir à l'accueil de Mac'n'Play.
- **Son** : volume, micro allumé ou coupé.
- **Image** : normale, zoom (sans bandes noires) ou étirée.
- **Qualité** : à baisser si l'image saccade.
- **Rendu** : de « Rapide » à « Netteté maximale », selon ce que votre Mac peut suivre.

En bas, l'état de la connexion : pertes de paquets et images perdues.

### Jouer hors de chez soi

Avec votre compte PSN connecté, la carte de la console marche aussi quand le Mac n'est pas chez vous : la partie passe par Internet. La qualité de départ s'adapte au réseau, puis baisse d'un cran si l'image saccade. Un message vous indique quand vous jouez par Internet.

La qualité dépend surtout de la connexion **de chez vous** (débit montant de votre box) et de celle du Mac. Un partage de connexion 4G ou 5G marche bien.

## Raccourcis

### À la manette

| Combinaison | Effet |
|---|---|
| L1 + R1 + L3 + R3 | Ouvrir ou fermer le menu en jeu |
| L1 + R1 + Haut (maintenir) | La croix directionnelle sert de pavé tactile, pour les jeux qui en ont besoin |
| ✕ / ○ | Valider / revenir en arrière dans l'appli |
| L2 / R2 (Paramètres) | Passer de « L'essentiel » à « Tous les réglages » |
| L1 / R1 (Tous les réglages) | Changer d'onglet |
| △ (Paramètres, deux consoles) | Changer de console |
| Options (Paramètres) | Fermer les Paramètres |
| R1 (accueil) | Actualiser les consoles du compte PSN |
| R3 (accueil) | Ajouter une console |

Les combinaisons du menu en jeu et du pavé tactile se modifient dans Paramètres › Tous les réglages › Manettes.

### Au clavier, pendant une partie

| Touches | Effet |
|---|---|
| ⌘ O | Ouvrir ou fermer le menu en jeu |
| ⌘ M | Couper ou remettre le son |
| ⌘ Z | Zoom (sans bandes noires) |
| ⌘ S | Image étirée |
| F11 | Plein écran ou fenêtre |
| Échap | Fermer le menu en jeu |

## Mises à jour

L'appli consulte GitHub une fois par jour et affiche un bandeau sur l'accueil quand une nouvelle version sort (désactivable dans Paramètres › Tous les réglages › Configuration). Pour mettre à jour, téléchargez le nouveau `.dmg` et remplacez l'appli dans Applications : vos réglages, consoles et compte PSN sont conservés.

Avec Homebrew : `brew upgrade --cask macnplay`.

## Vie privée

- **Tout reste sur votre Mac** : consoles associées, réglages, connexion au compte PSN, carte du compte et journal. Rien n'est envoyé au développeur.
- L'appli ne parle qu'à **votre console**, aux **serveurs de Sony** (compte PSN, jeu par Internet) et à **GitHub** (vérification des nouvelles versions, désactivable).
- Le **journal copié** pour un ticket masque vos adresses, identifiants, pseudo et noms de consoles.
- L'**export des réglages** (Configuration › Exporter) contient vos associations de consoles, mais pas votre compte PSN : gardez ce fichier pour vous.

## En cas de problème

- **Commencez par Paramètres › Tous les réglages › Configuration › Tester ma connexion** : il dit ce qui bloque (réseau, Internet, compte PSN ou console).
- **La console n'apparaît pas** : vérifiez que le Mac et la console sont sur le même réseau, et que la lecture à distance est activée sur la console.
- **La partie se lance toute seule à l'ouverture** : la connexion automatique est cochée pour cette console (Tous les réglages › Consoles).
- **« Le contenu ne peut pas être affiché via Remote Play »** : une appli vidéo (YouTube, Netflix…) ou un disque est ouvert sur la console. Appuyez sur le bouton **PS** pour revenir à l'accueil de la console, puis fermez l'appli. Pensez à la fermer avant de mettre la console en mode repos.
- **Le jeu par Internet ne marche pas au lycée, à la fac ou au travail** : ces réseaux bloquent souvent les connexions de Sony. « Tester ma connexion » le détecte. Utilisez un autre réseau, par exemple le partage de connexion de votre téléphone.
- **« La console est déjà utilisée »** : une autre lecture à distance est ouverte (sur un téléphone, un autre ordinateur, ou une autre fenêtre de Mac'n'Play). Fermez-la et réessayez.
- **L'image saccade** : ouvrez le menu en jeu et baissez la **qualité**, ou choisissez un rendu plus rapide. Brancher la console en câble aide beaucoup.
- **La manette ne répond pas** : déconnectez-la puis reconnectez-la dans Réglages Système › Bluetooth.
- **L'appli ne s'ouvre pas du tout** : vérifiez que votre Mac a une puce Apple et macOS 15 ou plus récent (menu Pomme › À propos de ce Mac).

Pour signaler un problème : [ouvrir un ticket](https://github.com/Fr0gzilla/Mac-n-Play/issues/new?template=probleme.md). Joignez le journal : **Configuration › Copier le journal**.

## Désinstaller

Glissez Mac'n'Play d'Applications vers la Corbeille. Pour effacer aussi vos réglages et votre connexion PSN, supprimez ces dossiers et fichiers (dans le Finder : menu Aller › Aller au dossier) :

- `~/Library/Application Support/MacnPlay`
- `~/Library/Caches/MacnPlay`
- `~/Library/Preferences/com.macnplay.MacnPlay.plist`
- `~/Library/Preferences/com.macnplay.pl_render_params.plist`

Avec Homebrew, une seule commande fait tout : `brew uninstall --zap --cask macnplay`.

## État du projet

Mac'n'Play est testé sur **PS4** avec une manette DualShock 4, en réseau local et par Internet (partage de connexion 5G). La **PS5** n'a pas encore été testée : vos retours sont les bienvenus. Les nouveautés de chaque version sont dans le [`CHANGELOG.md`](CHANGELOG.md).

## Fabriquer l'appli et contribuer

- [`BUILDING.md`](BUILDING.md) : fabriquer l'appli soi-même (Homebrew, Qt 6, CMake), lancer les tests, produire un `.dmg`.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) : organisation du code (modèle MVC, rôle de chaque fichier, règles métier, journal, tests) et modifications apportées au code de chiaki-ng.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) : règles pour proposer une modification.

## Licence et crédits

- Mac'n'Play est un logiciel libre, distribué sous licence **[GNU AGPL v3](COPYING)** (avec l'exception OpenSSL, voir [`LICENSES`](LICENSES)). Son code source complet est dans ce dépôt.
- Il est basé sur **[chiaki-ng](https://github.com/streetpea/chiaki-ng)** de Street Pea et ses contributeurs, lui-même dérivé de **[Chiaki](https://git.sr.ht/~thestr4ng3r/chiaki)** de Florian Märkl. Merci à eux.
- Mac'n'Play n'est ni approuvé ni certifié par Sony Interactive Entertainment. « PlayStation », « PS4 », « PS5 », « DualShock » et « DualSense » sont des marques de Sony Interactive Entertainment Inc.

---

<a id="english"></a>

## English

**Mac'n'Play** lets you play your PS4 or PS5 on your Mac with your controller (Remote Play). It is a macOS-focused version of the open source [chiaki-ng](https://github.com/streetpea/chiaki-ng) project. The interface follows your Mac's language (French or English).

### Requirements

- A Mac with **Apple silicon** (M1 to M5) running **macOS 15 Sequoia or later**. Intel Macs and older macOS versions are not supported.
- A PS4 or PS5 with Remote Play enabled, a PlayStation Network account, and a DualShock 4 or DualSense controller (keyboard and mouse work too).

### Install

1. Download `Mac-n-Play-….dmg` from the [releases page](https://github.com/Fr0gzilla/Mac-n-Play/releases/latest), open it and drag **Mac'n'Play** to **Applications**.
   With Homebrew: `brew tap fr0gzilla/macnplay https://github.com/Fr0gzilla/Mac-n-Play && brew trust fr0gzilla/macnplay && brew install --cask macnplay`
2. The app is not notarized by Apple, so macOS blocks the first launch. Try to open it, click **OK**, then go to **System Settings › Privacy & Security** and click **Open Anyway**. Or run:
   ```sh
   xattr -dr com.apple.quarantine "/Applications/Mac'n'Play.app"
   ```

### Getting started

1. Enable Remote Play on the console.
2. Sign in to PSN in the app (Settings › All settings › Remote).
3. Add your console with the **+** button (or R3) and enter the 8-digit code shown on the console under *Add Device*.
4. Press ✕ on the console card to play.

### Using the app

- **Settings › Essentials** holds the settings everyone needs (picture quality, frame rate, rendering, window mode); **All settings** has the details in tabs. With two consoles, △ switches between them.
- **In-game menu**: **L1 + R1 + L3 + R3** on the controller or **⌘ O** on the keyboard (volume, mic, zoom, quality, back to home). Other keys during a game: ⌘ M mute, ⌘ Z zoom, ⌘ S stretch, F11 full screen.
- **Playing away from home** works through the Internet once your PSN account is connected; the quality adapts to the connection automatically.
- **Auto-connect** (All settings › Consoles) starts a game on that console as soon as the app opens.
- **Updates** are announced on the home screen (GitHub is checked once a day; can be turned off). With Homebrew: `brew upgrade --cask macnplay`.

### Privacy

Everything stays on your Mac (paired consoles, settings, PSN sign-in, logs). The app only talks to your console, Sony's servers and GitHub (update check). The log you copy for a bug report hides addresses, identifiers, your PSN name and console names.

### Troubleshooting

Use **Settings › All settings › Config › Test my connection**: it checks the Mac's network, the Internet, the PSN account and the console, and explains what is wrong. School and company networks often block Sony's servers; use your phone's hotspot instead. To report a bug, [open an issue](https://github.com/Fr0gzilla/Mac-n-Play/issues/new?template=probleme.md) and attach the log (**Config › Copy the journal**).

### Uninstall

Drag the app to the Trash. To remove settings too, delete `~/Library/Application Support/MacnPlay`, `~/Library/Caches/MacnPlay` and `~/Library/Preferences/com.macnplay.*.plist`, or run `brew uninstall --zap --cask macnplay`.

### Status

Tested on **PS4** with a DualShock 4, on a local network and over the Internet (5G hotspot). PS5 is not tested yet; feedback is welcome in the [issues](https://github.com/Fr0gzilla/Mac-n-Play/issues).

### License

Free software under the **[GNU AGPL v3](COPYING)** (with OpenSSL exception). Based on [chiaki-ng](https://github.com/streetpea/chiaki-ng) by Street Pea and contributors, derived from [Chiaki](https://git.sr.ht/~thestr4ng3r/chiaki) by Florian Märkl. Not endorsed or certified by Sony Interactive Entertainment. "PlayStation", "PS4", "PS5", "DualShock" and "DualSense" are trademarks of Sony Interactive Entertainment Inc.
