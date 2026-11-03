// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Contrôleur (MVC) des manettes branchées.
//
// Rôle unique : tenir la liste des manettes reliées au Mac et leur transmettre
// la combinaison qui ouvre le menu en jeu.
//   - Modèle : ControllerManager (manettes vues par SDL) et Settings (combinaison, arrière-plan).
//   - Vue    : l'accueil et les Paramètres, via « Chiaki.controllers ».
// Le réglage des boutons d'une manette est confié à ControllerMappingController.
#pragma once

#include <QHash>
#include <QList>
#include <QObject>

class Settings;
class QmlController;
class QmlMainWindow;
class ControllerMappingController;

class ConnectedControllers : public QObject
{
    Q_OBJECT

public:
    ConnectedControllers(Settings *settings, QmlMainWindow *window, QObject *parent = nullptr);

    void setSettings(Settings *settings) { this->settings = settings; }
    // à appeler une fois le réglage des boutons créé : il suit les manettes branchées
    void setMappingController(ControllerMappingController *mapping) { this->mapping = mapping; }

    QList<QmlController*> list() const { return controllers.values(); }
    const QHash<int, QmlController*> *byDeviceId() const { return &controllers; }

    // relit les manettes disponibles : ouvre les nouvelles, oublie celles débranchées
    void refresh();
    // la combinaison du menu en jeu a changé dans les Paramètres
    void applyStreamMenuShortcut();
    // les manettes fonctionnent-elles quand une autre appli est au premier plan ?
    void applyBackgroundEvents();
    // l'appli passe au premier plan ou en arrière-plan
    void applyAppActive();

signals:
    void listChanged();

private:
    // combinaison du menu en jeu sous forme de masque de boutons (0 = désactivé)
    uint32_t streamMenuShortcut() const;

    Settings *settings;
    QmlMainWindow *window;
    ControllerMappingController *mapping = nullptr;
    QHash<int, QmlController*> controllers;
};
