// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Catégories du journal de Mac'n'Play : une par domaine, pour savoir d'un coup d'œil
// d'où vient un message (et donc une panne). Chaque ligne du journal porte le nom
// de sa catégorie, par exemple « [macnplay.psn] Profil PSN reçu ».
#pragma once

#include <QLoggingCategory>

Q_DECLARE_LOGGING_CATEGORY(logPsn)         // compte PlayStation Network : connexion, jetons, profil
Q_DECLARE_LOGGING_CATEGORY(logConsoles)    // consoles : découverte, association, réveil, masquage
Q_DECLARE_LOGGING_CATEGORY(logSession)     // partie en cours : lancement, arrêt, qualité
Q_DECLARE_LOGGING_CATEGORY(logController)  // manettes : branchement, attribution des boutons

#include <chiaki/log.h>

// pour la bibliothèque Chiaki (en C) : ses messages rejoignent le journal dans la catégorie
// donnée en « user » (un pointeur vers une des catégories ci-dessus), par exemple
//   chiaki_log_init(&log, mask, ChiakiLogToJournal, const_cast<QLoggingCategory *>(&logConsoles()));
void ChiakiLogToJournal(ChiakiLogLevel level, const char *msg, void *user);
