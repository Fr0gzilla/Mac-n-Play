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

public:
    static constexpr int MAX_CONSOLES = MacnPlayRules::MAX_CONSOLES;

    ConsoleRegistry(Settings *settings, QObject *parent = nullptr);

    void setSettings(Settings *settings);

    QVariantList list() const;
    QVariantList hidden() const;
    bool discoveryEnabled() const { return discovery_manager.GetActive(); }
    void setDiscoveryEnabled(bool enabled);
    int maxConsoles() const { return MAX_CONSOLES; }
    int registeredCount() const;
    bool limitReached() const { return MacnPlayRules::consoleLimitReached(registeredCount()); }

    // la console à la position « index » de la liste de l'accueil (valid = false si aucune)
    ConsoleEntry consoleAt(int index) const;
    // position dans la liste de la console du compte PSN nommée « nickname » (-1 si absente)
    int psnConsoleIndex(const QString &nickname) const;
    const QList<DiscoveryHost> discoveredHosts() const { return discovery_manager.GetHosts(); }

    // envoie le signal de réveil ; en cas d'échec, prévient l'utilisateur et renvoie false
    bool sendWakeup(const QString &address, const QByteArray &regist_key, bool ps5);
    // une console qui se réveille ou s'endort disparaît un instant du réseau :
    // pendant ce temps, on ne la propose pas une deuxième fois via le compte PSN
    void markWaking(const QString &nickname);
    // redemande au compte PSN ses consoles (en tâche de fond)
    void refreshPsnConsoles();

    // console en attente d'association (assistant d'ajout ouvert depuis l'accueil)
    void setPendingRegistration(const ConsoleEntry &entry) { pending_registration = entry; }
    const ConsoleEntry &pendingRegistration() const { return pending_registration; }

    Q_INVOKABLE void wakeUp(int index, QString nickname = QString());
    Q_INVOKABLE void setConsolePin(int index, QString console_pin);
    Q_INVOKABLE void addManualHost(int index, const QString &address);
    Q_INVOKABLE void deleteManualHost(int index);
    Q_INVOKABLE void hide(const QString &mac, const QString &nickname);
    Q_INVOKABLE void unhide(const QString &mac);
    // associe une console avec le code PIN affiché sur celle-ci ;
    // la progression passe par callback(message, réussi, fini)
    Q_INVOKABLE bool registerConsole(const QString &address, const QString &psn_id, const QString &pin, const QString &cpin, bool broadcast, int target, const QJSValue &callback);

signals:
    void listChanged();
    void hiddenChanged();
    void discoveryEnabledChanged();
    // le réseau a donné des nouvelles des consoles (état, nom…)
    void discoveredHostsUpdated();
    void error(const QString &title, const QString &text);

private:
    void fetchPsnConsoles();
    static bool parseMac(const QString &mac_string, HostMAC *mac);

    Settings *settings = nullptr;
    DiscoveryManager discovery_manager;
    // consoles du compte PSN associées à Mac'n'Play, par identifiant (duid)
    QMap<QString, PsnHost> psn_hosts;
    // toutes les consoles du compte PSN, par nom
    QMap<QString, PsnHost> psn_nickname_hosts;
    QList<QString> waking_nicknames;
    bool fetching_psn_consoles = false;
    QFutureWatcher<void> psn_consoles_watcher;
    ConsoleEntry pending_registration;
};
