import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects

// fenêtre « appuyez sur un bouton » : symbole néon qui pulse, consigne, bouton Annuler.
// La capture elle-même reste dans la page qui l'ouvre (élément invisible qui prend le focus).
Dialog {
    id: capture
    property string icon: ""
    property string glyph: ""
    property string heading: ""
    property string detail: ""

    modal: true
    title: ""
    header: null
    footer: null
    padding: 34
    topPadding: 30
    closePolicy: Popup.CloseOnPressOutside

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 200; easing.type: Easing.OutBack }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
    }

    background: Rectangle {
        radius: 26
        color: "#0a1430"
        border.width: 1
        border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 1.0
            shadowOpacity: 0.7
            shadowVerticalOffset: 10
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        // symbole du bouton dans un anneau néon qui « respire » en attendant l'appui
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            Rectangle {
                id: ring
                anchors.centerIn: parent
                width: 92
                height: 92
                radius: width / 2
                color: Qt.rgba(0.0, 0.27, 0.75, 0.12)
                border.width: 2
                border.color: "#3d7bff"
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#0046c0"
                    shadowBlur: 0.8
                    shadowOpacity: 1.0
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
                SequentialAnimation on scale {
                    running: capture.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.08; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.08; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Image {
                anchors.centerIn: parent
                visible: !!capture.icon
                width: 44
                height: 44
                sourceSize: Qt.size(88, 88)
                source: capture.icon
            }
            Text {
                anchors.centerIn: parent
                visible: !capture.icon
                text: capture.glyph
                color: "#9cc2ff"
                font.pixelSize: text.length > 1 ? 24 : 38
                font.bold: true
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            text: capture.heading
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 380
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""
            text: capture.detail
            font.pixelSize: 15
            opacity: 0.6
        }

        GlassButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            focusPolicy: Qt.NoFocus
            text: qsTr("Cancel")
            onClicked: capture.close()
        }
    }
}
