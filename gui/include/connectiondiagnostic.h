// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Diagnostic « Tester ma connexion » (Paramètres › Configuration).
//
// Rôle unique : vérifier, étape par étape, ce dont une partie a besoin, et le dire en clair :
// le réseau du Mac, l'accès à Internet, le compte PSN et la présence de la console sur ce réseau.
// Il ne modifie rien : il observe et explique.
#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QVariantList>

class QNetworkAccessManager;
class ConsoleRegistry;
class PsnAccount;
class Settings;

class ConnectionDiagnostic : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY changed)
    // une ligne par vérification : { title, status ("ok" | "warning" | "error"), detail }
    Q_PROPERTY(QVariantList results READ results NOTIFY changed)

public:
    ConnectionDiagnostic(Settings *settings, ConsoleRegistry *consoles, PsnAccount *psn, QObject *parent = nullptr);
    void setSettings(Settings *settings) { this->settings = settings; }

    bool running() const { return is_running; }
    QVariantList results() const { return check_results; }

    Q_INVOKABLE void start();

signals:
    void changed();

private:
    void checkLocalNetwork();
    void checkInternet();
    void measureLatency(int remaining);
    void checkPsnAccount();
    void checkConsole();
    void add(const QString &title, const QString &status, const QString &detail);
    void finish();

    Settings *settings;
    ConsoleRegistry *consoles;
    PsnAccount *psn;
    QNetworkAccessManager *network;
    QElapsedTimer internet_timer;
    // meilleur aller-retour mesuré vers Sony (ms), -1 tant qu'aucune mesure n'a abouti
    qint64 best_latency = -1;
    bool is_running = false;
    QVariantList check_results;
};
