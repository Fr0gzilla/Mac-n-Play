// Onglet du thème (Paramètres).
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

// Onglet en pastille : bleu PlayStation quand il est actif, discret sinon
TabButton {
    id: tab
    font.pixelSize: 17
    font.weight: checked ? Font.DemiBold : Font.Normal

    contentItem: Label {
        text: tab.text
        font: tab.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        color: tab.checked ? "#9cc2ff" : "#ffffff"
        opacity: tab.checked ? 1.0 : (tab.hovered ? 0.85 : 0.6)
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    background: Rectangle {
        implicitHeight: 44
        radius: height / 2
        color: Qt.rgba(0.6, 0.75, 1, tab.hovered && !tab.checked ? 0.10 : 0.0)
        Behavior on color { ColorAnimation { duration: 180 } }
    }
}
