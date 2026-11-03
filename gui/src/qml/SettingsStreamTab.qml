// Onglet Partie : qualité, fluidité et débit par console.
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
    // Stream
    property alias consoleSelectionItem: consoleSelection
    property alias streamFlickItem: streamFlick
    Flickable {
        id: streamFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: (streamGrid.height * streamGrid.scale) + 10
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: streamFlick.contentHeight > streamFlick.height
        }
        GridLayout {
            id: streamGrid
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

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 180
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Settings for:")
                font.weight: Font.Medium
                opacity: 0.92
            }


        C.ComboBox {
            id: consoleSelection
            Layout.preferredWidth: 400
            Layout.alignment: Qt.AlignLeft
            model: [qsTr("PS4"), qsTr("PS5")]
            currentIndex: selectedConsole
            onActivated: (index) => selectedConsole = index
            firstInFocusChain: true
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
            KeyNavigation.down: {
                if(selectedConsole == SettingsDialog.Console.PS4)
                    resolutionLocalPS4
                else
                    resolutionLocalPS5

            }

        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("")
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("")
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("")
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("")
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            font.weight: Font.Medium
            opacity: 0.92
            text: qsTr("")
        }

        Label {
            Layout.alignment: Qt.AlignCenter
            text: qsTr("Local")
        }

        Label {
            Layout.alignment: Qt.AlignCenter
            text: qsTr("Remote")
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Resolution:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            id: resolutionLocalPS4
            Layout.preferredWidth: 400
            model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p (PS5 and PS4 Pro)")]
            currentIndex: Chiaki.settings.resolutionLocalPS4 - 1
            onActivated: (index) => {
                Chiaki.settings.resolutionLocalPS4 = index + 1
                Chiaki.settings.bitrateLocalPS4 = 0
            }
            visible: selectedConsole == SettingsDialog.Console.PS4
            KeyNavigation.right: resolutionRemotePS4
            KeyNavigation.down: fpsLocalPS4
            KeyNavigation.up: consoleSelection
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: resolutionRemotePS4
            Layout.preferredWidth: 400
            model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p (PS5 and PS4 Pro)")]
            currentIndex: Chiaki.settings.resolutionRemotePS4 - 1
            onActivated: (index) => {
                Chiaki.settings.resolutionRemotePS4 = index + 1
                Chiaki.settings.bitrateRemotePS4 = 0
            }
            visible: selectedConsole == SettingsDialog.Console.PS4
            KeyNavigation.left: resolutionLocalPS4
            KeyNavigation.down: fpsRemotePS4
            KeyNavigation.up: consoleSelection
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: resolutionLocalPS5
            Layout.preferredWidth: 400
            model: [qsTr("360p"), qsTr("540p"), qsTr("720p"), qsTr("1080p (Default)")]
            currentIndex: Chiaki.settings.resolutionLocalPS5 - 1
            onActivated: (index) => {
                Chiaki.settings.resolutionLocalPS5 = index + 1
                Chiaki.settings.bitrateLocalPS5 = 0
            }
            visible: selectedConsole == SettingsDialog.Console.PS5
            KeyNavigation.right: resolutionRemotePS5
            KeyNavigation.up: consoleSelection
            KeyNavigation.down: fpsLocalPS5
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: resolutionRemotePS5
            Layout.preferredWidth: 400
            model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p")]
            currentIndex: Chiaki.settings.resolutionRemotePS5 - 1
            onActivated: (index) => {
                Chiaki.settings.resolutionRemotePS5 = index + 1
                Chiaki.settings.bitrateRemotePS5 = 0
            }
            visible: selectedConsole == SettingsDialog.Console.PS5
            KeyNavigation.left: resolutionLocalPS5
            KeyNavigation.up: consoleSelection
            KeyNavigation.down: fpsRemotePS5
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("FPS:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.ComboBox {
            id: fpsLocalPS4
            Layout.preferredWidth: 400
            model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
            currentIndex: (Chiaki.settings.fpsLocalPS4 / 30) - 1
            onActivated: (index) => Chiaki.settings.fpsLocalPS4 = (index + 1) * 30
            visible: selectedConsole == SettingsDialog.Console.PS4
            KeyNavigation.up: resolutionLocalPS4
            KeyNavigation.right: fpsRemotePS4
            KeyNavigation.down: bitrateLocalPS4
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: fpsRemotePS4
            Layout.preferredWidth: 400
            model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
            currentIndex: (Chiaki.settings.fpsRemotePS4 / 30) - 1
            onActivated: (index) => Chiaki.settings.fpsRemotePS4 = (index + 1) * 30
            visible: selectedConsole == SettingsDialog.Console.PS4
            KeyNavigation.up: resolutionRemotePS4
            KeyNavigation.left: fpsLocalPS4
            KeyNavigation.down: bitrateRemotePS4
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: fpsLocalPS5
            Layout.preferredWidth: 400
            model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
            currentIndex: (Chiaki.settings.fpsLocalPS5 / 30) - 1
            onActivated: (index) => Chiaki.settings.fpsLocalPS5 = (index + 1) * 30
            visible: selectedConsole == SettingsDialog.Console.PS5
            KeyNavigation.up: resolutionLocalPS5
            KeyNavigation.right: fpsRemotePS5
            KeyNavigation.down: bitrateLocalPS5
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        C.ComboBox {
            id: fpsRemotePS5
            Layout.preferredWidth: 400
            model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
            currentIndex: (Chiaki.settings.fpsRemotePS5 / 30) - 1
            onActivated: (index) => Chiaki.settings.fpsRemotePS5 = (index + 1) * 30
            visible: selectedConsole == SettingsDialog.Console.PS5
            KeyNavigation.up: resolutionRemotePS5
            KeyNavigation.left: fpsLocalPS5
            KeyNavigation.down: bitrateRemotePS5
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Bitrate:")
            font.weight: Font.Medium
            opacity: 0.92
        }

        C.Slider {
            id: bitrateLocalPS4
            visible: selectedConsole == SettingsDialog.Console.PS4
            property var bitrate: {
                var rate = 0;
                switch (Chiaki.settings.resolutionLocalPS4) {
                case 1: rate = 2; break; // 360p
                case 2: rate = 6; break; // 540p
                case 3: rate = 10; break; // 720p
                case 4: rate = 15; break; // 1080p
                }
                return rate;
            }
            Layout.preferredWidth: 200
            from: 2
            to: 100
            stepSize: 1
            value: Chiaki.settings.bitrateLocalPS4 / 1000 ? (Chiaki.settings.bitrateLocalPS4 / 1000) : bitrate
            onMoved: Chiaki.settings.bitrateLocalPS4 = value * 1000;
            KeyNavigation.up: fpsLocalPS4
            KeyNavigation.down: bitrateLocalPS4
            KeyNavigation.priority: KeyNavigation.BeforeItem
            Label {
                anchors {
                    left: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                }
                text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
            }
        }

        C.Slider {
            id: bitrateRemotePS4
            visible: selectedConsole == SettingsDialog.Console.PS4
            property var bitrate: {
                var rate = 0;
                switch (Chiaki.settings.resolutionRemotePS4) {
                case 1: rate = 2; break; // 360p
                case 2: rate = 6; break; // 540p
                case 3: rate = 10; break; // 720p
                case 4: rate = 15; break; // 1080p
                }
                return rate;
            }
            Layout.preferredWidth: 200
            from: 2
            to: 100
            stepSize: 1
            value: Chiaki.settings.bitrateRemotePS4 / 1000 ? (Chiaki.settings.bitrateRemotePS4 / 1000) : bitrate
            onMoved: Chiaki.settings.bitrateRemotePS4 = value * 1000;
            KeyNavigation.up: fpsRemotePS4
            KeyNavigation.down: bitrateRemotePS4
            KeyNavigation.priority: KeyNavigation.BeforeItem
            lastInFocusChain: true

            Label {
                anchors {
                    left: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                }
                text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
            }
        }

        C.Slider {
            id: bitrateLocalPS5
            visible: selectedConsole == SettingsDialog.Console.PS5
            property var bitrate: {
                var rate = 0;
                switch (Chiaki.settings.resolutionLocalPS5) {
                case 1: rate = 2; break; // 360p
                case 2: rate = 6; break; // 540p
                case 3: rate = 10; break; // 720p
                case 4: rate = 15; break; // 1080p
                }
                return rate;
            }
            Layout.preferredWidth: 200
            from: 2
            to: 100
            stepSize: 1
            value: Chiaki.settings.bitrateLocalPS5 / 1000 ? (Chiaki.settings.bitrateLocalPS5 / 1000) : bitrate
            onMoved: Chiaki.settings.bitrateLocalPS5 = value * 1000;
            KeyNavigation.up: fpsLocalPS5
            KeyNavigation.down: codecLocalPS5
            KeyNavigation.priority: KeyNavigation.BeforeItem

            Label {
                anchors {
                    left: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                }
                text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
            }
        }

        C.Slider {
            id: bitrateRemotePS5
            visible: selectedConsole == SettingsDialog.Console.PS5
            property var bitrate: {
                var rate = 0;
                switch (Chiaki.settings.resolutionRemotePS5) {
                case 1: rate = 2; break; // 360p
                case 2: rate = 6; break; // 540p
                case 3: rate = 10; break; // 720p
                case 4: rate = 15; break; // 1080p
                }
                return rate;
            }
            Layout.preferredWidth: 200
            from: 2
            to: 100
            stepSize: 1
            value: Chiaki.settings.bitrateRemotePS5 / 1000 ? (Chiaki.settings.bitrateRemotePS5 / 1000) : bitrate
            onMoved: Chiaki.settings.bitrateRemotePS5 = value * 1000;
            KeyNavigation.up: fpsRemotePS5
            KeyNavigation.down: codecRemotePS5
            KeyNavigation.priority: KeyNavigation.BeforeItem
            lastInFocusChain: true

            Label {
                anchors {
                    left: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 10
                }
                text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
            }
        }

        Label {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            Layout.preferredWidth: 180
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.WordWrap
            text: qsTr("Codec:")
            font.weight: Font.Medium
            opacity: 0.92
            visible: selectedConsole == SettingsDialog.Console.PS5
        }

        C.ComboBox {
            id: codecLocalPS5
            Layout.preferredWidth: 400
            property bool openGlBackend: Chiaki.settings.rendererBackend === 1
model: openGlBackend ? [qsTr("H264"), qsTr("H265 (Default)")] : [qsTr("H264"), qsTr("H265 (Default)"), qsTr("H265 HDR")]
            currentIndex: Chiaki.settings.codecLocalPS5
            onActivated: (index) => Chiaki.settings.codecLocalPS5 = index
            visible: selectedConsole == SettingsDialog.Console.PS5
            Keys.onReturnPressed: {
                if (popup.visible) {
                    activated(highlightedIndex);
                    popup.close();
                } else
                    popup.open();
            }
            KeyNavigation.up: bitrateLocalPS5
            KeyNavigation.right: codecRemotePS5
            KeyNavigation.down: codecLocalPS5
            KeyNavigation.priority: {
                if(!popup.visible)
                    KeyNavigation.BeforeItem
                else
                    KeyNavigation.AfterItem
            }
        }

            C.ComboBox {
                id: codecRemotePS5
                Layout.preferredWidth: 400
            property bool openGlBackend: Chiaki.settings.rendererBackend === 1
            model: openGlBackend ? [qsTr("H264"), qsTr("H265 (Default)")] : [qsTr("H264"), qsTr("H265 (Default)"), qsTr("H265 HDR")]
                currentIndex: Chiaki.settings.codecRemotePS5
                onActivated: (index) => Chiaki.settings.codecRemotePS5 = index
                visible: selectedConsole == SettingsDialog.Console.PS5
                lastInFocusChain: true
                Keys.onReturnPressed: {
                    if (popup.visible) {
                        activated(highlightedIndex);
                        popup.close();
                    } else
                        popup.open();
                }
                KeyNavigation.up: bitrateRemotePS5
                KeyNavigation.left: codecLocalPS5
                KeyNavigation.priority: {
                    if(!popup.visible)
                        KeyNavigation.BeforeItem
                    else
                        KeyNavigation.AfterItem
                }
            }

            // petite légende sous le codec, alignée sous les deux menus
            Label {
                Layout.columnSpan: 3
                Layout.leftMargin: 180 + 24
                Layout.preferredWidth: 824
                Layout.topMargin: -4
                visible: selectedConsole == SettingsDialog.Console.PS5
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("The codec is how the console compresses the picture before sending it. H265 gives a better picture for the same bitrate; H264 is lighter for the Mac and can lower the delay slightly.")
            }
        }
    }
}
