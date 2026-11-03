// Barre de défilement du thème.
import QtQuick
import QtQuick.Controls

// Barre de défilement néon : tige bleue fine, plus large au survol,
// estompée au repos et éclairée pendant le défilement
ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    padding: 4
    minimumSize: 0.08

    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 8 : 5
        implicitHeight: implicitWidth
        radius: width / 2
        color: bar.pressed ? "#7fb0ff" : "#3d7bff"
        opacity: bar.size >= 1.0 ? 0.0 : (bar.active || bar.hovered ? 0.95 : 0.35)
        Behavior on implicitWidth { NumberAnimation { duration: 140 } }
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    background: Rectangle {
        implicitWidth: 14
        radius: width / 2
        color: Qt.rgba(0.6, 0.75, 1, bar.hovered || bar.pressed ? 0.07 : 0.0)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
}
