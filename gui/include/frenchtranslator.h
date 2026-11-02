// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef CHIAKI_FRENCHTRANSLATOR_H
#define CHIAKI_FRENCHTRANSLATOR_H

#include <QTranslator>
#include <QHash>

// Traduction française de l'interface, chargée quand le système est en français
// (ou avec la variable d'environnement CHIAKI_LANG=fr ; CHIAKI_LANG=en la désactive).
class FrenchTranslator : public QTranslator
{
	Q_OBJECT

	public:
		explicit FrenchTranslator(QObject *parent = nullptr);
		QString translate(const char *context, const char *source_text, const char *disambiguation = nullptr, int n = -1) const override;
		bool isEmpty() const override { return false; }

		static bool Wanted();

	private:
		QHash<QString, QString> table;
};

#endif // CHIAKI_FRENCHTRANSLATOR_H
