// Pastille d'état (« En ligne », « PSN non connecté »…).
import QtQuick
import QtQuick.Controls

// Petite pastille : un point de couleur et un mot (état de la console, association…)
Rectangle {
    property color dot: "#9ca3af"
    property alias text: pillLabel.text
    implicitWidth: pillRow.implicitWidth + 28
    implicitHeight: 34
    radius: height / 2
    color: Qt.rgba(dot.r, dot.g, dot.b, 0.16)
    border.width: 1
    border.color: Qt.rgba(dot.r, dot.g, dot.b, 0.5)

    Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            radius: 5
            color: parent.parent.dot
        }

        Label {
            id: pillLabel
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }
    }
}
