// Bouton d'option du thème, navigable à la manette.
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

RadioButton {
    id: focusable
    // sans texte (case seule) : un rond centré autour de la case
    leftPadding: text ? 14 : 12
    rightPadding: text ? 20 : 12
    spacing: text ? 12 : 0
    // rond néon (remplace le bouton Material et son halo gris qui débordait)
    indicator: Rectangle {
        x: focusable.text ? focusable.leftPadding : (focusable.width - width) / 2
        y: focusable.topPadding + (focusable.availableHeight - height) / 2
        width: 22; height: 22
        radius: 11
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 2
        border.color: focusable.checked || focusable.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.45)
        opacity: focusable.enabled ? 1 : 0.4
        Rectangle {
            anchors.centerIn: parent
            width: 10; height: 10
            radius: 5
            color: "#9cc2ff"
            visible: focusable.checked
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

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
            if (!firstInFocusChain) {
                let item = nextItemInFocusChain(false);
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (!lastInFocusChain) {
                let item = nextItemInFocusChain();
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
            break;
        case Qt.Key_Return:
            if (visualFocus) {
                toggle();
                toggled();
            }
            event.accepted = true;
            break;
        }
    }
}
