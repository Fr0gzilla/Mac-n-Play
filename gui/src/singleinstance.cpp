// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "singleinstance.h"
#include "macnplaylog.h"

#include <QLocalServer>
#include <QLocalSocket>

// délai d'attente de la réponse de l'autre copie
static const int CONNECT_TIMEOUT_MS = 500;

SingleInstance::SingleInstance(QString key, QObject *parent)
    : QObject(parent), key(std::move(key))
{
}

bool SingleInstance::claim()
{
    QLocalSocket socket;
    socket.connectToServer(key);
    if(socket.waitForConnected(CONNECT_TIMEOUT_MS))
    {
        qCWarning(logSession) << "Mac'n'Play est déjà ouvert : cette copie se ferme et l'autre revient au premier plan";
        socket.write("show");
        socket.waitForBytesWritten(CONNECT_TIMEOUT_MS);
        return false;
    }
    // une copie qui a planté peut avoir laissé son point de rendez-vous : on le nettoie
    QLocalServer::removeServer(key);
    server = new QLocalServer(this);
    server->setSocketOptions(QLocalServer::UserAccessOption);
    if(!server->listen(key))
    {
        qCWarning(logSession) << "Verrou « une seule copie » indisponible :" << server->errorString();
        return true;
    }
    connect(server, &QLocalServer::newConnection, this, [this] {
        while(QLocalSocket *other = server->nextPendingConnection())
        {
            other->deleteLater();
            qCInfo(logSession) << "Une autre copie de Mac'n'Play a voulu démarrer : retour au premier plan";
            emit activationRequested();
        }
    });
    return true;
}
