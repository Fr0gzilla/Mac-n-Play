// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_SESSIONLOG_H
#define CHIAKI_SESSIONLOG_H

#include <chiaki/log.h>

#include <QString>
#include <QDir>
#include <QMutex>
#include <QAtomicInteger>

class QFile;
class StreamSession;

class SessionLog
{
	friend class SessionLogPrivate;

	private:
		StreamSession *session;
		ChiakiLog log;
		QFile *file;
		QMutex file_mutex;
		QAtomicInteger<bool> shutdown;
		bool sanitize;

		void Log(ChiakiLogLevel level, const char *msg);

	public:
		SessionLog(StreamSession *session, uint32_t level_mask, const QString &filename, bool sanitize);
		~SessionLog();

		ChiakiLog *GetChiakiLog()	{ return &log; }
		void PrepareShutdown();
};

// masque adresses IP, identifiants de compte, de console et de session dans un message
QString SanitizeLogMessage(const QString &msg);

// vrai pendant qu'un message de l'appli (Qt) est recopié dans le journal de la partie :
// il a déjà été affiché dans la console macOS, on ne l'y réimprime pas
extern thread_local bool session_log_from_qt;
QString GetLogBaseDir();
QString CreateLogFilename();

#endif //CHIAKI_SESSIONLOG_H
