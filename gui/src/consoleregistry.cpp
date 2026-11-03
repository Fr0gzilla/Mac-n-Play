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
// nom que Sony donne à la PS4 principale du compte (une seule PS4 peut jouer à distance)
static const QString MAIN_PS4_NAME = QStringLiteral("Main PS4 Console");

// association avec une console : fait le lien entre la bibliothèque Chiaki (fil séparé) et Qt
class ConsoleRegistration : public QObject
{
    Q_OBJECT

public:
    ConsoleRegistration(const ChiakiRegistInfo &info, uint32_t log_mask, QObject *parent)
        : QObject(parent)
    {
        chiaki_log_init(&chiaki_log, log_mask, &ConsoleRegistration::onLog, this);
        chiaki_regist_start(&chiaki_regist, &chiaki_log, &info, &ConsoleRegistration::onEvent, this);
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

    static void onEvent(ChiakiRegistEvent *event, void *user)
    {
        auto self = static_cast<ConsoleRegistration *>(user);
        switch(event->type)
        {
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS:
                QMetaObject::invokeMethod(self, std::bind(&ConsoleRegistration::succeeded, self, *event->registered_host), Qt::QueuedConnection);
                QMetaObject::invokeMethod(self, &QObject::deleteLater, Qt::QueuedConnection);
                break;
            case CHIAKI_REGIST_EVENT_TYPE_FINISHED_FAILED:
                QMetaObject::invokeMethod(self, &ConsoleRegistration::failed, Qt::QueuedConnection);
                QMetaObject::invokeMethod(self, &QObject::deleteLater, Qt::QueuedConnection);
                break;
            default:
                break;
        }
    }

    ChiakiLog chiaki_log;
    ChiakiRegist chiaki_regist;
};

ConsoleRegistry::ConsoleRegistry(Settings *settings, QObject *parent)
    : QObject(parent)
{
    connect(&psn_consoles_watcher, &QFutureWatcher<void>::finished, this, [this] { fetching_psn_consoles = false; });
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

QVariantList ConsoleRegistry::list() const
{
    QVariantList out;
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
        bool manual = false;
        for(const auto &manual_host : manual_hosts)
        {
            if(manual_host.GetRegistered() && manual_host.GetMAC() == host_mac && manual_host.GetHost() == host.host_addr)
            {
                manual = true;
                discovered_manual_hosts.append(manual_host);
            }
        }
        QString duid;
        if(!registered)
        {
            if(psn_nickname_hosts.contains(host.host_name))
                duid = psn_nickname_hosts.value(host.host_name).GetDuid();
            else if(!host.ps5)
                duid = psn_nickname_hosts.value(MAIN_PS4_NAME).GetDuid();
        }
        QVariantMap m;
        m["discovered"] = true;
        m["manual"] = manual;
        m["name"] = host.host_name;
        m["duid"] = duid;
        m["address"] = host.host_addr;
        m["ps5"] = host.ps5;
        m["mac"] = host_mac.ToString();
        m["state"] = chiaki_discovery_host_state_string(host.state);
        m["app"] = host.running_app_name;
        m["titleId"] = host.running_app_titleid;
        m["registered"] = registered;
        m["display"] = !hidden;
        local_nicknames.append(host.host_name);
        out.append(m);
        if(!host.ps5 && registered)
            registered_discovered_ps4s++;
    }

    // 2. consoles ajoutées à la main (cachées si elles sont déjà trouvées sur le réseau)
    for(const auto &host : manual_hosts)
    {
        QVariantMap m;
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
            m["registered"] = true;
            m["name"] = registered.GetServerNickname();
            m["ps5"] = chiaki_target_is_ps5(registered.GetTarget());
            m["mac"] = registered.GetServerMAC().ToString();
        }
        out.append(m);
    }

    // 3. consoles du compte PSN, seulement si elles ne sont pas déjà sur le réseau local
    if(registered_discovered_ps4s >= settings->GetPS4RegisteredHostsRegistered())
        local_nicknames.append(MAIN_PS4_NAME);
    for(const auto &host : psn_hosts)
    {
        if(local_nicknames.contains(host.GetName()) || waking_nicknames.contains(host.GetName()))
            continue;
        QVariantMap m;
        m["discovered"] = false;
        m["manual"] = false;
        m["display"] = true;
        m["name"] = host.GetName();
        m["duid"] = host.GetDuid();
        m["address"] = "";
        m["registered"] = true;
        m["ps5"] = host.IsPS5();
        out.append(m);
    }

    // démonstration : MACNPLAY_DEMO_PS5=1 ajoute une fausse PS5 pour voir l'accueil avec deux consoles
    if(qEnvironmentVariableIsSet("MACNPLAY_DEMO_PS5"))
    {
        QVariantMap m;
        m["demo"] = true;
        m["discovered"] = true;
        m["manual"] = false;
        m["display"] = true;
        m["name"] = "PS5-Salon";
        m["duid"] = "";
        m["address"] = "192.168.1.72";
        m["ps5"] = true;
        m["mac"] = "000000000000";
        m["state"] = "standby";
        m["app"] = "";
        m["registered"] = true;
        out.append(m);
    }
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

// même ordre que list() : réseau local, puis ajoutées à la main, puis compte PSN
ConsoleEntry ConsoleRegistry::consoleAt(int index) const
{
    if(index < 0)
        return {};
    const auto discovered = discovery_manager.GetHosts();
    const auto manual = settings->GetManualHosts();
    if(index < discovered.size())
    {
        ConsoleEntry entry;
        entry.valid = true;
        entry.discovered = true;
        entry.discovery_host = discovered.at(index);
        const HostMAC host_mac = entry.discovery_host.GetHostMAC();
        entry.registered = settings->GetRegisteredHostRegistered(host_mac);
        if(entry.registered)
            entry.registered_host = settings->GetRegisteredHost(host_mac);
        else if(psn_nickname_hosts.contains(entry.discovery_host.host_name))
            entry.duid = psn_nickname_hosts.value(entry.discovery_host.host_name).GetDuid();
        else if(!entry.discovery_host.ps5)
            entry.duid = psn_nickname_hosts.value(MAIN_PS4_NAME).GetDuid();
        for(const auto &manual_host : manual)
        {
            if(manual_host.GetRegistered() && manual_host.GetMAC() == host_mac && manual_host.GetHost() == entry.discovery_host.host_addr)
            {
                entry.manual_host = manual_host;
                break;
            }
        }
        return entry;
    }
    index -= discovered.size();
    if(index < manual.size())
    {
        ConsoleEntry entry;
        entry.valid = true;
        entry.manual_host = manual.at(index);
        if(entry.manual_host.GetRegistered() && settings->GetRegisteredHostRegistered(entry.manual_host.GetMAC()))
        {
            entry.registered = true;
            entry.registered_host = settings->GetRegisteredHost(entry.manual_host.GetMAC());
        }
        return entry;
    }
    index -= manual.size();
    int psn_index = 0;
    for(auto it = psn_hosts.cbegin(); it != psn_hosts.cend(); ++it)
    {
        bool on_local_network = false;
        for(const auto &host : discovered)
            on_local_network = on_local_network || host.host_name == it.value().GetName();
        if(on_local_network)
            continue;
        if(psn_index == index)
        {
            ConsoleEntry entry;
            entry.valid = true;
            entry.psn_host = it.value();
            entry.duid = it.key();
            entry.registered = true;
            entry.registered_host = settings->GetNicknameRegisteredHost(entry.psn_host.GetName());
            return entry;
        }
        psn_index++;
    }
    return {};
}

int ConsoleRegistry::psnConsoleIndex(const QString &nickname) const
{
    int i = 0;
    for(const auto &host : psn_hosts)
    {
        if(host.GetName() == nickname)
            return discovery_manager.GetHosts().size() + settings->GetManualHosts().size() + i;
        i++;
    }
    return -1;
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

void ConsoleRegistry::wakeUp(int index, QString nickname)
{
    const ConsoleEntry entry = consoleAt(index);
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

void ConsoleRegistry::setConsolePin(int index, QString console_pin)
{
    ConsoleEntry entry = consoleAt(index);
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

void ConsoleRegistry::deleteManualHost(int index)
{
    const ConsoleEntry entry = consoleAt(index);
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

bool ConsoleRegistry::registerConsole(const QString &address, const QString &psn_id, const QString &pin, const QString &cpin, bool broadcast, int target, const QJSValue &callback)
{
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
    auto registration = new ConsoleRegistration(info, settings->GetLogLevelMask(), this);
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
    return true;
}

void ConsoleRegistry::refreshPsnConsoles()
{
    if(fetching_psn_consoles)
    {
        qCInfo(logConsoles) << "Consoles du compte PSN : demande déjà en cours";
        return;
    }
    fetching_psn_consoles = true;
    psn_consoles_watcher.setFuture(QtConcurrent::run(&ConsoleRegistry::fetchPsnConsoles, this));
}

// tourne en tâche de fond : la demande à Sony peut prendre plusieurs secondes
void ConsoleRegistry::fetchPsnConsoles()
{
    const QString psn_token = settings->GetPsnAuthToken();
    if(psn_token.isEmpty())
        return;

    ChiakiHolepunchDeviceInfo *ps5_devices = nullptr;
    size_t ps5_count = 0;
    ChiakiLog log;
    chiaki_log_init(&log, settings->GetLogLevelMask(), ChiakiLogToJournal, const_cast<QLoggingCategory *>(&logConsoles()));
    for(int attempt = 1; attempt <= PSN_DEVICES_TRIES; attempt++)
    {
        const ChiakiErrorCode err = chiaki_holepunch_list_devices(psn_token.toUtf8().constData(), CHIAKI_HOLEPUNCH_CONSOLE_TYPE_PS5, &ps5_devices, &ps5_count, &log);
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
        if(!psn_nickname_hosts.contains(name))
            psn_nickname_hosts.insert(name, host);
        if(!psn_hosts.contains(duid) && settings->GetNicknameRegisteredHostRegistered(name))
            psn_hosts.insert(duid, host);
    }

    // Sony ne liste pas les PS4 : la PS4 principale du compte a un identifiant fixe
    const QString ps4_duid = QByteArray(32, 'A').toHex();
    const PsnHost ps4_host(ps4_duid, MAIN_PS4_NAME, false);
    if(!psn_nickname_hosts.contains(MAIN_PS4_NAME))
        psn_nickname_hosts.insert(MAIN_PS4_NAME, ps4_host);
    if(!psn_hosts.contains(ps4_duid) && settings->GetPS4RegisteredHostsRegistered() > 0)
        psn_hosts.insert(ps4_duid, ps4_host);

    qCInfo(logConsoles) << "Consoles du compte PSN à jour :" << psn_hosts.size() << "utilisable(s) à distance";
    if(ps5_devices)
        chiaki_holepunch_free_device_list(&ps5_devices);
    emit listChanged();
}

#include "consoleregistry.moc"
