// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "consoleregistry.h"
#include "settings.h"
#include "macnplaylog.h"
#include "exception.h"

#include "chiaki/remote/holepunch.h"
#include "chiaki/regist.h"

#include <QTimer>
#include <QtConcurrent>

// nombre d'essais pour obtenir la liste des PS5 du compte
static const int PSN_DEVICES_TRIES = 2;
// durée pendant laquelle une console qui se réveille n'est pas proposée via le compte PSN
static const int WAKEUP_PSN_IGNORE_SECONDS = 10;
// adresse MAC de la PS5 de démonstration (MACNPLAY_DEMO_PS5)
static const char *DEMO_CONSOLE_MAC = "000000000000";
// nom que Sony donne à la PS4 principale du compte (une seule PS4 peut jouer à distance)
static const QString MAIN_PS4_NAME = QStringLiteral("Main PS4 Console");

// association avec une console : fait le lien entre la bibliothèque Chiaki (fil séparé) et Qt.
// L'objet est détruit dans le fil de l'interface une fois l'association terminée ;
// son destructeur attend la fin du fil de la bibliothèque et libère ses ressources.
class ConsoleRegistration : public QObject
{
    Q_OBJECT

public:
    ConsoleRegistration(uint32_t log_mask, QObject *parent)
        : QObject(parent)
    {
        chiaki_log_init(&chiaki_log, log_mask, &ConsoleRegistration::onLog, this);
    }

    ~ConsoleRegistration() override
    {
        if(started)
        {
            chiaki_regist_stop(&chiaki_regist);
            chiaki_regist_fini(&chiaki_regist);
        }
    }

    // false si l'association n'a même pas pu démarrer
    bool start(const ChiakiRegistInfo &info)
    {
        started = chiaki_regist_start(&chiaki_regist, &chiaki_log, &info, &ConsoleRegistration::onEvent, this) == CHIAKI_ERR_SUCCESS;
        return started;
    }

signals:
    void log(ChiakiLogLevel level, const QString &msg);
    void failed();
    void succeeded(const RegisteredHost &host);

private:
    static void onLog(ChiakiLogLevel level, const char *msg, void *user)
    {
        ChiakiLogToJournal(level, msg, const_cast<QLoggingCategory *>(&logConsoles()));
        auto self = static_cast<ConsoleRegistration *>(user);
        QMetaObject::invokeMethod(self, std::bind(&ConsoleRegistration::log, self, level, QString::fromUtf8(msg)), Qt::QueuedConnection);
    }

    // appelé dans le fil de la bibliothèque : tout est renvoyé au fil de l'interface
    static void onEvent(ChiakiRegistEvent *event, void *user)
    {
        auto self = static_cast<ConsoleRegistration *>(user);
        switch(event->type)
        {
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
                QMetaObject::invokeMethod(self, std::bind(&ConsoleRegistration::succeeded, self, *event->registered_host), Qt::QueuedConnection);
                break;
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED:
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED:
                QMetaObject::invokeMethod(self, &ConsoleRegistration::failed, Qt::QueuedConnection);
                break;
        }
    }

    ChiakiLog chiaki_log;
    ChiakiRegist chiaki_regist;
    bool started = false;
};

ConsoleRegistry::ConsoleRegistry(Settings *settings, QObject *parent)
    : QObject(parent)
{
    connect(&psn_consoles_watcher, &QFutureWatcher<PsnConsoles>::finished, this, &ConsoleRegistry::onPsnConsolesFetched);
    connect(&discovery_manager, &DiscoveryManager::HostsUpdated, this, [this] {
        emit discoveredHostsUpdated();
        emit listChanged();
    });
    setSettings(settings);
    setDiscoveryEnabled(true);
}

void ConsoleRegistry::setSettings(Settings *new_settings)
{
    if(settings)
        disconnect(settings, nullptr, this, nullptr);
    settings = new_settings;
    // autre profil de réglages : les consoles du compte seront redemandées
    psn_hosts.clear();
    psn_nickname_hosts.clear();
    connect(settings, &Settings::RegisteredHostsUpdated, this, &ConsoleRegistry::listChanged);
    connect(settings, &Settings::ManualHostsUpdated, this, &ConsoleRegistry::listChanged);
    connect(settings, &Settings::HiddenHostsUpdated, this, &ConsoleRegistry::hiddenChanged);
    discovery_manager.SetSettings(settings);
    emit listChanged();
    emit hiddenChanged();
}

void ConsoleRegistry::setDiscoveryEnabled(bool enabled)
{
    discovery_manager.SetActive(enabled);
    emit discoveryEnabledChanged();
}

int ConsoleRegistry::registeredCount() const
{
    return settings->GetRegisteredHosts().size();
}

// la liste de l'accueil, construite en un seul endroit : ce qui est affiché (map pour le QML)
// et ce sur quoi on agit (ConsoleEntry) viennent de la même boucle. Chaque ligne a une clé
// stable (« mac:… », « manual:… », « psn:… ») : les écrans désignent une console par sa clé,
// pas par sa position, qui peut changer quand le réseau répond
QList<ConsoleRegistry::Row> ConsoleRegistry::rows() const
{
    QList<Row> out;
    QList<QString> local_nicknames;
    QList<ManualHost> discovered_manual_hosts;
    int registered_discovered_ps4s = 0;
    const auto manual_hosts = settings->GetManualHosts();

    // 1. consoles qui répondent sur le réseau local
    for(const auto &host : discovery_manager.GetHosts())
    {
        const HostMAC host_mac = host.GetHostMAC();
        const bool registered = settings->GetRegisteredHostRegistered(host_mac);
        bool hidden = settings->GetHiddenHostHidden(host_mac);
        // une console associée ne reste jamais masquée
        if(registered && hidden)
        {
            settings->RemoveHiddenHost(host_mac);
            hidden = false;
        }
        // une console masquée garde son nom à jour
        if(hidden)
        {
            auto hidden_host = settings->GetHiddenHost(host_mac);
            if(hidden_host.GetNickname() != host.host_name)
            {
                hidden_host.SetNickname(host.host_name);
                settings->RemoveHiddenHost(host_mac);
                settings->AddHiddenHost(hidden_host);
            }
        }
        Row row;
        row.entry.valid = true;
        row.entry.discovered = true;
        row.entry.discovery_host = host;
        row.entry.registered = registered;
        if(registered)
            row.entry.registered_host = settings->GetRegisteredHost(host_mac);
        else if(psn_nickname_hosts.contains(host.host_name))
            row.entry.duid = psn_nickname_hosts.value(host.host_name).GetDuid();
        else if(!host.ps5)
            row.entry.duid = psn_nickname_hosts.value(MAIN_PS4_NAME).GetDuid();
        bool manual = false;
        for(const auto &manual_host : manual_hosts)
        {
            if(manual_host.GetRegistered() && manual_host.GetMAC() == host_mac && manual_host.GetHost() == host.host_addr)
            {
                manual = true;
                discovered_manual_hosts.append(manual_host);
                row.entry.manual_host = manual_host;
            }
        }
        QVariantMap &m = row.view;
        m["key"] = DiscoveredKey(host_mac);
        m["discovered"] = true;
        m["manual"] = manual;
        m["name"] = host.host_name;
        m["duid"] = row.entry.duid;
        m["address"] = host.host_addr;
        m["ps5"] = host.ps5;
        m["mac"] = host_mac.ToString();
        m["state"] = chiaki_discovery_host_state_string(host.state);
        m["app"] = host.running_app_name;
        m["titleId"] = host.running_app_titleid;
        m["registered"] = registered;
        m["display"] = !hidden;
        local_nicknames.append(host.host_name);
        out.append(row);
        if(!host.ps5 && registered)
            registered_discovered_ps4s++;
    }

    // 2. consoles ajoutées à la main (cachées si elles sont déjà trouvées sur le réseau)
    for(const auto &host : manual_hosts)
    {
        Row row;
        row.entry.valid = true;
        row.entry.manual_host = host;
        QVariantMap &m = row.view;
        m["key"] = QStringLiteral("manual:%1").arg(host.GetID());
        m["discovered"] = false;
        m["manual"] = true;
        m["name"] = host.GetHost();
        m["duid"] = "";
        m["address"] = host.GetHost();
        m["state"] = "unknown";
        m["registered"] = false;
        m["display"] = !discovered_manual_hosts.contains(host);
        if(host.GetRegistered() && settings->GetRegisteredHostRegistered(host.GetMAC()))
        {
            const auto registered = settings->GetRegisteredHost(host.GetMAC());
            row.entry.registered = true;
            row.entry.registered_host = registered;
            m["registered"] = true;
            m["name"] = registered.GetServerNickname();
            m["ps5"] = chiaki_target_is_ps5(registered.GetTarget());
            m["mac"] = registered.GetServerMAC().ToString();
        }
        out.append(row);
    }

    // 3. consoles du compte PSN, seulement si elles ne sont pas déjà sur le réseau local
    //    (ni en train de se réveiller : elles vont réapparaître sur le réseau)
    if(registered_discovered_ps4s >= settings->GetPS4RegisteredHostsRegistered())
        local_nicknames.append(MAIN_PS4_NAME);
    for(auto it = psn_hosts.cbegin(); it != psn_hosts.cend(); ++it)
    {
        const PsnHost &host = it.value();
        if(local_nicknames.contains(host.GetName()) || waking_nicknames.contains(host.GetName()))
            continue;
        Row row;
        row.entry.valid = true;
        row.entry.psn_host = host;
        row.entry.duid = it.key();
        row.entry.registered = true;
        row.entry.registered_host = settings->GetNicknameRegisteredHost(host.GetName());
        QVariantMap &m = row.view;
        m["key"] = PsnKey(it.key());
        m["discovered"] = false;
        m["manual"] = false;
        m["display"] = true;
        // « Main PS4 Console » pour Sony : on affiche le nom de la PS4 associée
        m["name"] = QString::fromStdString(MacnPlayRules::consoleDisplayName(host.GetName().toStdString(), registeredPs4Name().toStdString()));
        m["duid"] = host.GetDuid();
        m["address"] = "";
        m["registered"] = true;
        m["ps5"] = host.IsPS5();
        out.append(row);
    }

    // démonstration : MACNPLAY_DEMO_PS5=1 ajoute une fausse PS5 pour voir l'accueil avec deux consoles
    if(qEnvironmentVariableIsSet("MACNPLAY_DEMO_PS5"))
    {
        Row row;  // entrée invalide : on ne peut pas jouer sur une console de démonstration
        QVariantMap &m = row.view;
        m["key"] = QStringLiteral("demo");
        m["demo"] = true;
        m["discovered"] = true;
        m["manual"] = false;
        m["display"] = true;
        m["name"] = "PS5-Salon";
        m["duid"] = "";
        m["address"] = "192.168.1.72";
        m["ps5"] = true;
        m["mac"] = DEMO_CONSOLE_MAC;
        m["state"] = "standby";
        m["app"] = "";
        m["registered"] = true;
        out.append(row);
    }
    // ce que l'accueil a le droit de proposer pour chaque console
    for(Row &row : out)
    {
        const bool discovered = row.view.value("discovered").toBool();
        const bool registered = row.view.value("registered").toBool();
        const bool remote = !row.view.value("duid").toString().isEmpty();
        // associée : code PIN déjà saisi, ou connue par le compte PSN (association automatique)
        row.view["paired"] = registered || remote;
        // « Réveiller » : seulement pour une console associée, ajoutée à la main et pas encore vue sur le réseau
        row.view["canWake"] = registered && !remote && !discovered;
        row.view["remote"] = remote;
    }
    return out;
}

QVariantList ConsoleRegistry::list() const
{
    QVariantList out;
    for(const Row &row : rows())
        out.append(row.view);
    return out;
}

QVariantList ConsoleRegistry::hidden() const
{
    QVariantList out;
    for(const auto &host : settings->GetHiddenHosts())
    {
        QVariantMap m;
        m["name"] = host.GetNickname();
        m["mac"] = host.GetMAC().ToString();
        out.append(m);
    }
    return out;
}

ConsoleEntry ConsoleRegistry::consoleByKey(const QString &key) const
{
    for(const Row &row : rows())
    {
        if(row.view.value("key").toString() == key)
            return row.entry;
    }
    return {};
}

QString ConsoleRegistry::DiscoveredKey(const HostMAC &mac)
{
    return QStringLiteral("mac:") + mac.ToString();
}

QString ConsoleRegistry::PsnKey(const QString &duid)
{
    return QStringLiteral("psn:") + duid;
}

QString ConsoleRegistry::registeredPs4Name() const
{
    for(const auto &host : settings->GetRegisteredHosts())
    {
        if(!chiaki_target_is_ps5(host.GetTarget()))
            return host.GetServerNickname();
    }
    return QString();
}

QString ConsoleRegistry::psnConsoleKey(const QString &nickname) const
{
    for(auto it = psn_hosts.cbegin(); it != psn_hosts.cend(); ++it)
    {
        if(it.value().GetName() == nickname)
            return PsnKey(it.key());
    }
    return QString();
}

bool ConsoleRegistry::sendWakeup(const QString &address, const QByteArray &regist_key, bool ps5)
{
    try
    {
        qCInfo(logConsoles) << "Réveil de la console" << address;
        discovery_manager.SendWakeup(address, regist_key, ps5);
        return true;
    }
    catch(const Exception &e)
    {
        qCWarning(logConsoles) << "Réveil impossible de" << address << ":" << e.what();
        emit error(tr("Wakeup failed"), tr("Failed to send Wakeup packet:\n%1").arg(e.what()));
        return false;
    }
}

void ConsoleRegistry::markWaking(const QString &nickname)
{
    if(nickname.isEmpty())
        return;
    waking_nicknames.append(nickname);
    QTimer::singleShot(WAKEUP_PSN_IGNORE_SECONDS * 1000, this, [this, nickname] {
        waking_nicknames.removeOne(nickname);
        emit listChanged();
    });
}

void ConsoleRegistry::wakeUp(const QString &key, QString nickname)
{
    const ConsoleEntry entry = consoleByKey(key);
    if(!entry.valid || !entry.registered)
        return;
    markWaking(nickname);
    const QString address = entry.address();
    const QByteArray regist_key = entry.registered_host.GetRPRegistKey();
    const bool ps5 = entry.isPS5();
    QTimer::singleShot(0, this, [this, address, regist_key, ps5]() {
        sendWakeup(address, regist_key, ps5);
    });
}

void ConsoleRegistry::setConsolePin(const QString &key, QString console_pin)
{
    ConsoleEntry entry = consoleByKey(key);
    if(!entry.valid)
        return;
    entry.registered_host.SetConsolePin(entry.registered_host, std::move(console_pin));
    settings->AddRegisteredHost(entry.registered_host);
    qCInfo(logConsoles) << "Code de la console enregistré pour" << entry.registered_host.GetServerNickname();
}

void ConsoleRegistry::addManualHost(int index, const QString &address)
{
    HostMAC mac;
    const QList<RegisteredHost> registered_hosts = settings->GetRegisteredHosts();
    const bool registered = index >= 0 && index < registered_hosts.length();
    if(registered)
        mac = registered_hosts.at(index).GetServerMAC();
    settings->SetManualHost(ManualHost(-1, address, registered, mac));
    qCInfo(logConsoles) << "Console ajoutée à la main :" << address;
}

void ConsoleRegistry::deleteManualHost(const QString &key)
{
    const ConsoleEntry entry = consoleByKey(key);
    const int id = entry.manual_host.GetID();
    if(!entry.valid || id < 0)
        return;
    settings->RemoveManualHost(id);
    qCInfo(logConsoles) << "Console ajoutée à la main supprimée :" << entry.manual_host.GetHost();
}

// adresse MAC écrite en hexadécimal (12 caractères) → 6 octets
bool ConsoleRegistry::parseMac(const QString &mac_string, HostMAC *mac)
{
    const QByteArray bytes = QByteArray::fromHex(mac_string.toUtf8());
    if(bytes.size() != 6)
    {
        qCWarning(logConsoles) << "Adresse MAC invalide :" << mac_string << "(" << bytes.size() << "octets au lieu de 6)";
        return false;
    }
    *mac = HostMAC(reinterpret_cast<const uint8_t *>(bytes.constData()));
    return true;
}

void ConsoleRegistry::hide(const QString &mac_string, const QString &nickname)
{
    HostMAC mac;
    if(!parseMac(mac_string, &mac))
        return;
    settings->AddHiddenHost(HiddenHost(mac, nickname));
    qCInfo(logConsoles) << "Console masquée :" << nickname;
    emit listChanged();
}

void ConsoleRegistry::unhide(const QString &mac_string)
{
    HostMAC mac;
    if(!parseMac(mac_string, &mac))
        return;
    settings->RemoveHiddenHost(mac);
    qCInfo(logConsoles) << "Console réaffichée :" << mac_string;
    emit listChanged();
}

bool ConsoleRegistry::registerConsole(const QString &address, const QString &psn_id, const QString &pin, const QString &cpin, int target, const QJSValue &callback)
{
    // adresse de diffusion : on cherche la console sur tout le réseau local
    const bool broadcast = address == QLatin1String(BROADCAST_ADDRESS);
    ChiakiRegistInfo info = {};
    const QByteArray address_bytes = address.toUtf8();
    info.host = address_bytes.constData();
    info.target = static_cast<ChiakiTarget>(target);
    info.broadcast = broadcast;
    info.pin = static_cast<uint32_t>(pin.toULong());
    info.console_pin = static_cast<uint32_t>(cpin.toULong());
    info.holepunch_info = nullptr;
    info.rudp = nullptr;
    // les très vieux systèmes PS4 (avant 7.0) identifient le joueur par son pseudo,
    // les autres par l'identifiant de compte PSN (8 octets en base64)
    QByteArray psn_id_bytes;
    if(target == CHIAKI_TARGET_PS4_8)
    {
        psn_id_bytes = psn_id.toUtf8();
        info.psn_online_id = psn_id_bytes.constData();
    }
    else
    {
        const QByteArray account_id = QByteArray::fromBase64(psn_id.toUtf8());
        if(account_id.size() != CHIAKI_PSN_ACCOUNT_ID_SIZE)
        {
            qCWarning(logConsoles) << "Association refusée : identifiant de compte PSN invalide";
            emit error(tr("Invalid Account-ID"), tr("The PSN Account-ID must be exactly %1 bytes encoded as base64.").arg(CHIAKI_PSN_ACCOUNT_ID_SIZE));
            return false;
        }
        info.psn_online_id = nullptr;
        memcpy(info.psn_account_id, account_id.constData(), CHIAKI_PSN_ACCOUNT_ID_SIZE);
    }

    qCInfo(logConsoles) << "Association avec" << address << "(" << (broadcast ? "recherche sur le réseau" : "adresse directe") << ")";
    auto registration = new ConsoleRegistration(settings->GetLogLevelMask(), this);
    connect(registration, &ConsoleRegistration::log, this, [callback](ChiakiLogLevel level, const QString &msg) {
        QJSValue cb = callback;
        if(cb.isCallable())
            cb.call({QString("[%1] %2").arg(chiaki_log_level_char(level)).arg(msg), true, false});
    });
    connect(registration, &ConsoleRegistration::failed, this, [this, address, callback]() {
        qCWarning(logConsoles) << "Association échouée avec" << address;
        QJSValue cb = callback;
        if(cb.isCallable())
            cb.call({QString(), false, true});
        pending_registration = {};
    });
    connect(registration, &ConsoleRegistration::succeeded, this, [this, address, callback](const RegisteredHost &host) {
        qCInfo(logConsoles) << "Console associée :" << host.GetServerNickname();
        QJSValue cb = callback;
        if(cb.isCallable())
            cb.call({QString(), true, true});
        settings->AddRegisteredHost(host);
        // une console ajoutée à la main garde le lien avec son association
        if(!pending_registration.discovered)
        {
            ManualHost manual_host = pending_registration.manual_host;
            if(manual_host.GetHost().isEmpty())
                manual_host.SetHost(address);
            manual_host.Register(host);
            settings->SetManualHost(manual_host);
        }
    });
    // une fois terminée (réussie ou non), l'association est détruite dans ce fil-ci
    connect(registration, &ConsoleRegistration::succeeded, registration, &QObject::deleteLater);
    connect(registration, &ConsoleRegistration::failed, registration, &QObject::deleteLater);
    if(!registration->start(info))
    {
        qCWarning(logConsoles) << "Association impossible à démarrer avec" << address;
        delete registration;
        pending_registration = {};
        QJSValue cb = callback;
        if(cb.isCallable())
            cb.call({tr("[E] The pairing could not start. Check the console address and try again."), false, true});
        return false;
    }
    return true;
}

void ConsoleRegistry::refreshPsnConsoles()
{
    if(psn_consoles_watcher.isRunning())
    {
        qCInfo(logConsoles) << "Consoles du compte PSN : demande déjà en cours";
        return;
    }
    // la tâche de fond reçoit une copie de ce qu'il lui faut : elle ne touche ni aux
    // réglages ni aux listes affichées, qui ne sont remplacées qu'à la fin (onPsnConsolesFetched)
    PsnRequest request;
    request.token = settings->GetPsnAuthToken();
    request.log_mask = settings->GetLogLevelMask();
    for(const auto &host : settings->GetRegisteredHosts())
        request.registered_nicknames.insert(host.GetServerNickname());
    request.registered_ps4s = settings->GetPS4RegisteredHostsRegistered();
    if(request.token.isEmpty())
        return;
    psn_consoles_watcher.setFuture(QtConcurrent::run(&ConsoleRegistry::fetchPsnConsoles, request));
}

void ConsoleRegistry::onPsnConsolesFetched()
{
    const PsnConsoles fetched = psn_consoles_watcher.result();
    if(!fetched.valid)
        return;
    psn_hosts = fetched.usable;
    psn_nickname_hosts = fetched.by_nickname;
    qCInfo(logConsoles) << "Consoles du compte PSN à jour :" << psn_hosts.size() << "utilisable(s) à distance";
    emit listChanged();
}

void ConsoleRegistry::clearPsnConsoles()
{
    if(psn_hosts.isEmpty() && psn_nickname_hosts.isEmpty())
        return;
    psn_hosts.clear();
    psn_nickname_hosts.clear();
    qCInfo(logConsoles) << "Consoles du compte PSN oubliées (compte déconnecté ou changé)";
    emit listChanged();
}

// tourne en tâche de fond : la demande à Sony peut prendre plusieurs secondes
ConsoleRegistry::PsnConsoles ConsoleRegistry::fetchPsnConsoles(PsnRequest request)
{
    PsnConsoles out;
    ChiakiHolepunchDeviceInfo *ps5_devices = nullptr;
    size_t ps5_count = 0;
    ChiakiLog log;
    chiaki_log_init(&log, request.log_mask, ChiakiLogToJournal, const_cast<QLoggingCategory *>(&logConsoles()));
    for(int attempt = 1; attempt <= PSN_DEVICES_TRIES; attempt++)
    {
        const ChiakiErrorCode err = chiaki_holepunch_list_devices(request.token.toUtf8().constData(), CHIAKI_HOLEPUNCH_CONSOLE_TYPE_PS5, &ps5_devices, &ps5_count, &log);
        if(err == CHIAKI_ERR_SUCCESS)
            break;
        qCWarning(logConsoles) << "Consoles PS5 du compte : échec de la demande" << attempt << "/" << PSN_DEVICES_TRIES;
        ps5_count = 0;
    }
    for(size_t i = 0; i < ps5_count; i++)
    {
        const ChiakiHolepunchDeviceInfo &device = ps5_devices[i];
        // la lecture à distance doit être activée sur la console
        if(!device.remoteplay_enabled)
            continue;
        const QString duid = QByteArray(reinterpret_cast<const char *>(device.device_uid), sizeof(device.device_uid)).toHex();
        const QString name = QString(device.device_name);
        const PsnHost host(duid, name, true);
        out.by_nickname.insert(name, host);
        if(request.registered_nicknames.contains(name))
            out.usable.insert(duid, host);
    }

    // Sony ne liste pas les PS4 : la PS4 principale du compte a un identifiant fixe
    const QString ps4_duid = QByteArray(32, 'A').toHex();
    const PsnHost ps4_host(ps4_duid, MAIN_PS4_NAME, false);
    out.by_nickname.insert(MAIN_PS4_NAME, ps4_host);
    if(request.registered_ps4s > 0)
        out.usable.insert(ps4_duid, ps4_host);

    if(ps5_devices)
        chiaki_holepunch_free_device_list(&ps5_devices);
    out.valid = true;
    return out;
}

#include "consoleregistry.moc"
