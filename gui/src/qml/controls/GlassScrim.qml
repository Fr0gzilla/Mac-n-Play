import QtQuick
import QtQuick.Effects

// Voile derrière les fenêtres : l'appli floutée puis assombrie, comme sous macOS
Item {
    property Item source

    MultiEffect {
        anchors.fill: parent
        source: parent.source
        visible: parent.source !== null
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: 0.15
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.0, 0.02, 0.08, 0.45)
    }
}
