// Case à cocher du thème, navigable à la manette.
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

CheckBox {
    id: focusable
    // sans texte (case seule) : un rond centré autour de la case
    leftPadding: text ? 14 : 12
    rightPadding: text ? 20 : 12
    spacing: text ? 12 : 0
    // case carrée néon (remplace la case Material et son halo gris qui débordait)
    indicator: Rectangle {
        x: focusable.text ? focusable.leftPadding : (focusable.width - width) / 2
        y: focusable.topPadding + (focusable.availableHeight - height) / 2
        width: 22; height: 22
        radius: 6
        color: focusable.checkState !== Qt.Unchecked ? Qt.rgba(0.24, 0.48, 1, 0.30) : Qt.rgba(1, 1, 1, 0.04)
        border.width: 2
        border.color: focusable.checkState !== Qt.Unchecked || focusable.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.45)
        opacity: focusable.enabled ? 1 : 0.4
        Text {
            anchors.centerIn: parent
            text: focusable.checkState === Qt.PartiallyChecked ? "–" : "✓"
            visible: focusable.checkState !== Qt.Unchecked
            color: "#d6e6ff"
            font.pixelSize: 16
            font.bold: true
        }
    }
    // contour néon autour de toute la ligne quand la manette est dessus, léger reflet au survol
    background: Rectangle {
        implicitHeight: 46
        radius: height / 2
        color: Qt.rgba(0.0, 0.27, 0.75, focusable.visualFocus ? 0.10 : (focusable.hovered ? 0.06 : 0))
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 2
            border.color: "#3d7bff"
            opacity: focusable.visualFocus ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
        }
    }
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false

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
                toggle();
                clicked();
            }
            event.accepted = true;
            break;
        }
    }
}
