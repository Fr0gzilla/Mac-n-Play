// Règles métier de Mac'n'Play, en fonctions pures (sans Qt, sans réseau, sans écran),
// pour pouvoir les vérifier par des tests automatiques (gui/tests/rulestest.cpp).
#pragma once

#include <array>
#include <cstdint>

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
}
