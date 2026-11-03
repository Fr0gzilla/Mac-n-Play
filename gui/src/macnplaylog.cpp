// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include "macnplaylog.h"

Q_LOGGING_CATEGORY(logPsn, "macnplay.psn", QtInfoMsg)
Q_LOGGING_CATEGORY(logConsoles, "macnplay.consoles", QtInfoMsg)
Q_LOGGING_CATEGORY(logSession, "macnplay.session", QtInfoMsg)
Q_LOGGING_CATEGORY(logController, "macnplay.controller", QtInfoMsg)

void ChiakiLogToJournal(ChiakiLogLevel level, const char *msg, void *user)
{
    const QLoggingCategory &category = *static_cast<const QLoggingCategory *>(user);
    switch(level)
    {
        case CHIAKI_LOG_ERROR:
            qCCritical(category).noquote() << msg;
            break;
        case CHIAKI_LOG_WARNING:
            qCWarning(category).noquote() << msg;
            break;
        case CHIAKI_LOG_INFO:
            qCInfo(category).noquote() << msg;
            break;
        default:
            qCDebug(category).noquote() << msg;
            break;
    }
}
