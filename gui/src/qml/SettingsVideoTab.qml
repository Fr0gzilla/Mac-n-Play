// Onglet Vidéo : décodage et affichage de l'image.
// Affiché dans SettingsDialog ; les fonctions communes (dialog.…) viennent de lui.
import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Effects

import org.streetpea.chiaking

import "controls" as C

Item {
    // Video
    property alias hwDecoderComboItem: hwDecoderCombo
    property alias videoFlickItem: videoFlick
    Flickable {
        id: videoFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: (videoGrid.height * videoGrid.scale) + 10
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: videoFlick.contentHeight > videoFlick.height
        }
        GridLayout {
            id: videoGrid
            // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
            scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
            transformOrigin: Item.Top
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            columns: 3
            rowSpacing: 14
            columnSpacing: 24

            // avec 2 consoles : rappeler ce qui est propre à la console choisie
            Rectangle {
                visible: dialog.multiConsole
                Layout.columnSpan: 3
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                implicitHeight: videoTagLabel.implicitHeight + 22
                radius: 14
                color: Qt.rgba(0.24, 0.48, 1, 0.10)
                border.width: 1
                border.color: Qt.rgba(0.36, 0.56, 0.88, 0.45)
                Label {
                    id: videoTagLabel
                    anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 14
                    text: dialog.chosenConsole ? qsTr("Resolution, frame rate, bitrate and video format apply to %1 only. The other settings apply to all consoles.").arg(dialog.chosenConsole.name) : ""
                }
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Hardware Decoder:")
                font.weight: Font.Medium
                opacity: 0.92
            }

        RowLayout {
            Layout.preferredWidth: 400
            spacing: 12

            C.ComboBox {
                id: hwDecoderCombo
                Layout.preferredWidth: 220
                model: Chiaki.settings.availableDecoders
                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.decoder))
                KeyNavigation.priority: KeyNavigation.BeforeItem
                KeyNavigation.up: hwDecoderCombo
                KeyNavigation.right: zeroCopyCheck
                KeyNavigation.down: windowTypeCombo
                onActivated: (index) => Chiaki.settings.decoder = index ? model[index] : ""
            }

            Label {
                text: qsTr("Zero-Copy")
            }

            C.CheckBox {
                id: zeroCopyCheck
                KeyNavigation.priority: KeyNavigation.BeforeItem
                KeyNavigation.up: zeroCopyCheck
                KeyNavigation.left: hwDecoderCombo
                KeyNavigation.down: windowTypeCombo
                checked: Chiaki.settings.useZeroCopy
                onToggled: Chiaki.settings.useZeroCopy = checked
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Auto)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Window Type:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            id: windowTypeCombo
            Layout.preferredWidth: 400
            popup.width: 500
            model: [qsTr("Stream Resolution"), qsTr("Custom Resolution"), qsTr("Adjust Resolution Manually"), qsTr("Fullscreen"), qsTr("Zoom [adjust zoom using slider in stream menu]"), qsTr("Stretch")]
            currentIndex: Chiaki.settings.windowType
            onActivated: (index) => Chiaki.settings.windowType = index;
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Fullscreen)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("Custom Resolution Width")
            visible: Chiaki.settings.windowType == 1
        }

        C.TextField {
            id: customResolutionWidth
            Layout.preferredWidth: 400
            visible: Chiaki.settings.windowType == 1
            text: Chiaki.settings.customResolutionWidth
            Material.accent: text && !validate() ? Material.Red : undefined
            onEditingFinished: {
                if (validate()) {
                    Chiaki.settings.customResolutionWidth = parseInt(text);
                } else {
                    Chiaki.settings.customResolutionWidth = 0;
                    text = "";
                }
            }
            function validate() {
                var num = parseInt(text);
                return num >= 0 && num <= 9999;
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(1920)")
            opacity: 0.45
            font.pixelSize: 15
            visible: Chiaki.settings.windowType == 1
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("Custom Resolution Height")
            visible: Chiaki.settings.windowType == 1
        }

        C.TextField {
            id: customResolutionHeight
            Layout.preferredWidth: 400
            visible: Chiaki.settings.windowType == 1
            text: Chiaki.settings.customResolutionHeight
            Material.accent: text && !validate() ? Material.Red : undefined
            onEditingFinished: {
                if (validate()) {
                    Chiaki.settings.customResolutionHeight = parseInt(text);
                } else {
                    Chiaki.settings.customResolutionHeight = 0;
                    text = "";
                }
            }
            function validate() {
                var num = parseInt(text);
                return num >= 0 && num <= 9999;
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(1080)")
            opacity: 0.45
            font.pixelSize: 15
            visible: Chiaki.settings.windowType == 1
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Toggle Fullscreen on Double-click:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.CheckBox {
            checked: Chiaki.settings.fullscreenDoubleClick
            onToggled: Chiaki.settings.fullscreenDoubleClick = checked
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Unchecked)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("Hide Cursor during Stream")
        }
        C.CheckBox {
            checked: Chiaki.settings.hideCursor
            onToggled: Chiaki.settings.hideCursor = !Chiaki.settings.hideCursor
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Checked)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Vertical Sync:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.CheckBox {
            checked: Chiaki.settings.vSyncEnabled
            onClicked: {
                Chiaki.settings.vSyncEnabled = checked
                if (Chiaki.window.runtimeRendererBackend === 1 && Chiaki.settings.restartApplication())
                    Qt.quit()
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Unchecked)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Render Preset:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            Layout.preferredWidth: 400
            popup.width: 560
            model: [qsTr("Fast"), qsTr("Default"), qsTr("High Quality"), qsTr("High Quality + Spatial Upscaling"), qsTr("High Quality + Advanced Spatial Upscaling"), qsTr("Custom")]
            currentIndex: Chiaki.settings.videoPreset
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

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(High Quality)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Frame Delivery:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            Layout.preferredWidth: 400
            model: [qsTr("Direct Mapping"), qsTr("Frame Queue")]
            currentIndex: Chiaki.settings.directFrameMapping ? 0 : 1
            onActivated: (index) => {
                const direct = index === 0;
                if (direct === Chiaki.settings.directFrameMapping)
                    return;
                Chiaki.settings.directFrameMapping = direct;
                if (Chiaki.settings.restartApplication())
                    Qt.quit();
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Direct Mapping)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Frame Mixer:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            Layout.preferredWidth: 400
            model: [qsTr("None"), qsTr("Oversample"), qsTr("Hermite"), qsTr("Linear"), qsTr("Cubic")]
            enabled: !Chiaki.settings.directFrameMapping
            currentIndex: Chiaki.settings.directFrameMapping ? 0 : Chiaki.settings.placeboFrameMixer
            onActivated: index => Chiaki.settings.placeboFrameMixer = index
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(None)")
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Renderer Backend:")
            // sur Mac, l'appli force toujours OpenGL : ce choix ne changerait rien
            visible: Qt.platform.os !== "osx"
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            Layout.preferredWidth: 400
            model: [qsTr("Vulkan"), qsTr("OpenGL")]
            visible: Qt.platform.os !== "osx"
            currentIndex: Chiaki.settings.rendererBackend
            onActivated: (index) => {
                if (index === Chiaki.settings.rendererBackend)
                    return;
                Chiaki.settings.rendererBackend = index;
                if (Chiaki.settings.restartApplication())
                    Qt.quit();
            }
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Vulkan)")
            visible: Qt.platform.os !== "osx"
            opacity: 0.45
            font.pixelSize: 15
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Vulkan Deferred Swap:")
            font.weight: Font.Medium
            opacity: 0.92
            visible: Chiaki.settings.rendererBackend == 0
        }

        C.CheckBox {
            checked: Chiaki.settings.vulkanDeferredSwap
            onToggled: Chiaki.settings.vulkanDeferredSwap = checked
            visible: Chiaki.settings.rendererBackend == 0
        }

        Label {
            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
            Layout.preferredWidth: 230
            elide: Text.ElideRight
            text: qsTr("(Unchecked)")
            opacity: 0.45
            font.pixelSize: 15
            visible: Chiaki.settings.rendererBackend == 0
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("Custom Renderer Settings")
            visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
        }

        C.Button {
            id: customRendererSettings
            text: qsTr("Open")
            onClicked: root.showPlaceboSettingsDialog()
            Material.roundedScale: Material.SmallScale
            visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
        }

        Label { visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 360
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("Display Settings")
        }

        C.Button {
            id: displaySettings
            text: qsTr("Open")
            onClicked: root.showDisplaySettingsDialog()
            Material.roundedScale: Material.SmallScale
            lastInFocusChain: true
        }

        Label {}
        }
    }
}
