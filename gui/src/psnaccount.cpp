// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "psnaccount.h"
#include "settings.h"
#include "psnaccountid.h"
#include "psntoken.h"
#include "jsonrequester.h"
#include "macnplaylog.h"
#include "macnplayrules.h"

#include "chiaki/remote/holepunch.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSettings>
#include <QStandardPaths>
#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonObject>
#include <QUrlQuery>

#ifdef CHIAKI_HAVE_WEBENGINE
#include <QQuickWebEngineProfile>
#include <QWebEngineClientHints>
#include <QWebEngineCookieStore>
#include <QWebEngineUrlRequestInterceptor>

// la page de connexion de Sony n'accepte que les navigateurs connus :
// on se présente comme une version récente de Chrome (ou Edge sous Windows)
class SecUaRequestInterceptor : public QWebEngineUrlRequestInterceptor
{
public:
    SecUaRequestInterceptor(QString version, QObject *parent = nullptr)
        : QWebEngineUrlRequestInterceptor(parent), chrome_version(std::move(version)) {}

    void interceptRequest(QWebEngineUrlRequestInfo &info) override
    {
#ifdef Q_OS_WINDOWS
        info.setHttpHeader("Sec-Ch-Ua", QString("\"Not(A:Brand\";v=\"99\", \"Microsoft Edge\";v=\"%1\", \"Chromium\";v=\"%1\"").arg(chrome_version).toUtf8());
#else
        info.setHttpHeader("Sec-Ch-Ua", QString("\"Not(A:Brand\";v=\"99\", \"Google Chrome\";v=\"%1\", \"Chromium\";v=\"%1\"").arg(chrome_version).toUtf8());
#endif
    }

private:
    QString chrome_version;
};
#endif

// le profil (statut en ligne, trophées, jeu en cours) est relu régulièrement
static const int PROFILE_REFRESH_MS = 5 * 60 * 1000;

// la carte du compte est gardée sur le Mac : elle s'affiche dès le lancement, même hors ligne
static const char *CACHED_PROFILE_KEY = "macnplay/psnProfile";

// un fichier par adresse d'avatar : si l'utilisateur change d'avatar, le nom change aussi
static QString CachedAvatarPath(const QString &avatar_url)
{
    const QString id = QCryptographicHash::hash(avatar_url.toUtf8(), QCryptographicHash::Sha1).toHex().left(12);
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/psn-avatar-" + id + ".img";
}

static void RemoveCachedAvatars(const QString &keep = QString())
{
    QDir dir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));
    for(const QString &name : dir.entryList({ "psn-avatar-*.img" }, QDir::Files))
    {
        if(dir.absoluteFilePath(name) != keep)
            dir.remove(name);
    }
}

// adresse du profil PSN : pseudo, avatar, PS Plus, trophées et activité en cours
static const char *PROFILE_URL = "https://us-prof.np.community.playstation.net/userProfile/v1/users/me/profile2"
    "?fields=onlineId,avatarUrls,plus,trophySummary(@default,level,progress,earnedTrophies),presences(@titleInfo)&avatarSizes=xl";

PsnAccount::PsnAccount(Settings *settings, QObject *parent)
    : QObject(parent), settings(nullptr)
{
    setSettings(settings);
    loadCachedProfile();
    connect(this, &PsnAccount::tokensReady, this, &PsnAccount::fetchProfile);
    // refresh() renouvelle les jetons s'ils expirent, puis relit le profil
    connect(&profile_timer, &QTimer::timeout, this, &PsnAccount::refresh);
    profile_timer.start(PROFILE_REFRESH_MS);
}

PsnAccount::~PsnAccount()
{
#ifdef CHIAKI_HAVE_WEBENGINE
    if(request_interceptor)
        request_interceptor->deleteLater();
#endif
}

void PsnAccount::setSettings(Settings *new_settings)
{
    if(settings)
        disconnect(settings, nullptr, this, nullptr);
    settings = new_settings;
    connect(settings, &Settings::PsnTokensUpdated, this, &PsnAccount::connectedChanged);
    emit connectedChanged();
}

bool PsnAccount::connected() const
{
    return !settings->GetPsnRefreshToken().isEmpty() && !settings->GetPsnAuthToken().isEmpty()
        && !settings->GetPsnAuthTokenExpiry().isEmpty() && !settings->GetPsnAccountId().isEmpty();
}

QUrl PsnAccount::loginUrl() const
{
    size_t duid_size = CHIAKI_DUID_STR_SIZE;
    char duid[CHIAKI_DUID_STR_SIZE];
    chiaki_holepunch_generate_client_device_uid(duid, &duid_size);
    return QUrl(PSNAuth::LOGIN_URL + "duid=" + QString(duid) + "&");
}

QString PsnAccount::openLoginPage()
{
    // une seule adresse : chaque appel à loginUrl() crée un identifiant d'appareil différent
    const QUrl url = loginUrl();
    QDesktopServices::openUrl(url);
    return QString(url.toEncoded());
}

bool PsnAccount::isRedirectUrl(const QUrl &url) const
{
    return url.toString().startsWith(QString::fromStdString(PSNAuth::REDIRECT_PAGE));
}

bool PsnAccount::handleLoginRedirect(const QUrl &url)
{
    if(!isRedirectUrl(url))
    {
        qCWarning(logPsn) << "Connexion : adresse de retour inattendue" << url.host();
        emit loginFailed(tr("The return address is not the expected Sony page:\n%1").arg(QString::fromStdString(PSNAuth::REDIRECT_PAGE)));
        return false;
    }
    const QString code = QUrlQuery(url).queryItemValue("code");
    if(code.isEmpty())
    {
        qCWarning(logPsn) << "Connexion : l'adresse de retour ne contient pas de code";
        emit loginFailed(tr("The return address contains no sign-in code. Try signing in again."));
        return false;
    }
    exchangeCode(code, QJSValue());
    return true;
}

void PsnAccount::loginWithRedirect(const QUrl &url, const QJSValue &callback)
{
    if(!isRedirectUrl(url))
    {
        qCWarning(logPsn) << "Connexion : adresse collée invalide";
        if(callback.isCallable())
            callback.call({tr("[E] Invalid address: check that you copied and pasted the whole address."), false, true});
        return;
    }
    const QString code = QUrlQuery(url).queryItemValue("code");
    if(code.isEmpty())
    {
        qCWarning(logPsn) << "Connexion : l'adresse collée ne contient pas de code";
        if(callback.isCallable())
            callback.call({tr("[E] The pasted address contains no sign-in code."), false, true});
        return;
    }
    exchangeCode(code, callback);
}

// échange le code de connexion contre les jetons d'accès et l'identifiant du compte
void PsnAccount::exchangeCode(const QString &code, const QJSValue &callback)
{
    qCInfo(logPsn) << "Connexion : échange du code contre les jetons d'accès";
    auto *request = new PSNAccountID(settings, this);
    connect(request, &PSNAccountID::AccountIDResponse, this, [this, callback](const QString &account_id) {
        qCInfo(logPsn) << "Connexion réussie";
        emit loginSucceeded(account_id);
        if(callback.isCallable())
            callback.call({QString("[I] PSN Remote Connection Tokens Generated."), true, true});
        emit tokensReady();
    });
    connect(request, &PSNAccountID::AccountIDError, this, [this, callback](const QString &error) {
        qCWarning(logPsn) << "Connexion refusée :" << error;
        emit loginFailed(error);
        if(callback.isCallable())
            callback.call({error, false, true});
    });
    connect(request, &PSNAccountID::Finished, request, &QObject::deleteLater);
    request->GetPsnAccountId(code);
}

void PsnAccount::renewTokens(std::function<void()> on_success, ErrorCallback on_error)
{
    qCInfo(logPsn) << "Jetons : renouvellement";
    auto *request = new PSNToken(settings, this);
    connect(request, &PSNToken::PSNTokenError, this, [on_error](const QString &error) {
        qCWarning(logPsn) << "Jetons : renouvellement impossible, connexion à distance indisponible :" << error;
        if(on_error)
            on_error(error);
    });
    connect(request, &PSNToken::UnauthorizedError, this, [this, on_error]() {
        forgetCredentials();
        if(on_error)
            on_error(tr("Your PSN session has expired: sign in again."));
    });
    connect(request, &PSNToken::PSNTokenSuccess, this, [this, on_success]() {
        qCInfo(logPsn) << "Jetons : renouvelés";
        emit tokensReady();
        if(on_success)
            on_success();
    });
    connect(request, &PSNToken::Finished, request, &QObject::deleteLater);
    request->RefreshPsnToken(settings->GetPsnRefreshToken());
}

bool PsnAccount::whenTokensValid(std::function<void()> on_ready, ErrorCallback on_error)
{
    const QString expiry_text = settings->GetPsnAuthTokenExpiry();
    if(expiry_text.isEmpty() || settings->GetPsnRefreshToken().isEmpty())
        return false;
    const QDateTime expiry = QDateTime::fromString(expiry_text, settings->GetTimeFormat());
    if(MacnPlayRules::tokenNeedsRenewal(QDateTime::currentSecsSinceEpoch(), expiry.toSecsSinceEpoch()))
        renewTokens(std::move(on_ready), std::move(on_error));
    else
        on_ready();
    return true;
}

void PsnAccount::eraseTokens()
{
    settings->SetPsnRefreshToken(QString());
    settings->SetPsnAuthToken(QString());
    settings->SetPsnAuthTokenExpiry(QString());
    settings->SetPsnAccountId(QString());
    clearProfile();
    emit connectedChanged();
    emit accountForgotten();
}

void PsnAccount::forgetCredentials()
{
    qCWarning(logPsn) << "Jetons : refusés par Sony, ils sont effacés et il faut se reconnecter";
    eraseTokens();
    emit credentialsExpired();
}

void PsnAccount::logout()
{
    qCInfo(logPsn) << "Déconnexion du compte PSN demandée";
    eraseTokens();
}

void PsnAccount::refresh()
{
    // jetons encore valides : on prévient tout de suite ; sinon renewTokens() le fera
    const QString expiry_text = settings->GetPsnAuthTokenExpiry();
    if(expiry_text.isEmpty() || settings->GetPsnRefreshToken().isEmpty())
        return;
    const QDateTime expiry = QDateTime::fromString(expiry_text, settings->GetTimeFormat());
    if(MacnPlayRules::tokenNeedsRenewal(QDateTime::currentSecsSinceEpoch(), expiry.toSecsSinceEpoch()))
        renewTokens();
    else
        emit tokensReady();
}

void PsnAccount::fetchProfile()
{
    const QString token = settings->GetPsnAuthToken();
    if(token.isEmpty())
    {
        // plus de compte connecté : la carte enregistrée n'a plus lieu d'être
        clearProfile();
        return;
    }
    auto *requester = new JsonRequester(this);
    connect(requester, &JsonRequester::requestFinished, this, [this, requester](const QString &, const QJsonDocument &doc) {
        requester->deleteLater();
        const QJsonObject profile = doc.object().value("profile").toObject();
        if(profile.isEmpty())
        {
            qCWarning(logPsn) << "Profil : réponse vide";
            return;
        }
        const QJsonObject trophies = profile.value("trophySummary").toObject();
        const QJsonObject earned = trophies.value("earnedTrophies").toObject();
        const QJsonArray avatars = profile.value("avatarUrls").toArray();
        QString avatar = avatars.isEmpty() ? QString() : avatars.first().toObject().value("avatarUrl").toString();
        if(avatar.startsWith("http://"))
            avatar.replace(0, 7, "https://");
        const QJsonArray presences = profile.value("presences").toArray();
        const QJsonObject presence = presences.isEmpty() ? QJsonObject() : presences.first().toObject();
        QVariantMap m;
        m["onlineId"] = profile.value("onlineId").toString();
        m["avatar"] = avatar;
        m["plus"] = profile.value("plus").toInt() == 1;
        m["level"] = trophies.value("level").toInt();
        m["progress"] = trophies.value("progress").toInt();
        m["platinum"] = earned.value("platinum").toInt();
        m["gold"] = earned.value("gold").toInt();
        m["silver"] = earned.value("silver").toInt();
        m["bronze"] = earned.value("bronze").toInt();
        m["online"] = presence.value("onlineStatus").toString() == "online";
        m["game"] = presence.value("titleName").toString();
        qCInfo(logPsn) << "Profil reçu pour" << m["onlineId"].toString();
        storeProfile(m);
    });
    connect(requester, &JsonRequester::requestError, this, [requester](const QString &, const QString &error, const QNetworkReply::NetworkError &) {
        // on garde la carte enregistrée : elle reste affichée avec ses dernières valeurs
        qCWarning(logPsn) << "Profil : demande échouée, la carte enregistrée reste affichée :" << error;
        requester->deleteLater();
    });
    requester->makeGetRequest(PROFILE_URL, JsonRequester::generateBearerAuthHeader(token));
}

#ifdef CHIAKI_HAVE_WEBENGINE
void PsnAccount::clearCookies(QQuickWebEngineProfile *profile)
{
    profile->cookieStore()->deleteAllCookies();
}

// la page de Sony vérifie la version du navigateur : on annonce une version de Chrome
// plausible pour aujourd'hui (une nouvelle sort environ toutes les 4 semaines depuis la 133)
void PsnAccount::setWebEngineHints(QQuickWebEngineProfile *profile)
{
    const QDate chrome_133_release(2025, 02, 18);
    const qint64 release = 133 + chrome_133_release.daysTo(QDate::currentDate()) / 28;
    const QString chrome_version = QString::number(release);
    QString user_agent = profile->httpUserAgent();
    user_agent.replace(QRegularExpression(" \\bQtWebEngine[^ ]*\\b"), "");
    user_agent.replace(QRegularExpression("\\bChrome[^ ]*\\b"), QString("Chrome/%1.0.0.0").arg(chrome_version));
#ifdef Q_OS_WINDOWS
    user_agent.replace("Windows NT 6.2", "Windows NT 10.0");
    user_agent += QString(" Edg/%1.0.0.0").arg(chrome_version);
#endif
    profile->setHttpUserAgent(user_agent);
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    auto hints = profile->clientHints();
    hints->setFullVersion(QString("%1.0.0.0").arg(chrome_version));
    QMap<QString, QVariant> full_version_list;
    full_version_list.insert("Not A(Brand", "99.0.0.0");
#ifdef Q_OS_WINDOWS
    full_version_list.insert("Microsoft Edge", QString("%1.0.0.0").arg(chrome_version));
#else
    full_version_list.insert("Google Chrome", QString("%1.0.0.0").arg(chrome_version));
#endif
    full_version_list.insert("Chromium", QString("%1.0.0.0").arg(chrome_version));
    hints->setFullVersionList(full_version_list);
#endif
    request_interceptor = new SecUaRequestInterceptor(chrome_version);
    profile->setUrlRequestInterceptor(request_interceptor);
}
#endif

void PsnAccount::loadCachedProfile()
{
    QVariantMap cached = QSettings().value(CACHED_PROFILE_KEY).toMap();
    if(cached.isEmpty())
        return;
    // statut d'avant : on ne sait pas encore s'il est en ligne
    cached["online"] = false;
    cached["game"] = QString();
    const QString avatar_file = CachedAvatarPath(cached.value("avatarUrl").toString());
    if(QFile::exists(avatar_file))
        cached["avatar"] = QUrl::fromLocalFile(avatar_file).toString();
    current_profile = cached;
    qCInfo(logPsn) << "Carte du compte enregistrée chargée pour" << cached["onlineId"].toString();
    emit profileChanged();
}

void PsnAccount::storeProfile(QVariantMap profile)
{
    const QString remote_avatar = profile["avatar"].toString();
    profile["avatarUrl"] = remote_avatar;
    // avatar déjà enregistré : on l'affiche depuis le Mac, sinon on le télécharge
    const QString avatar_file = CachedAvatarPath(remote_avatar);
    const bool have_avatar = !remote_avatar.isEmpty() && QFile::exists(avatar_file);
    if(have_avatar)
        profile["avatar"] = QUrl::fromLocalFile(avatar_file).toString();
    current_profile = profile;
    QSettings().setValue(CACHED_PROFILE_KEY, profile);
    emit profileChanged();
    if(!remote_avatar.isEmpty() && !have_avatar)
        downloadAvatar(remote_avatar);
}

void PsnAccount::downloadAvatar(const QString &url)
{
    if(!network)
        network = new QNetworkAccessManager(this);
    QNetworkReply *reply = network->get(QNetworkRequest(QUrl(url)));
    connect(reply, &QNetworkReply::finished, this, [this, reply, url] {
        reply->deleteLater();
        if(reply->error() != QNetworkReply::NoError)
        {
            qCWarning(logPsn) << "Avatar : téléchargement impossible :" << reply->errorString();
            return;
        }
        const QString avatar_file = CachedAvatarPath(url);
        QDir().mkpath(QFileInfo(avatar_file).absolutePath());
        QFile file(avatar_file);
        if(!file.open(QIODevice::WriteOnly) || file.write(reply->readAll()) <= 0)
            return;
        file.close();
        RemoveCachedAvatars(avatar_file);
        qCInfo(logPsn) << "Avatar enregistré sur le Mac";
        if(current_profile.value("avatarUrl").toString() != url)
            return;
        current_profile["avatar"] = QUrl::fromLocalFile(avatar_file).toString();
        QSettings().setValue(CACHED_PROFILE_KEY, current_profile);
        emit profileChanged();
    });
}

void PsnAccount::clearProfile()
{
    QSettings().remove(CACHED_PROFILE_KEY);
    RemoveCachedAvatars();
    if(current_profile.isEmpty())
        return;
    current_profile.clear();
    qCInfo(logPsn) << "Carte du compte effacée (compte déconnecté)";
    emit profileChanged();
}
