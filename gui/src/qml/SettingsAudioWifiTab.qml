// Onglet Son et Wi-Fi.
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
    // Audio and Wifi
    property alias audioOutDeviceItem: audioOutDevice
    property alias audiowifiFlickItem: audiowifiFlick
    Flickable {
        id: audiowifiFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: (audiowifigrid.height * audiowifigrid.scale) + 10
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            id: audiowifiScrollbar
            policy: ScrollBar.AsNeeded
            visible: audiowifiFlick.contentHeight > audiowifiFlick.height
        }
        GridLayout {
            id: audiowifigrid
            // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
            scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
            transformOrigin: Item.Top
            columns: 3
            rowSpacing: 14
            columnSpacing: 24
            onVisibleChanged: if (visible) Chiaki.settings.refreshAudioDevices()

            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            Label {
                Layout.columnSpan: 3
                Layout.topMargin: 12
                text: qsTr("SOUND")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                color: "#9cc2ff"
            }
            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Output Device:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.ComboBox {
                id: audioOutDevice
                Layout.preferredWidth: 400
                popup.x: (width - popup.width) / 2
                popup.width: 700
                popup.font.pixelSize: 16
                firstInFocusChain: true
                model: [qsTr("Auto")].concat(Chiaki.settings.availableAudioOutDevices)
                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioOutDevice))
                onActivated: (index) => Chiaki.settings.audioOutDevice = index ? model[index] : ""
                KeyNavigation.down: audioInDevice
                KeyNavigation.priority: popup.visible ? KeyNavigation.AfterItem : KeyNavigation.BeforeItem
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
                text: qsTr("Input Device:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.ComboBox {
                id: audioInDevice
                Layout.preferredWidth: 400
                popup.x: (width - popup.width) / 2
                popup.width: 700
                popup.font.pixelSize: 16
                model: [qsTr("Auto")].concat(Chiaki.settings.availableAudioInDevices)
                currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioInDevice))
                onActivated: (index) => Chiaki.settings.audioInDevice = index ? model[index] : ""
                KeyNavigation.up: audioOutDevice
                KeyNavigation.down: audioBufferSizeSlider
                KeyNavigation.priority: popup.visible ? KeyNavigation.AfterItem : KeyNavigation.BeforeItem
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
                text: qsTr("Audio Buffer Size:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.Slider {
                id: audioBufferSizeSlider
                Layout.preferredWidth: 250
                from: 1
                to: 10
                stepSize: 1
                value: Chiaki.settings.audioBufferSize / 1920 ? (Chiaki.settings.audioBufferSize / 1920) : 5
                onMoved: Chiaki.settings.audioBufferSize = value * 1920;
                KeyNavigation.up: audioInDevice

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: {
                        (parent.value * 10).toFixed(0) + qsTr(" ms")
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(50 ms)")
                opacity: 0.45
                font.pixelSize: 15
            }
            Label {
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("Sound memory before playback. Bigger avoids crackling on a weak network but adds a little delay.")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Audio Volume:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.Slider {
                Layout.preferredWidth: 250
                from: 0
                to: 128
                stepSize: 1
                value: Chiaki.settings.audioVolume
                onMoved: Chiaki.settings.audioVolume = value

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: {
                        ((parent.value / 128.0) * 100).toFixed(0) + qsTr("% volume")
                    }
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(100%)")
                opacity: 0.45
                font.pixelSize: 15
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Start Mic Unmuted:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.CheckBox {
                checked: Chiaki.settings.startMicUnmuted
                onToggled: Chiaki.settings.startMicUnmuted = checked
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
                text: qsTr("Speech Processing:")
                font.weight: Font.Medium
                opacity: 0.92
                visible: typeof Chiaki.settings.speechProcessing !== "undefined"
            }

            C.CheckBox {
                text: qsTr("Noise suppression + echo cancellation")
                checked: Chiaki.settings.speechProcessing
                onToggled: Chiaki.settings.speechProcessing = !Chiaki.settings.speechProcessing
                visible: typeof Chiaki.settings.speechProcessing !== "undefined"
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Unchecked)")
                opacity: 0.45
                font.pixelSize: 15
                visible: typeof Chiaki.settings.speechProcessing !== "undefined"
            }
            Label {
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {true} else {false}
                text: qsTr("Cleans up your voice on the microphone: removes background noise and echo.")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Noise To Suppress:")
                font.weight: Font.Medium
                opacity: 0.92
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
            }

            C.Slider {
                Layout.preferredWidth: 250
                from: 0
                to: 60
                stepSize: 1
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                value: Chiaki.settings.noiseSuppressLevel
                onMoved: Chiaki.settings.noiseSuppressLevel = value

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: qsTr("%1 dB").arg(parent.value)
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(6 dB)")
                opacity: 0.45
                font.pixelSize: 15
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Echo To Suppress:")
                font.weight: Font.Medium
                opacity: 0.92
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
            }

            C.Slider {
                Layout.preferredWidth: 250
                from: 0
                to: 60
                stepSize: 1
                value: Chiaki.settings.echoSuppressLevel
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                onMoved: Chiaki.settings.echoSuppressLevel = value

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: qsTr("%1 dB").arg(parent.value)
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(30 dB)")
                opacity: 0.45
                font.pixelSize: 15
                visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
            }

            Label {
                Layout.columnSpan: 3
                Layout.topMargin: 12
                text: qsTr("WI-FI AND NETWORK")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                color: "#9cc2ff"
            }
            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Weak Wifi Notification:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.Slider {
                Layout.preferredWidth: 250
                from: 0
                to: 100
                stepSize: 1
                value: Chiaki.settings.wifiDroppedNotif
                onMoved: Chiaki.settings.wifiDroppedNotif = value

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: qsTr(">= %1% dropped packets").arg(parent.value)
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(3%)")
                opacity: 0.45
                font.pixelSize: 15
            }
            Label {
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("Shows a warning during the game when too many images are lost on the way.")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Packet Loss Reported Max:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.Slider {
                Layout.preferredWidth: 250
                from: 0
                to: 100
                stepSize: 1
                value: Chiaki.settings.packetLossReportedMax
                onMoved: Chiaki.settings.packetLossReportedMax = value

                Label {
                    anchors {
                        left: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10
                    }
                    text: qsTr("%1% packet loss").arg(parent.value)
                }
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(5%)")
                opacity: 0.45
                font.pixelSize: 15
            }
            Label {
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("Caps the losses reported to the console. Lower keeps the picture quality; higher lets the console lower quality faster to stay smooth.")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                font.weight: Font.Medium
                opacity: 0.92
                text: qsTr("Request IDR Frame on FEC Failure")
            }

            C.CheckBox {
                checked: Chiaki.settings.iDROnFECFailureEnabled
                onToggled: Chiaki.settings.iDROnFECFailureEnabled = !Chiaki.settings.iDROnFECFailureEnabled
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
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("When the picture gets corrupted, asks the console for a complete new image to fix it quickly.")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                font.weight: Font.Medium
                opacity: 0.92
                text: qsTr("Show Stream Stats During Gameplay")
            }

            C.CheckBox {
                lastInFocusChain: true
                checked: Chiaki.settings.showStreamStats
                onToggled: Chiaki.settings.showStreamStats = !Chiaki.settings.showStreamStats
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
                Layout.columnSpan: 3
                Layout.leftMargin: 384
                Layout.preferredWidth: 654
                Layout.topMargin: -6
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                text: qsTr("Shows bitrate, losses and delay in a corner of the screen while playing.")
            }
        }
    }
}
