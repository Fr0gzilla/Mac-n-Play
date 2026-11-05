> **Vous avez installé la 1.1.0-beta ?** Elle ne vous préviendra pas de cette version (un défaut de son numéro de version, corrigé depuis la 1.1.0) : téléchargez-la ci-dessous à la main. Les versions suivantes seront bien annoncées dans l'appli.
>
> L'accès au micro sera redemandé une fois : l'appli a maintenant son propre identifiant macOS, distinct de chiaki-ng.

**Pour Mac avec puce Apple (M1 à M5), macOS 15 ou plus récent.**

### Correctifs de la 1.1.1

- **macOS 13 et 14** : l'appli s'ouvrait puis se fermait sans explication. macOS indique maintenant clairement qu'il faut macOS 15.
- **« Tester ma connexion »** affiche « Internet répond en X ms », sans promettre la fluidité de la partie.
- **Homebrew** : `brew uninstall --zap macnplay` efface aussi le cache et l'état des fenêtres.

### Nouveautés de la 1.1

- **Jeu hors de chez soi plus fiable** : la qualité s'adapte toute seule à la connexion (360p sur un partage de connexion de téléphone, 540p ailleurs) et baisse d'un cran si l'image saccade. Un message indique quand vous jouez par Internet.
- **« Tester ma connexion »** (Paramètres › Configuration) : vérifie le réseau du Mac, Internet, le compte PSN et la console, et explique ce qui bloque.
- **Contenu protégé** (YouTube, Netflix… ouverts sur la console) : la manette n'est plus bloquée, le bouton PS ramène la console à son accueil.
- **Carte du compte PSN** gardée sur le Mac : elle s'affiche dès le lancement, même hors ligne, et s'actualise toutes les 5 minutes.
- **Nouvelles versions signalées** sur l'accueil.
- **Une seule copie de l'appli à la fois** : fini la console bloquée par deux fenêtres ouvertes.
- **Journal** à copier en un clic pour signaler un problème.
- **Nouvelle icône** au format de macOS 26.
- Le vrai nom de votre PS4 sur sa carte, au lieu de « Main PS4 Console ».
- **Image propre dès le début d'une partie** : plus de triangles ni de couleurs délavées quand la connexion perd la première image.
- **Menu en jeu (Ctrl+O)** fluide, et immédiat après sa première ouverture.
- **Plus sûr** : le journal copié masque vos adresses et votre pseudo, l'export des réglages ne contient plus vos identifiants PSN.

### Installation

1. Téléchargez le fichier `.dmg` ci-dessous, ouvrez-le et glissez Mac'n'Play dans Applications. Ou avec Homebrew : `brew upgrade --cask macnplay`.
2. Au premier lancement, macOS bloque l'appli (elle n'est pas enregistrée auprès d'Apple) : Réglages Système › Confidentialité et sécurité › **Ouvrir quand même**.

Le mode d'emploi complet est sur la [page d'accueil du projet](https://github.com/Fr0gzilla/Mac-n-Play#readme).
