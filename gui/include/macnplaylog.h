// Catégories du journal de Mac'n'Play : une par domaine, pour savoir d'un coup d'œil
// d'où vient un message (et donc une panne). Chaque ligne du journal porte le nom
// de sa catégorie, par exemple « [macnplay.psn] Profil PSN reçu ».
#pragma once

#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(logPsn)         // compte PlayStation Network : connexion, jetons, profil
Q_DECLARE_LOGGING_CATEGORY(logConsoles)    // consoles : découverte, association, réveil, masquage
Q_DECLARE_LOGGING_CATEGORY(logSession)     // partie en cours : lancement, arrêt, qualité
Q_DECLARE_LOGGING_CATEGORY(logController)  // manettes : branchement, attribution des boutons
