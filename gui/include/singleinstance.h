// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Une seule copie de Mac'n'Play à la fois.
//
// Deux copies ouvertes en même temps (par exemple une ancienne version restée dans
// Téléchargements) se disputent la console, qui refuse alors toute partie
// (« Remote is already in use »). La deuxième copie prévient la première, qui revient
// au premier plan, puis se ferme.
#pragma once

#include <QObject>
#include <QString>

class QLocalServer;

class SingleInstance : public QObject
{
    Q_OBJECT

public:
    explicit SingleInstance(QString key, QObject *parent = nullptr);

    // true : cette copie est la seule et devient la copie principale ;
    // false : une autre copie tourne déjà (elle a été prévenue), celle-ci doit se fermer
    bool claim();

signals:
    // une autre copie vient d'essayer de démarrer : il faut montrer la fenêtre
    void activationRequested();

private:
    QString key;
    QLocalServer *server = nullptr;
};
