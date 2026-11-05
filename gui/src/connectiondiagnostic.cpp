// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "connectiondiagnostic.h"
#include "consoleregistry.h"
#include "psnaccount.h"
#include "settings.h"
#include "macnplaylog.h"
#include "macnplayrules.h"

#include <QHostAddress>
#include <QNetworkAccessManager>
#include <QNetworkInterface>
#include <QNetworkReply>
#include <QTcpSocket>
#include <QTimer>

// serveur PlayStation déjà utilisé par l'appli (consoles du compte) : s'il répond, même par
// un refus, Internet et les serveurs de Sony sont joignables
static const char *SONY_CHECK_URL = "https://web.np.playstation.com/";
static const char *SONY_CHECK_HOST = "web.np.playstation.com";
// au-delà, la connexion est lente pour jouer à distance (millisecondes d'aller-retour)
static const qint64 SLOW_RESPONSE_MS = 150;
// nombre de mesures du temps d'aller-retour ; on garde la meilleure
static const int LATENCY_SAMPLES = 3;

ConnectionDiagnostic::ConnectionDiagnostic(Settings *settings, ConsoleRegistry *consoles, PsnAccount *psn, QObject *parent)
    : QObject(parent), settings(settings), consoles(consoles), psn(psn), network(new QNetworkAccessManager(this))
{
}

void ConnectionDiagnostic::add(const QString &title, const QString &status, const QString &detail)
{
    QVariantMap line;
    line["title"] = title;
    line["status"] = status;
    line["detail"] = detail;
    check_results.append(line);
    qCInfo(logSession).noquote() << "Diagnostic :" << title << "→" << status << ":" << detail;
    emit changed();
}

void ConnectionDiagnostic::start()
{
    if(is_running)
        return;
    is_running = true;
    check_results.clear();
    qCInfo(logSession) << "Diagnostic de connexion lancé";
    emit changed();
    checkLocalNetwork();
    checkPsnAccount();
    checkConsole();
    // Internet en dernier : c'est la seule vérification qui attend une réponse
    checkInternet();
}

void ConnectionDiagnostic::checkLocalNetwork()
{
    // on ne regarde que le Wi-Fi et le câble : les réseaux virtuels (VPN…) ne disent rien de la console
    QString address;
    bool phone = false;
    for(const QNetworkInterface &interface : QNetworkInterface::allInterfaces())
    {
        const bool physical = interface.type() == QNetworkInterface::Wifi || interface.type() == QNetworkInterface::Ethernet;
        if(!physical || !(interface.flags() & QNetworkInterface::IsRunning))
            continue;
        for(const QNetworkAddressEntry &entry : interface.addressEntries())
        {
            const QHostAddress candidate = entry.ip();
            if(candidate.protocol() != QAbstractSocket::IPv4Protocol || candidate.isLoopback() || candidate.isLinkLocal())
                continue;
            address = candidate.toString();
            phone = MacnPlayRules::isPhoneHotspotAddress(candidate.toIPv4Address());
            break;
        }
        if(!address.isEmpty())
            break;
    }
    if(address.isEmpty())
        add(tr("Mac network"), "error", tr("The Mac is not connected to any network. Connect it to Wi-Fi."));
    else if(phone)
        add(tr("Mac network"), "warning", tr("The Mac uses a phone's connection sharing (%1): you can only play over the Internet, in lower quality. For the best image, connect it to the same Wi-Fi as the console.").arg(address));
    else
        add(tr("Mac network"), "ok", tr("Connected (%1).").arg(address));
}

void ConnectionDiagnostic::checkPsnAccount()
{
    if(!psn->connected())
        add(tr("PSN account"), "warning", tr("Not signed in. Only needed to play away from home: Settings › Remote › Sign in."));
    else
        add(tr("PSN account"), "ok", tr("Signed in."));
}

void ConnectionDiagnostic::checkConsole()
{
    const auto registered = settings->GetRegisteredHosts();
    if(registered.isEmpty())
    {
        add(tr("Console"), "error", tr("No console is paired yet. Use the + button on the home screen."));
        return;
    }
    for(const auto &host : consoles->discoveredHosts())
    {
        if(!settings->GetRegisteredHostRegistered(host.GetHostMAC()))
            continue;
        const bool standby = host.state == CHIAKI_DISCOVERY_HOST_STATE_STANDBY;
        add(tr("Console"), "ok", standby
            ? tr("%1 found on this network, in rest mode (it will be woken up when you play).").arg(host.host_name)
            : tr("%1 found on this network, ready to play.").arg(host.host_name));
        return;
    }
    add(tr("Console"), "warning", tr("%1 is not found on this network. Either it is fully switched off, or the Mac is on another network: the game will then go through the Internet (PSN account needed).").arg(registered.first().GetServerNickname()));
}

void ConnectionDiagnostic::checkInternet()
{
    // une demande chiffrée vérifie que Sony répond sans interception, puis quelques
    // ouvertures de connexion mesurent l'aller-retour : le temps de réponse du serveur web
    // de Sony (plusieurs centaines de ms) ne dit rien de la latence en jeu
    QNetworkRequest request{QUrl(QString::fromLatin1(SONY_CHECK_URL))};
    request.setTransferTimeout(8000);
    QNetworkReply *reply = network->head(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if(reply->error() == QNetworkReply::SslHandshakeFailedError)
        {
            // le réseau (école, entreprise) remplace le certificat de Sony par celui de son pare-feu
            add(tr("Internet"), "error", tr("This network intercepts secure connections (school or company network?): PlayStation servers refuse it, so playing over the Internet won't work here. Use another network, for example your phone's connection."));
            finish();
            return;
        }
        if(reply->error() != QNetworkReply::NoError && reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() == 0)
        {
            add(tr("Internet"), "error", tr("PlayStation servers can't be reached (%1). Check the Internet connection.").arg(reply->errorString()));
            finish();
            return;
        }
        best_latency = -1;
        measureLatency(LATENCY_SAMPLES);
    });
}

void ConnectionDiagnostic::measureLatency(int remaining)
{
    if(remaining == 0)
    {
        if(best_latency < 0)
            add(tr("Internet"), "ok", tr("PlayStation servers reachable."));
        else if(best_latency > SLOW_RESPONSE_MS)
            add(tr("Internet"), "warning", tr("Reachable but slow (%1 ms to answer): playing over the Internet may stutter.").arg(best_latency));
        else
            add(tr("Internet"), "ok", tr("PlayStation servers reachable (%1 ms).").arg(best_latency));
        finish();
        return;
    }
    // le nom est déjà connu du système (demande précédente) : l'ouverture d'une connexion
    // dure un aller-retour
    QTcpSocket *socket = new QTcpSocket(this);
    internet_timer.start();
    connect(socket, &QTcpSocket::connected, this, [this, socket, remaining] {
        const qint64 elapsed = internet_timer.elapsed();
        if(best_latency < 0 || elapsed < best_latency)
            best_latency = elapsed;
        socket->disconnect(this);
        socket->abort();
        socket->deleteLater();
        measureLatency(remaining - 1);
    });
    connect(socket, &QTcpSocket::errorOccurred, this, [this, socket] {
        socket->disconnect(this);
        socket->deleteLater();
        measureLatency(0);
    });
    // pas de réponse en 3 s : on s'arrête avec ce qui a été mesuré
    QTimer::singleShot(3000, socket, [this, socket] {
        socket->disconnect(this);
        socket->abort();
        socket->deleteLater();
        measureLatency(0);
    });
    socket->connectToHost(QString::fromLatin1(SONY_CHECK_HOST), 443);
}

void ConnectionDiagnostic::finish()
{
    is_running = false;
    emit changed();
}
