// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL
// Copyright (C) 2026 Fr0gzilla (Mac'n'Play)
// Règles métier de Mac'n'Play, en fonctions pures (sans Qt, sans réseau, sans écran),
// pour pouvoir les vérifier par des tests automatiques (gui/tests/rulestest.cpp).
#pragma once

#include <array>
#include <cstdint>
#include <string>
#include <vector>

namespace MacnPlayRules
{
    // nombre maximal de consoles associées à l'appli
    constexpr int MAX_CONSOLES = 2;

    inline bool consoleLimitReached(int registered_consoles)
    {
        return registered_consoles >= MAX_CONSOLES;
    }

    // une combinaison de boutons est réglée par 4 valeurs « numéro du bouton + 1 » (0 = aucun) ;
    // on la transforme en masque de bits, indépendant de l'ordre des boutons
    inline uint32_t buttonComboMask(const std::array<uint32_t, 4> &buttons)
    {
        uint32_t mask = 0;
        for(uint32_t button : buttons)
        {
            if(button > 0 && button <= 32)
                mask |= 1u << (button - 1);
        }
        return mask;
    }

    // la croix « pavé tactile » ne peut pas utiliser la combinaison du menu en jeu :
    // ouvrir le menu basculerait aussi la croix
    inline bool dpadComboClashesWithMenu(const std::array<uint32_t, 4> &dpad, const std::array<uint32_t, 4> &menu)
    {
        const uint32_t dpad_mask = buttonComboMask(dpad);
        return dpad_mask != 0 && dpad_mask == buttonComboMask(menu);
    }

    // marge avant l'expiration d'un jeton PSN : un jeton qui expire pendant la requête serait refusé
    constexpr int64_t TOKEN_RENEWAL_MARGIN_SECONDS = 60;

    inline bool tokenNeedsRenewal(int64_t now_seconds, int64_t expiry_seconds)
    {
        return now_seconds + TOKEN_RENEWAL_MARGIN_SECONDS >= expiry_seconds;
    }

    // ---- versions (prévenir qu'une nouvelle version est sortie) ----

    // « v1.2.3 » ou « 1.2.3 » → {1, 2, 3} ; vide si ce n'est pas un numéro de version
    // (par exemple « dev-b565efe » pour une fabrication de test). Une pré-version
    // (« 1.2.3-beta ») donne les mêmes nombres : voir isPrerelease().
    inline std::vector<int> parseVersion(std::string text)
    {
        if(!text.empty() && (text[0] == 'v' || text[0] == 'V'))
            text.erase(0, 1);
        const size_t dash = text.find('-');
        if(dash != std::string::npos && dash > 0)
            text.erase(dash);
        std::vector<int> parts;
        int value = -1;
        for(char c : text)
        {
            if(c >= '0' && c <= '9')
                value = (value < 0 ? 0 : value * 10) + (c - '0');
            else if(c == '.' && value >= 0)
            {
                parts.push_back(value);
                value = -1;
            }
            else
                return {};
        }
        if(value < 0)
            return {};
        parts.push_back(value);
        return parts;
    }

    // « 1.2.3-beta » : pré-version, plus ancienne que la version finale « 1.2.3 »
    inline bool isPrerelease(const std::string &text)
    {
        const size_t dash = text.find('-');
        return dash != std::string::npos && dash > 1 && !parseVersion(text).empty();
    }

    // la version publiée est-elle plus récente que celle installée ?
    // (une version installée sans numéro, fabrication de test, n'est jamais signalée)
    inline bool versionIsNewer(const std::string &published, const std::string &installed)
    {
        std::vector<int> a = parseVersion(published), b = parseVersion(installed);
        if(a.empty() || b.empty())
            return false;
        const size_t n = a.size() > b.size() ? a.size() : b.size();
        a.resize(n, 0);
        b.resize(n, 0);
        if(a != b)
            return a > b;
        // mêmes numéros : la version finale l'emporte sur la pré-version
        return isPrerelease(installed) && !isPrerelease(published);
    }

    // ---- qualité du jeu à distance (par Internet) ----

    // préréglages de définition de la bibliothèque : 1 = 360p, 2 = 540p, 3 = 720p, 4 = 1080p
    constexpr int PRESET_360P = 1;
    constexpr int PRESET_540P = 2;
    constexpr int PRESET_720P = 3;

    // adresse IPv4 (en nombre) donnée par un partage de connexion de téléphone :
    // iPhone 172.20.10.0/28 (fiable) ; Android 192.168.43.0/24, mais seulement jusqu'à
    // Android 10 : depuis Android 11 le réseau est tiré au hasard et n'est pas reconnu
    inline bool isPhoneHotspotAddress(uint32_t ipv4)
    {
        return (ipv4 & 0xFFFFFFF0u) == 0xAC140A00u    // 172.20.10.0/28
            || (ipv4 & 0xFFFFFF00u) == 0xC0A82B00u;   // 192.168.43.0/24
    }

    // définition de départ d'une partie par Internet : légère sur un téléphone,
    // moyenne sinon ; jamais plus que ce que l'utilisateur a choisi
    inline int remoteStartPreset(bool phone_hotspot, int chosen_preset)
    {
        const int automatic = phone_hotspot ? PRESET_360P : PRESET_540P;
        return chosen_preset < automatic ? chosen_preset : automatic;
    }

    // pertes au-delà desquelles l'image saccade nettement (fraction de paquets perdus)
    constexpr double HIGH_PACKET_LOSS = 0.05;
    // durée de pertes élevées avant de baisser la qualité (secondes)
    constexpr int HIGH_LOSS_SECONDS_BEFORE_LOWERING = 10;

    // pendant une partie par Internet : faut-il baisser la définition d'un cran ?
    // renvoie le nouveau préréglage, ou celui en cours s'il ne faut rien changer
    inline int presetAfterLosses(int current_preset, int seconds_with_high_loss)
    {
        if(seconds_with_high_loss < HIGH_LOSS_SECONDS_BEFORE_LOWERING || current_preset <= PRESET_360P)
            return current_preset;
        return current_preset - 1;
    }

    // ---- nom affiché sur l'accueil ----

    // Sony appelle la PS4 du compte « Main PS4 Console » : on montre plutôt son vrai nom
    // (celui de la PS4 associée), quand on le connaît
    inline std::string consoleDisplayName(const std::string &psn_name, const std::string &registered_ps4_name)
    {
        if(psn_name == "Main PS4 Console" && !registered_ps4_name.empty())
            return registered_ps4_name;
        return psn_name;
    }
}

