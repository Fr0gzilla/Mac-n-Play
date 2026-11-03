// Tests automatiques des règles métier (include/macnplayrules.h).
// Lancement : ctest dans le dossier de fabrication, ou directement ./macnplay-rules-test
#include "macnplayrules.h"

#include <QtTest>

using namespace MacnPlayRules;

class RulesTest : public QObject
{
    Q_OBJECT

private slots:
    void deuxConsolesAuMaximum()
    {
        QVERIFY(!consoleLimitReached(0));
        QVERIFY(!consoleLimitReached(1));
        QVERIFY(consoleLimitReached(2));
        QVERIFY(consoleLimitReached(3));
    }

    void masqueDeBoutons()
    {
        // L1 + R1 + L3 + R3 (réglages 10, 11, 12, 13 → bits 9 à 12)
        QCOMPARE(buttonComboMask({10, 11, 12, 13}), uint32_t(0b1111000000000));
        // l'ordre ne compte pas, les cases vides non plus
        QCOMPARE(buttonComboMask({13, 0, 10, 0}), buttonComboMask({10, 13, 0, 0}));
        QCOMPARE(buttonComboMask({0, 0, 0, 0}), uint32_t(0));
        // une valeur hors limites est ignorée au lieu de déborder
        QCOMPARE(buttonComboMask({99, 0, 0, 0}), uint32_t(0));
    }

    void combinaisonDuPaveTactile()
    {
        const std::array<uint32_t, 4> menu = {10, 11, 12, 13};
        // la même combinaison, dans un autre ordre : refusée
        QVERIFY(dpadComboClashesWithMenu({13, 12, 11, 10}, menu));
        // la combinaison par défaut L1 + R1 + Haut : acceptée
        QVERIFY(!dpadComboClashesWithMenu({10, 11, 8, 0}, menu));
        // aucune combinaison ne gêne jamais
        QVERIFY(!dpadComboClashesWithMenu({0, 0, 0, 0}, {0, 0, 0, 0}));
    }

    void renouvellementDesJetons()
    {
        const int64_t expiry = 10000;
        QVERIFY(!tokenNeedsRenewal(expiry - 3600, expiry));  // encore une heure : on garde
        QVERIFY(tokenNeedsRenewal(expiry - 30, expiry));     // moins d'une minute : on renouvelle
        QVERIFY(tokenNeedsRenewal(expiry + 1, expiry));      // déjà expiré
    }
};

QTEST_APPLESS_MAIN(RulesTest)
#include "rulestest.moc"
