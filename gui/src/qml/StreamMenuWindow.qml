// Fenêtre séparée qui accueille le menu en jeu.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Window

import org.streetpea.chiaking

Window {
    id: streamMenuWindow

    property bool open: false
    property bool closing: false
    // gardée ouverte (vide et traversable par la souris) pendant la partie : la créer à chaque
    // appui de Ctrl+O prenait jusqu'à 2 s. Elle n'est gardée qu'après une première ouverture :
    // créée plus tôt, avant le passage du jeu en plein écran, macOS la laissait derrière lui.
    property bool alive: false
    property bool warm: false

    signal closeRequested()
    signal displaySettingsRequested()
    signal placeboSettingsRequested()
    signal mainViewRequested()
    signal closeAnimationFinished()

    visible: (alive && warm) || open || closing
    flags: Qt.Tool | Qt.FramelessWindowHint | (open || closing ? 0 : Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus)
    color: "transparent"
    modality: Qt.NonModal

    function focusInitialItem() {
        requestActivate();
        content.initialFocusItem.forceActiveFocus(Qt.TabFocusReason);
    }

    // menu fermé : le clavier reste au jeu
    onVisibleChanged: {
        if (visible && !open && transientParent)
            transientParent.requestActivate();
    }

    onActiveChanged: {
        if (active && open)
            focusTimer.restart();
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: streamMenuWindow.closeRequested()
    }

    Shortcut {
        sequence: "Ctrl+O"
        onActivated: {
            if (streamMenuWindow.open)
                streamMenuWindow.closeRequested();
        }
    }

    // la fenêtre reste en place et seul son contenu glisse : déplacer une fenêtre macOS
    // image par image saccade pendant que le jeu s'affiche en plein écran.
    // La glissade attend la première image de la fenêtre (qui prépare l'affichage et les
    // effets, et ferait sauter l'animation), au plus 200 ms.
    property bool ready: false
    property real slide: open && ready ? 0 : height
    onFrameSwapped: if (open && !ready && !readyTimer.running) readyTimer.start()
    onOpenChanged: {
        ready = false;
        if (open) {
            warm = true;
            raise();
            readyFallback.restart();
            focusTimer.restart();
        }
    }
    // le jeu change d'affichage (plein écran, fenêtre) : la fenêtre du menu sera recréée
    // par-dessus à la prochaine ouverture
    Connections {
        target: streamMenuWindow.transientParent
        function onVisibilityChanged() {
            if (!streamMenuWindow.open && !streamMenuWindow.closing)
                streamMenuWindow.warm = false;
        }
    }

    Timer {
        id: readyTimer
        interval: 16
        onTriggered: streamMenuWindow.ready = streamMenuWindow.open
    }
    Timer {
        id: readyFallback
        interval: 200
        onTriggered: streamMenuWindow.ready = streamMenuWindow.open
    }
    Behavior on slide {
        NumberAnimation {
            id: menuAnimation
            duration: 250
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (!running && !streamMenuWindow.open)
                    streamMenuWindow.closeAnimationFinished();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: 0
        repeat: false
        onTriggered: {
            if (streamMenuWindow.open)
                streamMenuWindow.focusInitialItem();
        }
    }

    StreamMenuContent {
        id: content
        y: streamMenuWindow.slide
        width: parent.width
        height: parent.height
        focus: true
        onCloseRequested: streamMenuWindow.closeRequested()
        onQuitRequested: {
            if (Chiaki.session)
                Chiaki.window.close();
            else
                streamMenuWindow.mainViewRequested();
        }
        onDisplaySettingsRequested: streamMenuWindow.displaySettingsRequested()
        onPlaceboSettingsRequested: streamMenuWindow.placeboSettingsRequested()
    }
}
