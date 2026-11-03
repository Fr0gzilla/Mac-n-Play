// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Qualité d'image des parties par Internet.
//
// Rôle unique : choisir une définition raisonnable au départ d'une partie à distance,
// puis surveiller les pertes de l'image et demander une définition plus basse si
// elles durent. La relance de la partie elle-même reste le rôle de QmlBackend.
#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QTimer>

class StreamSession;

class RemoteQualityGuard : public QObject
{
    Q_OBJECT

public:
    explicit RemoteQualityGuard(QObject *parent = nullptr);

    // le Mac passe-t-il par le partage de connexion d'un téléphone ?
    static bool onPhoneHotspot();
    // préréglage de départ (1 = 360p … 4 = 1080p) pour une partie à distance
    static int startPreset(int chosen_preset);
    static QString presetName(int preset);

    // surveille la partie à distance en cours, jouée dans ce préréglage
    void watch(StreamSession *session, int preset);
    void stop();

signals:
    // les pertes durent : relancer la partie dans ce préréglage
    void lowerRequested(int preset);

private:
    void checkLosses();

    QPointer<StreamSession> session;
    QTimer timer;
    int preset = 0;
    int seconds_with_high_loss = 0;
};
