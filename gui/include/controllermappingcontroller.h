// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Contrôleur (MVC) de l'attribution des boutons de la manette.
//
// Rôle unique : permettre à l'utilisateur de choisir quel bouton physique de sa manette
// fait quelle action PlayStation (✕, ○, L1…), puis enregistrer ce choix.
//   - Modèle : Settings (affectations enregistrées par modèle de manette, clé VID:PID)
//     et la table de correspondance SDL de chaque manette.
//   - Vue    : ControllerMappingDialog.qml et l'onglet Manettes des Paramètres,
//     qui l'utilisent sous le nom « Chiaki.controllerMapping ».
#pragma once

#include <QObject>
#include <QHash>
#include <QMap>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class Settings;
class Controller;
class QmlController;

class ControllerMappingController : public QObject
{
    Q_OBJECT
    // une affectation est en cours de réglage (une manette a été choisie)
    Q_PROPERTY(bool inProgress READ inProgress NOTIFY inProgressChanged)
    // chaque action PlayStation avec les boutons physiques qui la déclenchent
    Q_PROPERTY(QVariantList mapping READ mapping NOTIFY mappingChanged)
    // nom du modèle de la manette en cours de réglage
    Q_PROPERTY(QString controllerType READ controllerType NOTIFY controllerTypeChanged)
    // la manette utilise encore l'affectation d'origine
    Q_PROPERTY(bool defaultMapping READ defaultMapping NOTIFY defaultMappingChanged)
    // des changements n'ont pas encore été appliqués
    Q_PROPERTY(bool altered READ altered NOTIFY alteredChanged)
    // les sticks analogiques peuvent eux aussi être réaffectés
    Q_PROPERTY(bool analogStickMapping READ analogStickMapping WRITE setAnalogStickMapping NOTIFY analogStickMappingChanged)

public:
    ControllerMappingController(Settings *settings, const QHash<int, QmlController*> *controllers, QObject *parent = nullptr);

    // le profil de réglages a changé : on suit le nouveau
    void setSettings(Settings *settings);

    // appelés par la gestion des manettes quand une manette apparaît ou disparaît
    void controllerOpened(Controller *controller);
    void controllerClosed(int device_id);

    // applique à SDL les affectations enregistrées des manettes branchées
    void applySavedMappings();

    bool inProgress() const { return in_progress; }
    QVariantList mapping() const;
    QString controllerType() const { return controller_type; }
    bool defaultMapping() const { return default_mapping; }
    bool altered() const { return is_altered; }
    bool analogStickMapping() const { return analog_stick_mapping; }
    void setAnalogStickMapping(bool enabled);

    // déroulement d'un réglage : begin → (choix de la manette) → assign… → apply ou quit
    Q_INVOKABLE void begin(bool reset_requested);
    Q_INVOKABLE void assignPhysicalButton(QString physical_button, int chiaki_button);
    Q_INVOKABLE void apply();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void quit();

    // boutons physiques de la manette en cours de réglage, avec l'action de chacun (0 = aucune)
    Q_INVOKABLE QVariantList physicalButtons() const;
    // affectation enregistrée de la première manette branchée : bouton physique → action
    Q_INVOKABLE QVariantMap physicalButtonActions() const;

    // capture d'un bouton pour la navigation dans l'appli (Paramètres › Touches › Manette)
    Q_INVOKABLE void startNavCapture();
    Q_INVOKABLE void stopNavCapture();

signals:
    void inProgressChanged();
    void mappingChanged();
    void controllerTypeChanged();
    void defaultMappingChanged();
    void alteredChanged();
    void analogStickMappingChanged();
    void steamControllerSelected();
    void navButtonCaptured(uint button);

private:
    void startWith(Controller *controller);
    void setWaitingForController(bool waiting);
    void setInProgress(bool value);
    void setDefaultMapping(bool value);
    void setAltered(bool value);
    void abortStart();
    void restoreOriginalMapping();
    void rememberGuidToUpdate(const QString &vid_pid, const QString &guid);
    static void addSdlMapping(const QString &guid, const QString &mapping);

    Settings *settings;
    const QHash<int, QmlController*> *controllers;

    // manette en cours de réglage
    Controller *controller = nullptr;
    int device_id = -1;
    QString guid;
    QString vid_pid;
    QString controller_type;
    // action SDL (« a », « dpup »…) → boutons physiques (« b0 », « h0.1 »…)
    QMap<QString, QStringList> current_mappings;
    // même table, telle qu'elle était au dernier « Appliquer »
    QMap<QString, QStringList> applied_mappings;
    // bouton physique → action SDL (vide = aucune)
    QMap<QString, QString> physical_to_action;

    // table SDL d'origine de chaque manette (clé GUID), pour pouvoir revenir en arrière
    QMap<QString, QString> original_mappings;
    // manettes (GUID) dont l'affectation enregistrée doit encore être appliquée, par VID:PID
    QMap<QString, QStringList> guids_to_update;

    bool in_progress = false;
    bool reset_requested = false;
    bool default_mapping = false;
    bool is_altered = false;
    bool analog_stick_mapping = false;
};
