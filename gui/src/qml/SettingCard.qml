// Carte d'un réglage : nom et explication à gauche, commande (enfant) à droite.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    property alias title: cardTitle.text
    property alias hint: cardHint.text
    default property alias control: cardHolder.data
    property real controlWidth: 420
    Layout.fillWidth: true
    implicitHeight: Math.max(cardText.implicitHeight, cardHolder.implicitHeight) + 36
    radius: 18
    color: Qt.rgba(0.35, 0.55, 1, 0.05)
    border.width: 1
    border.color: Qt.rgba(0.6, 0.75, 1, 0.16)
    RowLayout {
        anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
        spacing: 24
        ColumnLayout {
            id: cardText
            Layout.fillWidth: true
            spacing: 4
            Label {
                id: cardTitle
                Layout.fillWidth: true
                font.pixelSize: 17
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
            }
            Label {
                id: cardHint
                Layout.fillWidth: true
                visible: text !== ""
                font.pixelSize: 14
                opacity: 0.55
                wrapMode: Text.WordWrap
            }
        }
        Item {
            id: cardHolder
            Layout.preferredWidth: controlWidth
            Layout.preferredHeight: childrenRect.height
            implicitHeight: childrenRect.height
        }
    }
}
