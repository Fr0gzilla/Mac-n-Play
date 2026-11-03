// Bouton rond en verre (barre du haut).
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Bouton en pastille : plein (couleur d’accent) pour l'action principale, en verre pour les autres
Button {
    id: button
    property bool primary: false
    property string badge: ""
    flat: true
    leftPadding: badge ? 54 : 26
    rightPadding: 26
    topPadding: 12
    bottomPadding: 12
    font.weight: primary ? Font.DemiBold : Font.Normal
    Material.foreground: "#ffffff"

    background: Rectangle {
        implicitHeight: 52
        radius: height / 2
        color: button.primary
            ? (button.down ? Qt.darker(Material.accent, 1.15) : Material.accent)
            : Qt.rgba(1, 1, 1, button.down ? 0.20 : (button.hovered || button.activeFocus ? 0.16 : 0.10))
        border.width: button.primary ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, button.activeFocus ? 0.6 : 0.22)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Image {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 14
        }
        width: 28
        height: 28
        sourceSize: Qt.size(width, height)
        source: button.badge
        visible: button.badge !== ""
    }
}
