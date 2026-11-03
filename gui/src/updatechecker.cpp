#include "updatechecker.h"
#include "macnplaylog.h"
#include "macnplayrules.h"

#include <QCoreApplication>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>

// ce lien renvoie vers la page de la dernière version publiée (…/releases/tag/v1.2.3).
// On lit l'adresse d'arrivée plutôt que l'API de GitHub, limitée à 60 demandes par heure
// et par adresse : sur un partage de connexion, l'adresse est commune à beaucoup d'abonnés.
static const char *LATEST_RELEASE_URL = "https://github.com/Fr0gzilla/Mac-n-Play/releases/latest";
// première vérification peu après le lancement, pour ne pas ralentir le démarrage
static const int FIRST_CHECK_DELAY_MS = 8000;
static const int CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;

UpdateChecker::UpdateChecker(QObject *parent)
    : QObject(parent), network(new QNetworkAccessManager(this))
{
    connect(&daily_timer, &QTimer::timeout, this, &UpdateChecker::checkNow);
    daily_timer.start(CHECK_INTERVAL_MS);
    QTimer::singleShot(FIRST_CHECK_DELAY_MS, this, &UpdateChecker::checkNow);
}

void UpdateChecker::checkNow()
{
    QNetworkRequest request{QUrl(QString::fromLatin1(LATEST_RELEASE_URL))};
    request.setRawHeader("User-Agent", QString("MacnPlay/%1").arg(QCoreApplication::applicationVersion()).toUtf8());
    // on veut seulement l'adresse de redirection, pas la page
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    QNetworkReply *reply = network->head(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        const QUrl target = reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
        // …/releases/tag/v1.2.3 → « v1.2.3 »
        const QString path = target.path();
        const QString tag = path.contains("/releases/tag/") ? path.section('/', -1) : QString();
        if(tag.isEmpty())
        {
            // pas de réseau, ou GitHub injoignable : on réessaiera demain, sans déranger l'utilisateur
            qCInfo(logSession) << "Nouvelle version : vérification impossible pour l'instant :" << reply->errorString();
            return;
        }
        const QString installed = QCoreApplication::applicationVersion();
        const bool newer = MacnPlayRules::versionIsNewer(tag.toStdString(), installed.toStdString());
        qCInfo(logSession) << "Nouvelle version : publiée" << tag << ", installée" << installed << (newer ? "→ mise à jour disponible" : "→ à jour");
        const QString version = tag.startsWith('v') ? tag.mid(1) : tag;
        if(newer == is_available && version == latest_version)
            return;
        is_available = newer;
        latest_version = version;
        page_url = target.isRelative() ? QUrl("https://github.com").resolved(target).toString() : target.toString();
        emit changed();
    });
}

void UpdateChecker::dismiss()
{
    dismissed = true;
    emit changed();
}
