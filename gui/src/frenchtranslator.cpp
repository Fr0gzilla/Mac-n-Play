// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#include <frenchtranslator.h>

#include <QLocale>

namespace
{
	struct Entry { const char *source; const char *french; };
	const Entry entries[] = {
#include "frenchtranslations.inc"
	};
}

FrenchTranslator::FrenchTranslator(QObject *parent)
	: QTranslator(parent)
{
	table.reserve(sizeof(entries) / sizeof(entries[0]));
	for(const Entry &entry : entries)
		table.insert(QString::fromUtf8(entry.source), QString::fromUtf8(entry.french));
}

QString FrenchTranslator::translate(const char *context, const char *source_text, const char *disambiguation, int n) const
{
	Q_UNUSED(context);
	Q_UNUSED(disambiguation);
	Q_UNUSED(n);
	if(!source_text)
		return QString();
	return table.value(QString::fromUtf8(source_text));
}

bool FrenchTranslator::Wanted()
{
	QString lang = qEnvironmentVariable("CHIAKI_LANG").toLower();
	if(!lang.isEmpty())
		return lang.startsWith("fr");
	for(const QString &ui_lang : QLocale::system().uiLanguages())
	{
		if(ui_lang.startsWith("fr"))
			return true;
		if(ui_lang.startsWith("en"))
			return false;
	}
	return false;
}
