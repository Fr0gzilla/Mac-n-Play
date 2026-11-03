// Contenu du menu en jeu (L1 + R1 + L3 + R3) : son, image, qualité, retour à l'accueil.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects

import org.streetpea.chiaking

import "controls" as C

// Menu en jeu (L1 + R1 + L3 + R3 ou Ctrl+O) : un panneau en verre en bas de l'écran,
// rangé en groupes Son / Image / Rendu, avec l'état de la connexion à droite.
// Utilisé tel quel par le menu intégré (StreamView) et par la fenêtre séparée (StreamMenuWindow).
FocusScope {
    id: menu

    signal closeRequested()
    signal quitRequested()
    signal displaySettingsRequested()
    signal placeboSettingsRequested()

    property Item initialFocusItem: quitButton

    // qualité de la partie en cours (relue à chaque ouverture du menu)
    property var quality: ({})
    readonly property var qualityChoices: {
        let list = [];
        if (quality.allow1080)
            list.push({ preset: 4, text: "1080p" });
        list.push({ preset: 3, text: "720p" }, { preset: 2, text: "540p" }, { preset: 1, text: "360p" });
        return list;
    }
    onVisibleChanged: if (visible) quality = Chiaki.sessionQuality()
    Component.onCompleted: quality = Chiaki.sessionQuality()

    // ← → passent d'une commande à la suivante, dans l'ordre de la barre
    readonly property var navItems: [quitButton, volumeControl.minusButton, volumeControl.plusButton, micButton, normalButton, zoomButton, zoomControl.minusButton, zoomControl.plusButton, stretchButton, qualityCombo, renderCombo, displayButton, placeboButton]
    function moveFocus(from, step) {
        const items = navItems.filter(it => it.visible && it.enabled);
        let i = items.indexOf(from);
        if (i < 0)
            return;
        i = Math.max(0, Math.min(items.length - 1, i + step));
        items[i].forceActiveFocus(Qt.TabFocusReason);
    }
    function neighbour(from, step) {
        const items = navItems.filter(it => it.visible && it.enabled);
        const i = items.indexOf(from);
        return items[Math.max(0, Math.min(items.length - 1, i + step))];
    }

    Keys.onPressed: (event) => {
        const item = Window.activeFocusItem;
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            moveFocus(item, event.key === Qt.Key_Left ? -1 : 1);
            event.accepted = true;
        }
    }
    Keys.onMenuPressed: closeRequested()
    Keys.onEscapePressed: closeRequested()

    readonly property bool zoomMode: Chiaki.window.videoMode == ChiakiWindow.VideoMode.Zoom
    readonly property bool stretchMode: Chiaki.window.videoMode == ChiakiWindow.VideoMode.Stretch

    // ——— petites briques ———

    // pastille sélectionnable (bouton ou interrupteur)
    component MenuPill: Rectangle {
        id: pill
        property alias text: pillLabel.text
        property bool checked: false
        property color tint: "#3d7bff"
        signal activated()
        activeFocusOnTab: true
        implicitWidth: pillLabel.implicitWidth + 40
        implicitHeight: 48
        radius: height / 2
        color: checked ? Qt.rgba(tint.r, tint.g, tint.b, 0.32) : Qt.rgba(1, 1, 1, pillMouse.containsMouse ? 0.12 : 0.06)
        border.width: activeFocus ? 2 : 1
        border.color: activeFocus ? "#7fb0ff" : (checked ? Qt.rgba(tint.r, tint.g, tint.b, 0.8) : Qt.rgba(1, 1, 1, 0.16))
        opacity: enabled ? 1.0 : 0.4
        Behavior on color { ColorAnimation { duration: 120 } }
        layer.enabled: activeFocus
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#2f7dff"; shadowBlur: 0.7; shadowOpacity: 0.8; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        Label {
            id: pillLabel
            anchors.centerIn: parent
            font.pixelSize: 16
            font.weight: pill.checked ? Font.DemiBold : Font.Normal
            color: "#ffffff"
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { pill.forceActiveFocus(); pill.activated(); }
        }
        Keys.onReturnPressed: activated()
        Keys.onSpacePressed: activated()
    }

    // réglage continu (volume, zoom) : − et + de chaque côté d'une barre lumineuse
    // (← → pour aller sur − ou +, ✕ pour appuyer ; maintenir ✕ répète ; la barre se glisse aussi à la souris)
    component MenuLevel: RowLayout {
        id: level
        property real from: 0
        property real to: 1
        property real value: 0
        property real step: 0.05
        property string valueText: ""
        property string caption: ""
        property alias minusButton: minus
        property alias plusButton: plus
        signal moved(real value)
        spacing: 6
        function set(v) {
            v = Math.max(from, Math.min(to, v));
            if (v !== value)
                moved(v);
        }
        MenuPill {
            id: minus
            implicitWidth: 48
            text: "−"
            onActivated: level.set(level.value - level.step)
        }
        Rectangle {
            implicitWidth: 190
            implicitHeight: 48
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Label {
                id: levelCaption
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: level.caption
                font.pixelSize: 14
                opacity: 0.7
            }
            Rectangle {
                id: track
                anchors {
                    left: levelCaption.right
                    leftMargin: 10
                    right: levelValue.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    width: parent.width * (level.value - level.from) / (level.to - level.from)
                    height: parent.height
                    radius: 3
                    color: "#3d9bff"
                }
            }
            Label {
                id: levelValue
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                text: level.valueText
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: "#9cc2ff"
            }
            MouseArea {
                anchors.fill: track
                anchors.margins: -16
                onPressed: (mouse) => update(mouse)
                onPositionChanged: (mouse) => { if (pressed) update(mouse); }
                function update(mouse) {
                    const x = mapToItem(track, mouse.x, mouse.y).x;
                    level.set(level.from + Math.max(0, Math.min(1, x / track.width)) * (level.to - level.from));
                }
            }
        }
        MenuPill {
            id: plus
            implicitWidth: 48
            text: "+"
            onActivated: level.set(level.value + level.step)
        }
    }

    component GroupCaption: Label {
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        color: "#9cc2ff"
        opacity: 0.85
    }

    component GroupSeparator: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 74
        Layout.alignment: Qt.AlignVCenter
        color: Qt.rgba(0.6, 0.75, 1, 0.16)
    }

    // ——— le panneau ———

    Rectangle {
        id: panel
        anchors {
            fill: parent
            leftMargin: 20
            rightMargin: 20
            topMargin: 16
            bottomMargin: 20
        }
        radius: 28
        color: Qt.rgba(0.02, 0.04, 0.11, 0.94)
        border.width: 1
        border.color: Qt.rgba(0.6, 0.75, 1, 0.24)
        // dégradé bleu PlayStation venu de la gauche
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: parent.radius - 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.22, 0.6, 0.45) }
                GradientStop { position: 0.55; color: "transparent" }
            }
        }
        // reflet du verre
        Rectangle {
            anchors { fill: parent; margins: 1 }
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                GradientStop { position: 0.4; color: "transparent" }
            }
        }

        // la barre rétrécit d'un bloc si la fenêtre est trop étroite, au lieu de déborder
        RowLayout {
            readonly property real available: panel.width - 56
            anchors {
                left: parent.left
                leftMargin: 28
                verticalCenter: parent.verticalCenter
            }
            scale: Math.min(1, available / implicitWidth)
            transformOrigin: Item.Left
            width: Math.max(implicitWidth, available / scale)
            spacing: 26

            // revenir à l'interface de l'appli (la partie s'arrête)
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                GroupCaption { text: qsTr("GAME") }
                MenuPill {
                    id: quitButton
                    text: "⌂  " + qsTr("Back to Mac'n'Play")
                    tint: "#ff5c7a"
                    color: Qt.rgba(1, 0.36, 0.48, activeFocus ? 0.30 : 0.16)
                    border.color: activeFocus ? "#ff9fb1" : Qt.rgba(1, 0.36, 0.48, 0.6)
                    onActivated: menu.quitRequested()
                }
            }

            GroupSeparator { }

            // son : volume et micro
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                GroupCaption { text: qsTr("SOUND") }
                RowLayout {
                    spacing: 10
                    MenuLevel {
                        id: volumeControl
                        caption: qsTr("Volume")
                        from: 0
                        to: 128
                        step: 8
                        value: Chiaki.settings.audioVolume
                        valueText: Math.round(value / 128 * 100) + " %"
                        onMoved: (v) => Chiaki.settings.audioVolume = Math.round(v)
                    }
                    MenuPill {
                        id: micButton
                        enabled: !!Chiaki.session && Chiaki.session.connected
                        checked: !!Chiaki.session && !Chiaki.session.muted
                        tint: "#4ade80"
                        text: checked ? "🎙  " + qsTr("Mic on") : "🎙  " + qsTr("Mic off")
                        onActivated: Chiaki.session.muted = !Chiaki.session.muted
                    }
                }
            }

            GroupSeparator { }

            // image : normale, zoom (avec son niveau) ou étirée
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                GroupCaption { text: qsTr("PICTURE") }
                RowLayout {
                    spacing: 8
                    MenuPill {
                        id: normalButton
                        text: qsTr("Normal")
                        checked: !menu.zoomMode && !menu.stretchMode
                        onActivated: Chiaki.window.videoMode = ChiakiWindow.VideoMode.Normal
                    }
                    MenuPill {
                        id: zoomButton
                        text: qsTr("Zoom")
                        checked: menu.zoomMode
                        onActivated: Chiaki.window.videoMode = ChiakiWindow.VideoMode.Zoom
                    }
                    MenuLevel {
                        id: zoomControl
                        visible: menu.zoomMode
                        caption: ""
                        from: -1
                        to: 4
                        step: 0.1
                        value: Chiaki.window.ZoomFactor
                        valueText: value <= -0.995 ? qsTr("No Black Bars") : (value >= 0 ? value + 1 : value).toFixed(2) + " ×"
                        onMoved: (v) => {
                            Chiaki.window.ZoomFactor = v;
                            Chiaki.settings.sZoomFactor = v;
                        }
                    }
                    MenuPill {
                        id: stretchButton
                        text: qsTr("Stretch")
                        checked: menu.stretchMode
                        onActivated: Chiaki.window.videoMode = ChiakiWindow.VideoMode.Stretch
                    }
                }
            }

            GroupSeparator { }

            // qualité : baisser (ou remonter) la définition, la partie se reconnecte en quelques secondes
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                visible: !!Chiaki.session
                spacing: 8
                GroupCaption { text: qsTr("QUALITY") }
                C.ComboBox {
                    id: qualityCombo
                    Layout.preferredWidth: 150
                    model: menu.qualityChoices.map(q => q.text)
                    currentIndex: Math.max(0, menu.qualityChoices.findIndex(q => q.preset === menu.quality.resolution))
                    KeyNavigation.left: menu.neighbour(qualityCombo, -1)
                    KeyNavigation.right: menu.neighbour(qualityCombo, 1)
                    onActivated: (index) => {
                        const preset = menu.qualityChoices[index].preset;
                        if (preset === menu.quality.resolution)
                            return;
                        menu.closeRequested();
                        Chiaki.restartSessionWithResolution(preset);
                    }
                }
            }

            GroupSeparator { }

            // rendu : même choix que dans les Paramètres, plus les réglages d'affichage
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 8
                GroupCaption { text: qsTr("RENDERING") }
                RowLayout {
                    spacing: 8
                    C.ComboBox {
                        id: renderCombo
                        Layout.preferredWidth: 250
                        model: [qsTr("Fast"), qsTr("Default"), qsTr("High Quality"), qsTr("High Quality + sharper"), qsTr("Sharpest"), qsTr("Custom")]
                        currentIndex: Chiaki.settings.videoPreset
                        KeyNavigation.left: menu.neighbour(renderCombo, -1)
                        KeyNavigation.right: menu.neighbour(renderCombo, 1)
                        onActivated: (index) => {
                            Chiaki.settings.videoPreset = index;
                            switch (index) {
                            case 0: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Fast; break;
                            case 1: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Default; break;
                            case 2: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQuality; break;
                            case 3: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualitySpatial; break;
                            case 4: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial; break;
                            case 5: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Custom; break;
                            }
                        }
                    }
                    MenuPill {
                        id: displayButton
                        text: "⚙  " + qsTr("Display")
                        onActivated: menu.displaySettingsRequested()
                    }
                    MenuPill {
                        id: placeboButton
                        visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
                        text: qsTr("Placebo")
                        onActivated: menu.placeboSettingsRequested()
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // état de la connexion : débit, pertes, images sautées
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                visible: !!Chiaki.session
                spacing: 4
                readonly property real loss: (Chiaki.session && isFinite(Chiaki.session.averagePacketLoss)) ? Chiaki.session.averagePacketLoss * 100 : 0

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 8
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: !Chiaki.session || !Chiaki.session.connected ? "#fbbf24" : (parent.parent.loss < 2 ? "#4ade80" : "#ff6b8b")
                    }
                    Label {
                        text: !Chiaki.session ? "" : (Chiaki.session.connected ? qsTr("Connected to %1") : qsTr("Connecting to %1")).arg(Chiaki.settings.streamerMode ? qsTr("the console") : Chiaki.session.host)
                        font.pixelSize: 15
                        opacity: 0.75
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 6
                    Label {
                        text: Chiaki.session ? Chiaki.session.measuredBitrate.toFixed(1) : ""
                        font.pixelSize: 32
                        font.weight: Font.Bold
                        color: "#5aa8ff"
                    }
                    Label {
                        Layout.alignment: Qt.AlignBaseline
                        text: "Mbps"
                        font.pixelSize: 16
                        opacity: 0.7
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 14
                    Label {
                        text: qsTr("%1 % packet loss").arg(parent.parent.loss.toFixed(1))
                        font.pixelSize: 14
                        color: parent.parent.loss < 2 ? Qt.rgba(1, 1, 1, 0.6) : "#ff9fb1"
                    }
                    Label {
                        visible: Chiaki.window.droppedFrames > 0
                        text: qsTr("%1 dropped frames").arg(Chiaki.window.droppedFrames)
                        font.pixelSize: 14
                        color: "#ff9fb1"
                    }
                }
            }
        }
    }
}
