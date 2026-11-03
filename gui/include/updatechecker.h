// Contrôleur (MVC) des nouvelles versions.
//
// Rôle unique : savoir si une version plus récente de Mac'n'Play est publiée sur GitHub,
// pour le dire à l'utilisateur (« Chiaki.updates » côté écrans).
//   - Modèle : la page des versions du dépôt sur GitHub (sans compte).
//   - Vue    : le bandeau « nouvelle version » de l'accueil.
// Rien n'est téléchargé ni installé tout seul : l'utilisateur choisit.
#pragma once

#include <QObject>
#include <QString>
#include <QTimer>

class QNetworkAccessManager;

class UpdateChecker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    // page de la version (notes et fichier .dmg)
    Q_PROPERTY(QString pageUrl READ pageUrl NOTIFY changed)
    // l'utilisateur accepte que l'appli consulte GitHub une fois par jour (réglage enregistré)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)

public:
    explicit UpdateChecker(QObject *parent = nullptr);

    bool available() const { return is_available && !dismissed; }
    QString latestVersion() const { return latest_version; }
    QString pageUrl() const { return page_url; }
    bool enabled() const;
    void setEnabled(bool enabled);

    Q_INVOKABLE void checkNow();
    // « Plus tard » : le bandeau disparaît jusqu'au prochain lancement
    Q_INVOKABLE void dismiss();

signals:
    void changed();

private:
    QNetworkAccessManager *network;
    QTimer daily_timer;
    bool is_available = false;
    bool dismissed = false;
    QString latest_version;
    QString page_url;
};
