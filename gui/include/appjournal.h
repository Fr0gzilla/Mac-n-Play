// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Journal de l'appli : un fichier texte par lancement, pour retrouver l'origine d'une panne.
//
// Chaque ligne donne l'heure, la gravité et le domaine du message, par exemple :
//   14:25:49.812  ATTENTION  [macnplay.psn]  Jetons : refusés par Sony, il faut se reconnecter
// Les fichiers (macnplay_AAAA-MM-JJ_HH-MM-SS.log) sont rangés avec les journaux de partie,
// dans ~/Library/Application Support/MacnPlay/MacnPlay/log ; les 5 derniers sont gardés.
#pragma once

#include <QObject>
#include <QStringList>
#include <QString>
#include <QtGlobal>

class QMessageLogContext;

namespace AppJournal
{
    // ouvre le fichier du lancement en cours et supprime les plus anciens
    void open();
    // ajoute un message Qt au fichier (sans effet si open() n'a pas réussi)
    void write(QtMsgType type, const QMessageLogContext &context, const QString &message);
    // masquer adresses et identifiants dès l'écriture (réglage « Masquer les adresses… »)
    void setSanitize(bool sanitize);
    // chemin du fichier du lancement en cours (vide si indisponible)
    QString currentPath();
    // dossier qui contient les journaux de l'appli et des parties
    QString folder();
    // version publiable d'un journal : adresses IP et MAC, identifiants, et les mots privés
    // donnés (pseudo PSN, noms des consoles) sont remplacés par des repères
    QString anonymize(const QString &text, const QStringList &private_words);
}

// Actions sur le journal pour les écrans (« Chiaki.journal ») : Paramètres › Configuration.
class Settings;

class JournalController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString path READ path CONSTANT)

public:
    JournalController(Settings *settings, QObject *parent = nullptr) : QObject(parent), settings(settings) {}
    void setSettings(Settings *settings) { this->settings = settings; }
    QString path() const { return AppJournal::currentPath(); }
    // copie le journal du lancement en cours, anonymisé, à coller dans un ticket GitHub ;
    // false s'il est illisible
    Q_INVOKABLE bool copyToClipboard() const;
    // ouvre le dossier des journaux (appli et parties) dans le Finder
    Q_INVOKABLE void openFolder() const;

private:
    Settings *settings;
};
