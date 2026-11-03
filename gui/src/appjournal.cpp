// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "appjournal.h"
#include "sessionlog.h"
#include "settings.h"

#include <QRegularExpression>
#include <QSettings>

#include <QClipboard>
#include <QDateTime>
#include <QDesktopServices>
#include <QGuiApplication>
#include <QUrl>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QTextStream>

namespace
{
    // nombre de journaux de l'appli gardés (le plus récent compris)
    const int KEPT_JOURNALS = 5;
    QMutex journal_mutex;
    QFile journal_file;
    bool sanitize_lines = true;

    const char *severityLabel(QtMsgType type)
    {
        switch(type)
        {
            case QtDebugMsg: return "détail   ";
            case QtInfoMsg: return "info     ";
            case QtWarningMsg: return "ATTENTION";
            case QtCriticalMsg: return "ERREUR   ";
            case QtFatalMsg: return "FATAL    ";
        }
        return "?        ";
    }

    void removeOldJournals(QDir dir)
    {
        dir.setNameFilters({ "macnplay_*.log" });
        // les noms contiennent la date : l'ordre alphabétique inverse va du plus récent au plus ancien
        const QStringList journals = dir.entryList(QDir::Files, QDir::Name | QDir::Reversed);
        for(int i = KEPT_JOURNALS - 1; i < journals.size(); i++)
            dir.remove(journals.at(i));
    }
}

void AppJournal::open()
{
    const QString dir_path = GetLogBaseDir();
    if(dir_path.isEmpty())
        return;
    QDir dir(dir_path);
    removeOldJournals(dir);
    QMutexLocker lock(&journal_mutex);
    journal_file.setFileName(dir.absoluteFilePath("macnplay_" + QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss") + ".log"));
    if(!journal_file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text))
        return;
    QTextStream(&journal_file) << "Journal de Mac'n'Play, lancé le " << QDateTime::currentDateTime().toString("dd/MM/yyyy à HH:mm:ss") << "\n";
    journal_file.flush();
}

void AppJournal::write(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    QMutexLocker lock(&journal_mutex);
    if(!journal_file.isOpen())
        return;
    QTextStream out(&journal_file);
    out << QTime::currentTime().toString("HH:mm:ss.zzz") << "  " << severityLabel(type) << "  ";
    if(context.category && qstrcmp(context.category, "default") != 0)
        out << "[" << context.category << "]  ";
    out << (sanitize_lines ? SanitizeLogMessage(message) : message) << "\n";
    // écrit tout de suite : si l'appli plante, la dernière ligne reste lisible
    journal_file.flush();
}

void AppJournal::setSanitize(bool sanitize)
{
    QMutexLocker lock(&journal_mutex);
    sanitize_lines = sanitize;
}

QString AppJournal::currentPath()
{
    QMutexLocker lock(&journal_mutex);
    return journal_file.isOpen() ? journal_file.fileName() : QString();
}

QString AppJournal::folder()
{
    return GetLogBaseDir();
}

QString AppJournal::anonymize(const QString &text, const QStringList &private_words)
{
    static const QRegularExpression mac_plain(QStringLiteral("\\b[0-9A-Fa-f]{12}\\b"));
    static const QRegularExpression mac_colons(QStringLiteral("\\b(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\\b"));
    QStringList lines = text.split(u'\n');
    for(QString &line : lines)
    {
        line = SanitizeLogMessage(line);
        line.replace(mac_colons, QStringLiteral("<adresse-mac>"));
        line.replace(mac_plain, QStringLiteral("<adresse-mac>"));
        for(const QString &word : private_words)
        {
            if(word.size() >= 3)
                line.replace(word, QStringLiteral("<nom>"), Qt::CaseInsensitive);
        }
    }
    return lines.join(u'\n');
}

bool JournalController::copyToClipboard() const
{
    QFile file(AppJournal::currentPath());
    if(file.fileName().isEmpty() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    // le journal est fait pour être collé dans un ticket public : pseudo et noms des consoles masqués
    QStringList private_words;
    if(settings)
    {
        for(const auto &host : settings->GetRegisteredHosts())
            private_words << host.GetServerNickname();
    }
    private_words << QSettings().value("macnplay/psnProfile").toMap().value("onlineId").toString();
    QGuiApplication::clipboard()->setText(AppJournal::anonymize(QString::fromUtf8(file.readAll()), private_words));
    return true;
}

void JournalController::openFolder() const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(AppJournal::folder()));
}
