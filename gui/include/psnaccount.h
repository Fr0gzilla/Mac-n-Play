// Contrôleur (MVC) du compte PlayStation Network.
//
// Rôle unique : connecter l'utilisateur à son compte PSN, garder ses jetons d'accès
// valides et fournir son profil (pseudo, avatar, PS Plus, trophées).
//   - Modèle : Settings (jetons PSN enregistrés) et les services web de Sony.
//   - Vue    : PSNLoginDialog.qml, PSNTokenDialog.qml et le panneau du compte sur
//     l'accueil, qui l'utilisent sous le nom « Chiaki.psn ».
// La liste des consoles du compte n'est pas gérée ici : quand les jetons sont prêts,
// le signal tokensReady() prévient qui doit la rafraîchir.
#pragma once

#include <QObject>
#include <QTimer>
#include <QJSValue>
#include <QUrl>
#include <QVariantMap>

class Settings;
class QNetworkAccessManager;
#ifdef CHIAKI_HAVE_WEBENGINE
class QQuickWebEngineProfile;
class SecUaRequestInterceptor;
#endif

class PsnAccount : public QObject
{
    Q_OBJECT
    // profil du compte : onlineId, avatar, plus, level, progress, platinum… (vide si non connecté)
    Q_PROPERTY(QVariantMap profile READ profile NOTIFY profileChanged)

public:
    PsnAccount(Settings *settings, QObject *parent = nullptr);
    ~PsnAccount();

    void setSettings(Settings *settings) { this->settings = settings; }
    QVariantMap profile() const { return current_profile; }

    // renouvelle les jetons avec le jeton de renouvellement enregistré
    void renewTokens();
    // Sony refuse les jetons : on les efface, puis credentialsExpired() demande une reconnexion
    void forgetCredentials();

    // adresse de la page de connexion de Sony (avec un identifiant d'appareil neuf)
    Q_INVOKABLE QUrl loginUrl() const;
    // ouvre la page de connexion dans le navigateur ; renvoie son adresse
    Q_INVOKABLE QString openLoginPage();
    // l'adresse est-elle la page où Sony renvoie après la connexion ?
    Q_INVOKABLE bool isRedirectUrl(const QUrl &url) const;
    // fin de connexion depuis la page intégrée : signaux loginSucceeded / loginFailed
    Q_INVOKABLE bool handleLoginRedirect(const QUrl &url);
    // fin de connexion depuis une adresse collée : le résultat passe par callback(message, réussi, fini)
    Q_INVOKABLE void loginWithRedirect(const QUrl &url, const QJSValue &callback);
    // vérifie les jetons (les renouvelle s'ils expirent) puis met le profil à jour
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void fetchProfile();
#ifdef CHIAKI_HAVE_WEBENGINE
    Q_INVOKABLE void setWebEngineHints(QQuickWebEngineProfile *profile);
    Q_INVOKABLE void clearCookies(QQuickWebEngineProfile *profile);
#endif

signals:
    void profileChanged();
    void loginSucceeded(const QString &account_id);
    void loginFailed(const QString &error);
    // les jetons ont été refusés par Sony et effacés : il faut se reconnecter
    void credentialsExpired();
    // les jetons sont valides : les données du compte peuvent être demandées
    void tokensReady();

private:
    void exchangeCode(const QString &code, const QJSValue &callback);
    // la carte du compte (profil et avatar) est enregistrée sur le Mac pour s'afficher hors ligne
    void loadCachedProfile();
    void storeProfile(QVariantMap profile);
    void downloadAvatar(const QString &url);
    void clearProfile();

    Settings *settings;
    QVariantMap current_profile;
    QTimer profile_timer;
    QNetworkAccessManager *network = nullptr;
#ifdef CHIAKI_HAVE_WEBENGINE
    SecUaRequestInterceptor *request_interceptor = nullptr;
#endif
};
