#include "remotequalityguard.h"
#include "streamsession.h"
#include "macnplaylog.h"
#include "macnplayrules.h"

#include <QHostAddress>
#include <QNetworkInterface>

RemoteQualityGuard::RemoteQualityGuard(QObject *parent)
    : QObject(parent)
{
    timer.setInterval(1000);
    connect(&timer, &QTimer::timeout, this, &RemoteQualityGuard::checkLosses);
}

bool RemoteQualityGuard::onPhoneHotspot()
{
    for(const QHostAddress &address : QNetworkInterface::allAddresses())
    {
        if(address.protocol() == QAbstractSocket::IPv4Protocol && !address.isLoopback()
            && MacnPlayRules::isPhoneHotspotAddress(address.toIPv4Address()))
            return true;
    }
    return false;
}

int RemoteQualityGuard::startPreset(int chosen_preset)
{
    const bool phone = onPhoneHotspot();
    const int start = MacnPlayRules::remoteStartPreset(phone, chosen_preset);
    qCInfo(logSession) << "Partie par Internet" << (phone ? "(partage de connexion d'un téléphone)" : "")
                       << ": qualité" << presetName(start) << "(réglée :" << presetName(chosen_preset) << ")";
    return start;
}

QString RemoteQualityGuard::presetName(int value)
{
    switch(value)
    {
        case 1: return QStringLiteral("360p");
        case 2: return QStringLiteral("540p");
        case 3: return QStringLiteral("720p");
        case 4: return QStringLiteral("1080p");
        default: return QStringLiteral("?");
    }
}

void RemoteQualityGuard::watch(StreamSession *watched, int watched_preset)
{
    session = watched;
    preset = watched_preset;
    seconds_with_high_loss = 0;
    timer.start();
}

void RemoteQualityGuard::stop()
{
    timer.stop();
    session = nullptr;
}

void RemoteQualityGuard::checkLosses()
{
    if(!session)
    {
        stop();
        return;
    }
    const double loss = session->GetAveragePacketLoss();
    seconds_with_high_loss = (qIsFinite(loss) && loss > MacnPlayRules::HIGH_PACKET_LOSS) ? seconds_with_high_loss + 1 : 0;
    const int lower = MacnPlayRules::presetAfterLosses(preset, seconds_with_high_loss);
    if(lower == preset)
        return;
    qCWarning(logSession) << "Partie par Internet : pertes élevées depuis" << seconds_with_high_loss
                          << "s, qualité abaissée de" << presetName(preset) << "à" << presetName(lower);
    stop();
    emit lowerRequested(lower);
}
