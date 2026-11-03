#include "appjournal.h"
#include "sessionlog.h"

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
    out << message << "\n";
    // écrit tout de suite : si l'appli plante, la dernière ligne reste lisible
    journal_file.flush();
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

bool JournalController::copyToClipboard() const
{
    QFile file(AppJournal::currentPath());
    if(file.fileName().isEmpty() || !file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;
    QGuiApplication::clipboard()->setText(QString::fromUtf8(file.readAll()));
    return true;
}

void JournalController::openFolder() const
{
    QDesktopServices::openUrl(QUrl::fromLocalFile(AppJournal::folder()));
}
