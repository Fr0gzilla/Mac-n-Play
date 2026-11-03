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

    void lectureDesNumerosDeVersion()
    {
        QCOMPARE(parseVersion("v1.2.3"), std::vector<int>({1, 2, 3}));
        QCOMPARE(parseVersion("1.0.111"), std::vector<int>({1, 0, 111}));
        QVERIFY(parseVersion("dev-b565efe").empty());
        QVERIFY(parseVersion("1..2").empty());
        QVERIFY(parseVersion("").empty());
    }

    void nouvelleVersionDisponible()
    {
        QVERIFY(versionIsNewer("v1.1.0", "1.0.0"));
        QVERIFY(versionIsNewer("v1.0.10", "1.0.9"));      // 10 > 9 : on compare des nombres, pas du texte
        QVERIFY(!versionIsNewer("v1.0.0", "1.0.0"));
        QVERIFY(!versionIsNewer("v1.0.0", "1.1.2"));
        QVERIFY(versionIsNewer("v1.1", "1.0.5"));          // nombre de parties différent
        QVERIFY(!versionIsNewer("v1.1.0", "dev-b565efe"));  // fabrication de test : jamais signalée
    }

    void reconnaissanceDuPartageDeConnexion()
    {
        QVERIFY(isPhoneHotspotAddress(0xAC140A02u));   // 172.20.10.2 (iPhone)
        QVERIFY(isPhoneHotspotAddress(0xC0A82B05u));   // 192.168.43.5 (Android)
        QVERIFY(!isPhoneHotspotAddress(0xC0A8013Cu));  // 192.168.1.60 (box)
        QVERIFY(!isPhoneHotspotAddress(0xAC140A10u));  // 172.20.10.16 : hors de la plage iPhone
    }

    void qualiteDeDepartADistance()
    {
        QCOMPARE(remoteStartPreset(true, PRESET_720P), PRESET_360P);   // téléphone : léger
        QCOMPARE(remoteStartPreset(false, PRESET_720P), PRESET_540P);  // autre réseau : moyen
        QCOMPARE(remoteStartPreset(false, PRESET_360P), PRESET_360P);  // jamais au-dessus du choix
    }

    void baisseDeQualiteSurPertes()
    {
        QCOMPARE(presetAfterLosses(PRESET_720P, 3), PRESET_720P);   // pertes trop brèves : on garde
        QCOMPARE(presetAfterLosses(PRESET_720P, 12), PRESET_540P);  // pertes durables : un cran de moins
        QCOMPARE(presetAfterLosses(PRESET_360P, 60), PRESET_360P);  // déjà au minimum
    }

    void nomAfficheDeLaConsole()
    {
        QCOMPARE(consoleDisplayName("Main PS4 Console", "PS4-955"), std::string("PS4-955"));
        QCOMPARE(consoleDisplayName("Main PS4 Console", ""), std::string("Main PS4 Console"));
        QCOMPARE(consoleDisplayName("PS5-Salon", "PS4-955"), std::string("PS5-Salon"));
    }
};

QTEST_APPLESS_MAIN(RulesTest)
#include "rulestest.moc"
