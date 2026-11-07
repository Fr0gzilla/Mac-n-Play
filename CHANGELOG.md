# Historique des versions

## En cours (prochaine version)

- La connexion automatique n'allume plus jamais la console : elle lance la partie seulement si la console est déjà allumée chez vous. Une console en mode repos attend « Jouer ».
- Quitter l'appli pendant la demande du code PIN de connexion la figeait : elle se ferme normalement.
- La fenêtre du code PIN de connexion s'adapte à son titre traduit, qui était coupé en français.

## 1.2.1 — 7 novembre 2026

- La demande d'accès au micro a aussi son texte anglais dans un dossier de langue, comme les autres langues (conseil d'Apple, évite un mélange chez qui a l'anglais puis une autre langue dans ses préférences).
- La fabrication vérifie que la demande du micro existe dans les 6 langues, et que le texte anglais est le même dans ses deux exemplaires.

## 1.2.0 — 7 novembre 2026

- L'appli parle allemand, espagnol, italien et portugais du Brésil, en plus du français et de l'anglais : elle suit la langue du Mac, ou celle choisie dans Paramètres › Tous les réglages › Général › Langue, appliquée sans relancer. macOS retient ce choix pour ses propres messages.
- La demande d'accès au micro est traduite dans chaque langue.
- README : les serveurs STUN publics (jeu hors de chez soi) sont mentionnés dans « Vie privée ».
- Vérification des traductions étendue à chaque langue (textes manquants, `%1` perdus).

## 1.1.1 — 5 novembre 2026

- « Tester ma connexion » dit « Internet répond en X ms » : la mesure vise un serveur proche de chez vous, pas votre console.
- Choix de la console de « L'essentiel » sorti des écrans vers les règles métier, avec son test.
- L'appli annonce macOS 15 minimum (elle disait 13 et plantait au lancement sur macOS 13 et 14 au lieu de prévenir) ; la fabrication vérifie ce minimum et la version de chaque OpenSSL embarquée.
- Homebrew : `brew uninstall --zap` efface aussi le cache et l'état des fenêtres.

## 1.1.0 — 5 novembre 2026

- Sécurité : journal copié anonymisé (adresses, identifiants, pseudo, noms des consoles masqués), et anonymisé dès l'écriture quand « Masquer les adresses » est coché ; export des réglages sans les jetons du compte PSN ; vérification des nouvelles versions désactivable.
- Consoles désignées par une clé stable (adresse MAC, identifiant PSN) plutôt que par leur rang dans la liste.
- « Tester ma connexion » mesure le vrai aller-retour vers Sony (et non le temps de réponse de son site web, qui affichait « lent » à tort).
- Menu en jeu (Ctrl+O) : glissade fluide, et fenêtre gardée prête après la première ouverture (elle mettait 2 s à apparaître).
- Une PS5 vue sur le Wi-Fi mais pas associée n'affiche plus votre compte PSN, et « L'essentiel » règle d'abord votre console associée.
- Connexion automatique par Internet : la PS4 retenue est retrouvée dans le compte PSN, où Sony l'appelle « Main PS4 Console ».
- Numéro de version de l'appli : macOS voyait 1.10.0 (celui de chiaki-ng), ce qui empêchait d'annoncer les nouvelles versions.
- Image abîmée au début d'une partie (triangles, couleurs délavées) : une image complète est redemandée à la console dès qu'une image est refusée.
- Corrections :
  - mauvaise console lancée au clic dans certains cas ;
  - déconnexion PSN incomplète ;
  - plantages possibles (profil PSN, accès simultané aux consoles du compte) ;
  - fuite de l'assistant d'ajout ;
  - trois bugs de l'attribution des boutons ;
  - PS5 qui disparaissaient après une panne réseau passagère ;
  - consoles de l'ancien compte qui revenaient après une déconnexion ;
  - qualité des cartes de l'accueil pas mise à jour ;
  - jeton PSN refusé compté deux fois ;
  - compte PSN pas déconnecté à l'import de réglages ;
  - réglage PS4 Pro perdu dans les autres profils.
- L'appli a son propre identifiant macOS (`com.macnplay.MacnPlay`) : permissions séparées de chiaki-ng (l'accès au micro est redemandé une fois).
- Code : restes de chiaki-ng inutiles sur Mac retirés, tests automatiques à chaque envoi, vérification des traductions, mise en forme du code (`.clang-format`).

## 1.1.0-beta — 3 novembre 2026 (pré-version)

- Jeu par Internet : qualité adaptée à la connexion au départ, baisse automatique si l'image saccade, message « Partie par Internet ».
- « Tester ma connexion » : réseau du Mac, Internet, compte PSN et console, expliqués en clair.
- Contenu protégé sur la console (YouTube, Netflix…) : la manette n'est plus bloquée, le bouton PS ramène la console à son accueil.
- Carte du compte PSN gardée sur le Mac (affichée hors ligne), actualisée toutes les 5 minutes.
- Nouvelles versions signalées sur l'accueil.
- Une seule copie de l'appli à la fois.
- Journal à copier en un clic.
- Nouvelle icône au format de macOS 26 ; demande d'accès au micro au nom de Mac'n'Play.
- Le vrai nom de la PS4 sur sa carte.
- Code réorganisé en modèle MVC (voir `ARCHITECTURE.md`), premiers tests automatiques.

## 1.0.0 — 3 novembre 2026

Première version publique : Remote Play PS4/PS5 pour Mac avec puce Apple (macOS 15 et plus),
interface en français, accueil à la manette, compte PSN, menu en jeu, deux consoles, assistant d'ajout.
