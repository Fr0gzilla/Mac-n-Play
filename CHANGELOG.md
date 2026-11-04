# Historique des versions

## En cours (prochaine version)

- Sécurité : journal copié anonymisé (adresses, identifiants, pseudo, noms des consoles masqués), et anonymisé dès l'écriture quand « Masquer les adresses » est coché ; export des réglages sans les jetons du compte PSN ; vérification des nouvelles versions désactivable.
- Consoles désignées par une clé stable (adresse MAC, identifiant PSN) plutôt que par leur rang dans la liste.
- « Tester ma connexion » mesure le temps de réponse sur une connexion déjà ouverte (moins de « lent » à tort).
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
