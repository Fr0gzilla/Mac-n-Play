// Fond en verre translucide des fenêtres.
import QtQuick

// Fond « verre » commun aux fenêtres : teinte sombre translucide, liseré clair et reflet en haut
Rectangle {
    property real tint: 0.78
    radius: 28
    color: Qt.rgba(0.03, 0.07, 0.17, tint)
    border.width: 1
    border.color: Qt.rgba(0.6, 0.75, 1, 0.22)

    Rectangle {
        anchors { fill: parent; margins: 1 }
        radius: parent.radius - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.12) }
            GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
