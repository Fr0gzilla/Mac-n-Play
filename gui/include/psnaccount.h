// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
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

#include <functional>

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
    // un compte PSN complet est enregistré (jetons et identifiant) : les écrans n'ont
    // pas à lire les jetons eux-mêmes
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    PsnAccount(Settings *settings, QObject *parent = nullptr);
    ~PsnAccount();

    void setSettings(Settings *settings);
    QVariantMap profile() const { return current_profile; }
    bool connected() const;

    using ErrorCallback = std::function<void(const QString &error)>;

    // renouvelle les jetons avec le jeton de renouvellement enregistré ; on_success / on_error
    // sont appelés à la fin (en plus du signal tokensReady)
    void renewTokens(std::function<void()> on_success = {}, ErrorCallback on_error = {});
    // lance on_ready dès que les jetons sont valides (tout de suite, ou après les avoir renouvelés) ;
    // false si aucun compte n'est connecté (on_error n'est alors pas appelé)
    bool whenTokensValid(std::function<void()> on_ready, ErrorCallback on_error = {});
    // Sony refuse les jetons : on les efface, puis credentialsExpired() demande une reconnexion
    void forgetCredentials();
    // l'utilisateur se déconnecte : jetons, carte du compte et avatar enregistré sont effacés
    Q_INVOKABLE void logout();

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
    void connectedChanged();
    // le compte n'est plus utilisable (déconnexion, jetons refusés) : oublier ce qui en dépend
    void accountForgotten();
    void loginSucceeded(const QString &account_id);
    void loginFailed(const QString &error);
    // les jetons ont été refusés par Sony et effacés : il faut se reconnecter
    void credentialsExpired();
    // les jetons sont valides : les données du compte peuvent être demandées
    void tokensReady();

private:
    void exchangeCode(const QString &code, const QJSValue &callback);
    void eraseTokens();
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
