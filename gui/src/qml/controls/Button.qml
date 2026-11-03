// Bouton du thème Mac'n'Play, navigable à la manette.
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Button {
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false


    Component.onDestruction: {
        if (visualFocus) {
            let item = nextItemInFocusChain();
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        }
    }

    // navigation personnalisée (ex. grille des touches) : reçoit (élément, flèche)
    property var navHandler: null

    Keys.onPressed: (event) => {
        if (navHandler && [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].indexOf(event.key) >= 0) {
            navHandler(this, event.key);
            event.accepted = true;
            return;
        }
        // ← / → : passe au bouton voisin s'il est sur la même ligne
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            let item = nextItemInFocusChain(event.key === Qt.Key_Right);
            if (item && item !== this) {
                const mine = mapToItem(null, 0, height / 2).y;
                const theirs = item.mapToItem(null, 0, item.height / 2).y;
                if (Math.abs(mine - theirs) < 12) {
                    item.forceActiveFocus(Qt.TabFocusReason);
                    event.accepted = true;
                }
            }
            return;
        }
        switch (event.key) {
        case Qt.Key_Up:
            if (!firstInFocusChain) {
                let item = nextItemInFocusChain(false);
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                if(!sendOutput)
                    event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (!lastInFocusChain) {
                let item = nextItemInFocusChain();
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                if(!sendOutput)
                    event.accepted = true;
            }
            break;
        case Qt.Key_Return:
            if (visualFocus) {
                clicked();
            }
            event.accepted = true;
            break;
        }
    }

    // bouton en verre ; contour néon quand il a le focus manette
    id: glassButtonBase
    background: Rectangle {
        implicitHeight: 46
        radius: height / 2
        color: Qt.rgba(0.35, 0.55, 1, glassButtonBase.down ? 0.20 : (glassButtonBase.hovered ? 0.14 : 0.08))
        border.width: glassButtonBase.visualFocus ? 2 : 1
        border.color: glassButtonBase.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.25)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
