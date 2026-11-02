import QtQml

// noms et symboles des boutons de manette, partagés par les pages Touches et Affectation
QtObject {
    // nom court et symbole néon d'un bouton (valeurs de la bibliothèque chiaki)
    function info(value, fallback) {
        const ps = "qrc:/icons/ps/";
        switch (value) {
        case 1: return { label: qsTr("Cross"), icon: ps + "croix.svg" };
        case 2: return { label: qsTr("Circle"), icon: ps + "rond.svg" };
        case 4: return { label: qsTr("Square"), icon: ps + "carre.svg" };
        case 8: return { label: qsTr("Triangle"), icon: ps + "triangle.svg" };
        case 64: case 1 << 20: case 1 << 24: return { label: qsTr("Up"), glyph: "↑" };
        case 128: case 1 << 21: case 1 << 25: return { label: qsTr("Down"), glyph: "↓" };
        case 16: case 1 << 19: case 1 << 23: return { label: qsTr("Left"), glyph: "←" };
        case 32: case 1 << 18: case 1 << 22: return { label: qsTr("Right"), glyph: "→" };
        case 1 << 26: case 1 << 28: return { label: qsTr("Horizontal"), glyph: "↔" };
        case 1 << 27: case 1 << 29: return { label: qsTr("Vertical"), glyph: "↕" };
        case 256: return { label: "L1", icon: "qrc:/icons/l1.svg" };
        case 512: return { label: "R1", icon: "qrc:/icons/r1.svg" };
        case 65536: return { label: "L2", icon: "qrc:/icons/l2.svg" };
        case 131072: return { label: "R2", icon: "qrc:/icons/r2.svg" };
        case 1024: return { label: qsTr("Press (L3)"), glyph: "L3" };
        case 2048: return { label: qsTr("Press (R3)"), glyph: "R3" };
        case 4096: return { label: qsTr("Options"), glyph: "☰" };
        case 8192: return { label: qsTr("Share / Create"), glyph: "⇪" };
        case 16384: return { label: fallback, glyph: "▭" };
        case 32768: return { label: qsTr("PS button"), glyph: "PS" };
        case 1 << 30: return { label: qsTr("Mic"), glyph: "MIC" };
        default: return { label: fallback, glyph: "•" };
        }
    }

    // nom lisible d'un bouton physique tel que SDL le note (« b0 », « h0.1 », « +a2 »…).
    // Sur une manette PlayStation, SDL numérote les boutons dans l'ordre standard : on peut les nommer.
    function physicalName(raw, playStation) {
        if (!raw)
            return "";
        const m = raw.match(/^([+-]?)([abh])(\d+)(?:\.(\d+))?~?$/);
        if (!m)
            return raw;
        const sign = m[1], kind = m[2], n = parseInt(m[3]);
        if (kind === "h")
            return { 1: "↑", 2: "→", 4: "↓", 8: "←" }[parseInt(m[4])] || raw;
        if (kind === "b") {
            // ordre vu sur une manette PS4 avec SDL sous macOS (la croix directionnelle est un « h »)
            const names = ["✕", "○", "□", "△", "Share", "PS", "Options", "L3", "R3", "L1", "R1", qsTr("Touchpad")];
            if (playStation && n < names.length)
                return names[n];
            return qsTr("Button %1").arg(n + 1);
        }
        const axes = [qsTr("L stick ↔"), qsTr("L stick ↕"), qsTr("R stick ↔"), qsTr("R stick ↕"), "L2", "R2"];
        const axis = playStation && n < axes.length ? axes[n] : qsTr("Axis %1").arg(n + 1);
        return sign ? axis + " " + sign : axis;
    }

    // symbole néon du bouton physique quand on le connaît (manette PlayStation), sinon ""
    function physicalIcon(raw, playStation) {
        if (!raw || !playStation)
            return "";
        const icons = {
            "b0": "qrc:/icons/ps/croix.svg", "b1": "qrc:/icons/ps/rond.svg", "b2": "qrc:/icons/ps/carre.svg", "b3": "qrc:/icons/ps/triangle.svg",
            "b9": "qrc:/icons/l1.svg", "b10": "qrc:/icons/r1.svg", "a4": "qrc:/icons/l2.svg", "+a4": "qrc:/icons/l2.svg",
            "a5": "qrc:/icons/r2.svg", "+a5": "qrc:/icons/r2.svg"
        };
        return icons[raw.replace("~", "")] || "";
    }

    // ce que fait chaque bouton dans les jeux (« Sélection » pour ✕…), comme l'affiche la page Manette
    function role(value, fallback) {
        switch (value) {
        case 1: return qsTr("Selection");
        case 2: return qsTr("Back");
        case 4: case 8: return qsTr("Game action");
        case 64: case 1 << 20: case 1 << 24: return qsTr("Up");
        case 128: case 1 << 21: case 1 << 25: return qsTr("Down");
        case 16: case 1 << 19: case 1 << 23: return qsTr("Left");
        case 32: case 1 << 18: case 1 << 22: return qsTr("Right");
        case 256: return qsTr("Left shoulder");
        case 512: return qsTr("Right shoulder");
        case 65536: return qsTr("Left trigger");
        case 131072: return qsTr("Right trigger");
        case 1024: return qsTr("Left stick press");
        case 2048: return qsTr("Right stick press");
        case 1 << 26: case 1 << 28: return qsTr("Horizontal");
        case 1 << 27: case 1 << 29: return qsTr("Vertical");
        case 4096: return qsTr("Game menu");
        case 8192: return qsTr("Capture and share");
        case 32768: return qsTr("PlayStation menu");
        default: return fallback;
        }
    }
}
