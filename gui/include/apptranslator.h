// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Traduction de l'interface.
//
// Rôle unique : traduire les textes anglais de qsTr()/tr() dans la langue du Mac.
// Une table par langue dans include/translations/<code>.inc, lignes { "anglais", "traduction" }.
// L'anglais est la langue d'origine des textes : il n'a pas de table.
// La langue suit celle du Mac (ou celle choisie pour l'appli dans Réglages Système › Langue
// et région › Applications) ; la variable d'environnement CHIAKI_LANG=<code> la force (tests).
#pragma once

#include <QTranslator>
#include <QHash>

class AppTranslator : public QTranslator
{
	Q_OBJECT

	public:
		AppTranslator(const QString &language, QObject *parent = nullptr);
		QString translate(const char *context, const char *source_text, const char *disambiguation = nullptr, int n = -1) const override;
		bool isEmpty() const override { return table.isEmpty(); }

		// code de la langue à utiliser (« fr », « de »…), vide pour garder l'anglais
		static QString WantedLanguage();

	private:
		QHash<QString, QString> table;
};
