// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)

#include <apptranslator.h>

#include <QLocale>

namespace
{
	struct Entry { const char *source; const char *translation; };

	const Entry french[] = {
#include "translations/fr.inc"
	};
	const Entry german[] = {
#include "translations/de.inc"
	};
	const Entry spanish[] = {
#include "translations/es.inc"
	};
	const Entry italian[] = {
#include "translations/it.inc"
	};
	const Entry portuguese[] = {
#include "translations/pt.inc"
	};

	struct Language { const char *code; const Entry *entries; size_t count; };
	template<size_t N> constexpr Language language(const char *code, const Entry (&entries)[N]) { return { code, entries, N }; }

	// langues traduites ; à garder en accord avec CFBundleLocalizations (MacOSXBundleInfo.plist.in)
	const Language languages[] = {
		language("fr", french),
		language("de", german),
		language("es", spanish),
		language("it", italian),
		language("pt", portuguese),
	};

	const Language *find(const QString &code)
	{
		for(const Language &lang : languages)
			if(code.startsWith(QLatin1String(lang.code)))
				return &lang;
		return nullptr;
	}
}

AppTranslator::AppTranslator(const QString &language, QObject *parent)
	: QTranslator(parent)
{
	const Language *lang = find(language);
	if(!lang)
		return;
	table.reserve(lang->count);
	for(size_t i = 0; i < lang->count; i++)
		table.insert(QString::fromUtf8(lang->entries[i].source), QString::fromUtf8(lang->entries[i].translation));
}

QString AppTranslator::translate(const char *context, const char *source_text, const char *disambiguation, int n) const
{
	Q_UNUSED(context);
	Q_UNUSED(disambiguation);
	Q_UNUSED(n);
	if(!source_text)
		return QString();
	return table.value(QString::fromUtf8(source_text));
}

QString AppTranslator::WantedLanguage()
{
	const QString forced = qEnvironmentVariable("CHIAKI_LANG").toLower();
	if(!forced.isEmpty())
		return find(forced) ? QString::fromLatin1(find(forced)->code) : QString();
	// la première langue préférée du Mac que l'appli connaît ; l'anglais arrête la recherche
	for(const QString &ui_lang : QLocale::system().uiLanguages())
	{
		if(ui_lang.startsWith("en"))
			return QString();
		if(const Language *lang = find(ui_lang))
			return QString::fromLatin1(lang->code);
	}
	return QString();
}
