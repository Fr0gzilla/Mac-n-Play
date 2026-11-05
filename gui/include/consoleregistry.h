// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Contrôleur (MVC) des consoles.
//
// Rôle unique : savoir quelles consoles existent et agir sur elles hors partie :
// les découvrir sur le réseau, lister celles du compte PSN, les associer, les réveiller,
// les masquer, et faire respecter la limite de consoles associées.
//   - Modèle : Settings (consoles associées, ajoutées à la main, masquées),
//     DiscoveryManager (consoles qui répondent sur le réseau) et le compte PSN.
//   - Vue    : l'accueil, l'assistant d'ajout et l'onglet Consoles des Paramètres,
//     qui l'utilisent sous le nom « Chiaki.consoles ».
// Lancer une partie sur une console n'est pas son rôle : voir QmlBackend (la partie).
#pragma once

#include "discoverymanager.h"
#include "host.h"
#include "macnplayrules.h"

#include <QFutureWatcher>
#include <QJSValue>
#include <QObject>
#include <QSet>
#include <QVariantList>

class Settings;

// une console telle qu'elle apparaît dans la liste de l'accueil
struct ConsoleEntry
{
    bool valid = false;

    // trouvée sur le réseau local
    bool discovered = false;
    DiscoveryHost discovery_host;
    // ajoutée à la main par son adresse
    ManualHost manual_host;
    // connue par le compte PSN (pour jouer à distance)
    PsnHost psn_host;
    QString duid;
    // associée (code PIN déjà saisi)
    bool registered = false;
    RegisteredHost registered_host;

    QString address() const { return discovered ? discovery_host.host_addr : manual_host.GetHost(); }
    bool isPS5() const
    {
        if(discovered)
            return discovery_host.ps5;
        return registered ? chiaki_target_is_ps5(registered_host.GetTarget()) : true;
    }
};

class ConsoleRegistry : public QObject
{
    Q_OBJECT
    // consoles affichées sur l'accueil : trouvées sur le réseau, ajoutées à la main, puis du compte PSN
    Q_PROPERTY(QVariantList list READ list NOTIFY listChanged)
    // consoles masquées par l'utilisateur (Paramètres › Consoles › Réafficher)
    Q_PROPERTY(QVariantList hidden READ hidden NOTIFY hiddenChanged)
    Q_PROPERTY(bool discoveryEnabled READ discoveryEnabled WRITE setDiscoveryEnabled NOTIFY discoveryEnabledChanged)
    // nombre maximal de consoles associées à Mac'n'Play
    Q_PROPERTY(int maxConsoles READ maxConsoles CONSTANT)
    Q_PROPERTY(int registeredCount READ registeredCount NOTIFY listChanged)
    Q_PROPERTY(bool limitReached READ limitReached NOTIFY listChanged)
    // adresse à donner à registerConsole pour chercher la console sur tout le réseau local
    Q_PROPERTY(QString broadcastAddress READ broadcastAddress CONSTANT)

public:
    static constexpr int MAX_CONSOLES = MacnPlayRules::MAX_CONSOLES;
    static constexpr const char *BROADCAST_ADDRESS = "255.255.255.255";

    ConsoleRegistry(Settings *settings, QObject *parent = nullptr);

    void setSettings(Settings *settings);

    QVariantList list() const;
    QVariantList hidden() const;
    bool discoveryEnabled() const { return discovery_manager.GetActive(); }
    void setDiscoveryEnabled(bool enabled);
    int maxConsoles() const { return MAX_CONSOLES; }
    QString broadcastAddress() const { return QString::fromLatin1(BROADCAST_ADDRESS); }
    int registeredCount() const;
    bool limitReached() const { return MacnPlayRules::consoleLimitReached(registeredCount()); }

    // la console de clé « key » (champ « key » de list() ; valid = false si aucune)
    ConsoleEntry consoleByKey(const QString &key) const;
    // clé d'une console trouvée sur le réseau local
    static QString DiscoveredKey(const HostMAC &mac);
    static QString PsnKey(const QString &duid);
    // clé de la console du compte PSN nommée « nickname » (vide si absente)
    QString psnConsoleKey(const QString &nickname) const;
    const QList<DiscoveryHost> discoveredHosts() const { return discovery_manager.GetHosts(); }

    // envoie le signal de réveil ; en cas d'échec, prévient l'utilisateur et renvoie false
    bool sendWakeup(const QString &address, const QByteArray &regist_key, bool ps5);
    // une console qui se réveille ou s'endort disparaît un instant du réseau :
    // pendant ce temps, on ne la propose pas une deuxième fois via le compte PSN
    void markWaking(const QString &nickname);
    // redemande au compte PSN ses consoles (en tâche de fond)
    void refreshPsnConsoles();
    // oublie les consoles du compte (déconnexion ou changement de compte)
    void clearPsnConsoles();

    // console en attente d'association (assistant d'ajout ouvert depuis l'accueil)
    void setPendingRegistration(const ConsoleEntry &entry) { pending_registration = entry; }
    const ConsoleEntry &pendingRegistration() const { return pending_registration; }

    // rang, dans list, de la console réglée par « L'essentiel » (règle settingsConsoleIndex), -1 si aucune
    Q_INVOKABLE int settingsConsoleIndex(const QVariantList &consoles) const;
    Q_INVOKABLE void wakeUp(const QString &key, QString nickname = QString());
    Q_INVOKABLE void setConsolePin(const QString &key, QString console_pin);
    Q_INVOKABLE void addManualHost(int index, const QString &address);
    Q_INVOKABLE void deleteManualHost(const QString &key);
    Q_INVOKABLE void hide(const QString &mac, const QString &nickname);
    Q_INVOKABLE void unhide(const QString &mac);
    // associe une console avec le code PIN affiché sur celle-ci ;
    // la progression passe par callback(message, réussi, fini)
    Q_INVOKABLE bool registerConsole(const QString &address, const QString &psn_id, const QString &pin, const QString &cpin, int target, const QJSValue &callback);

signals:
    void listChanged();
    void hiddenChanged();
    void discoveryEnabledChanged();
    // le réseau a donné des nouvelles des consoles (état, nom…)
    void discoveredHostsUpdated();
    void error(const QString &title, const QString &text);

private:
    // une ligne de l'accueil : ce qui est affiché et la console sur laquelle on agit
    struct Row
    {
        ConsoleEntry entry;
        QVariantMap view;
    };
    QList<Row> rows() const;

    // ce que la tâche de fond reçoit (copie) et ce qu'elle rend
    struct PsnRequest
    {
        QString token;
        uint32_t log_mask = 0;
        QSet<QString> registered_nicknames;
        int registered_ps4s = 0;
        // génération des listes au moment de la demande (voir psn_generation)
        int generation = 0;
    };
    struct PsnConsoles
    {
        bool valid = false;
        // la liste des PS5 a bien été reçue (sinon on garde celles déjà connues)
        bool ps5_received = false;
        int generation = 0;
        QMap<QString, PsnHost> usable;
        QMap<QString, PsnHost> by_nickname;
    };
    static PsnConsoles fetchPsnConsoles(PsnRequest request);
    void onPsnConsolesFetched();
    // nom de la PS4 associée (vide s'il n'y en a pas)
    QString registeredPs4Name() const;
    static bool parseMac(const QString &mac_string, HostMAC *mac);

    Settings *settings = nullptr;
    DiscoveryManager discovery_manager;
    // consoles du compte PSN associées à Mac'n'Play, par identifiant (duid)
    QMap<QString, PsnHost> psn_hosts;
    // toutes les consoles du compte PSN, par nom
    QMap<QString, PsnHost> psn_nickname_hosts;
    QList<QString> waking_nicknames;
    QFutureWatcher<PsnConsoles> psn_consoles_watcher;
    // augmentée à chaque oubli des consoles (déconnexion, changement de profil) : une réponse
    // demandée avant l'oubli concerne l'ancien compte et doit être ignorée
    int psn_generation = 0;
    ConsoleEntry pending_registration;
};
