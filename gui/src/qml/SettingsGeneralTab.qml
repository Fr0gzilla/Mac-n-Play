// Onglet Général : langue, fenêtre, fin de partie, menu en jeu.
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
    // General
    property alias firstFocusItem: languageChoice
    property alias generalFlickItem: generalFlick
    Flickable {
        id: generalFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: (generalLayout.height * generalLayout.scale) + 10
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: generalFlick.contentHeight > generalFlick.height
        }
        ColumnLayout {
            id: generalLayout
            // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
            scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
            transformOrigin: Item.Top
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 10
            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                rowSpacing: 14
                columnSpacing: 24

                Label {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 360
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    text: qsTr("Language:")
                    font.weight: Font.Medium
                    opacity: 0.92
                }

            C.ComboBox {
                id: languageChoice
                // codes connus de AppTranslator ; vide : suivre la langue du Mac
                readonly property var codes: ["", "en", "fr", "de", "es", "it", "pt"]
                Layout.preferredWidth: 400
                firstInFocusChain: true
                // chaque langue écrite dans sa propre langue, pour la retrouver même sans la lire
                model: [qsTr("Same as the Mac"), "English", "Français", "Deutsch", "Español", "Italiano", "Português"]
                currentIndex: Math.max(0, codes.indexOf(Chiaki.settings.language))
                onActivated: index => Chiaki.settings.language = codes[index]
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Same as the Mac)")
                opacity: 0.45
                font.pixelSize: 15
            }

                Label {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 360
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    text: qsTr("Action On Disconnect:")
                    font.weight: Font.Medium
                    opacity: 0.92
                }

            C.ComboBox {
                id: disconnectAction
                Layout.preferredWidth: 400
                model: [qsTr("Do Nothing"), qsTr("Enter Sleep Mode"), qsTr("Ask")]
                currentIndex: Chiaki.settings.disconnectAction
                onActivated: index => Chiaki.settings.disconnectAction = index
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Ask)")
                opacity: 0.45
                font.pixelSize: 15
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Action On Suspend:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.ComboBox {
                Layout.preferredWidth: 400
                model: [qsTr("Do Nothing"), qsTr("Enter Sleep Mode")]
                currentIndex: Chiaki.settings.suspendAction
                onActivated: index => Chiaki.settings.suspendAction = index
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Do Nothing)")
                opacity: 0.45
                font.pixelSize: 15
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Steam Deck Haptics:")
                font.weight: Font.Medium
                opacity: 0.92
                visible: (typeof Chiaki.settings.steamDeckHaptics !== "undefined")
            }

            C.CheckBox {
                text: qsTr("True haptics for SteamDeck, better quality but noisier")
                checked: {
                    if(typeof Chiaki.settings.steamDeckHaptics !== "undefined")
                        Chiaki.settings.steamDeckHaptics
                    else
                        false
                }
                onToggled: Chiaki.settings.steamDeckHaptics = checked
                visible: (typeof Chiaki.settings.steamDeckHaptics !== "undefined")
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Unchecked)")
                opacity: 0.45
                font.pixelSize: 15
                visible: (typeof Chiaki.settings.steamDeckHaptics !== "undefined")
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Steam Deck Vertical:")
                font.weight: Font.Medium
                opacity: 0.92
                visible: typeof Chiaki.settings.verticalDeck !== "undefined"
            }

            C.CheckBox {
                text: qsTr("Use Steam Deck in vertical orientation (motion controls)")
                checked: {
                    if(typeof Chiaki.settings.verticalDeck !== "undefined")
                        Chiaki.settings.verticalDeck
                    else
                        false
                }
                onToggled: Chiaki.settings.verticalDeck = checked
                visible: typeof Chiaki.settings.verticalDeck !== "undefined"
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Unchecked)")
                opacity: 0.45
                font.pixelSize: 15
                visible: typeof Chiaki.settings.verticalDeck !== "undefined"
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Audio/Video:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            C.ComboBox {
                Layout.preferredWidth: 400
                model: [qsTr("Audio and Video Enabled"), qsTr("Audio Disabled"), qsTr("Video Disabled"), qsTr("Audio and Video Disabled")]
                currentIndex: Chiaki.settings.audioVideoDisabled
                onActivated: index => Chiaki.settings.audioVideoDisabled = index
            }

            Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Audio and Video Enabled)")
                opacity: 0.45
                font.pixelSize: 15
            }

            Label {
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                text: qsTr("Log Directory:")
                font.weight: Font.Medium
                opacity: 0.92
            }

            RowLayout {
                Layout.preferredWidth: 400
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    text: Chiaki.settings.logDirectory
                    elide: Text.ElideMiddle
                    opacity: 0.7
                    font.pixelSize: 15
                }
                C.Button {
                    id: openButton
                    text: qsTr("Open")
                    onClicked: Qt.openUrlExternally("file://" + Chiaki.settings.logDirectory);
                }
            }
            Label {

            }
            Label {
                visible: false // retiré de Mac'n'Play
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                font.weight: Font.Medium
                opacity: 0.92
                text: qsTr("Streamer Mode (Hides Info)")
            }
            C.CheckBox {
                visible: false // retiré de Mac'n'Play
                id: streamerMode
                checked: Chiaki.settings.streamerMode
                onToggled: Chiaki.settings.streamerMode = !Chiaki.settings.streamerMode
            }

            Label {
                visible: false // retiré de Mac'n'Play
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.preferredWidth: 230
                elide: Text.ElideRight
                text: qsTr("(Unchecked)")
                opacity: 0.45
                font.pixelSize: 15
            }

            Label {
                visible: false // retiré de Mac'n'Play
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.preferredWidth: 360
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.WordWrap
                font.weight: Font.Medium
                opacity: 0.92
                text: qsTr("Stream Menu Shortcut Enabled")
            }
            C.CheckBox {
                visible: false // retiré de Mac'n'Play
                id: streamMenu
                checked: Chiaki.settings.streamMenuEnabled
                onToggled: Chiaki.settings.streamMenuEnabled = !Chiaki.settings.streamMenuEnabled
                KeyNavigation.priority: KeyNavigation.BeforeItem
                KeyNavigation.up: streamerMode
                KeyNavigation.left: streamMenu
                KeyNavigation.right: streamMenu
                KeyNavigation.down: {
                    if(streamMenuShortcut1.visible)
                        streamMenuShortcut1
                    else
                        streamMenu
                }
            }

                Label {
                    visible: false // retiré de Mac'n'Play
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.preferredWidth: 230
                    elide: Text.ElideRight
                    text: qsTr("(Checked)")
                    opacity: 0.45
                    font.pixelSize: 15
                }
            }
            RowLayout {
                visible: false // retiré de Mac'n'Play
                spacing: 24
                Layout.alignment: Qt.AlignHCenter
                Label {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredWidth: 360
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap
                    text: qsTr("Stream Menu Combo:")
                    font.weight: Font.Medium
                    opacity: 0.92
                }

            RowLayout {
                Layout.preferredWidth: 400
                spacing: 6
            C.ComboBox {
                id: streamMenuShortcut1
                Layout.fillWidth: true
                Layout.preferredWidth: 95
                implicitContentWidthPolicy: ComboBox.ContentItemImplicitWidth
                firstInFocusChain: false
                model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                currentIndex: Chiaki.settings.streamMenuShortcut1
                onActivated: index => Chiaki.settings.streamMenuShortcut1 = index
                KeyNavigation.priority: {
                    if(!popup.visible)
                        KeyNavigation.BeforeItem
                    else
                        KeyNavigation.AfterItem
                }
                KeyNavigation.up: streamMenu
                KeyNavigation.down: streamMenuShortcut1
                KeyNavigation.left: streamMenuShortcut1
                KeyNavigation.right: streamMenuShortcut2
            }

            C.ComboBox {
                id: streamMenuShortcut2
                Layout.fillWidth: true
                Layout.preferredWidth: 95
                implicitContentWidthPolicy: ComboBox.ContentItemImplicitWidth
                firstInFocusChain: false
                model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                currentIndex: Chiaki.settings.streamMenuShortcut2
                onActivated: index => Chiaki.settings.streamMenuShortcut2 = index
                KeyNavigation.priority: {
                    if(!popup.visible)
                        KeyNavigation.BeforeItem
                    else
                        KeyNavigation.AfterItem
                }
                KeyNavigation.up: streamMenu
                KeyNavigation.down: streamMenuShortcut2
                KeyNavigation.left: streamMenuShortcut1
                KeyNavigation.right: streamMenuShortcut3
            }

            C.ComboBox {
                id: streamMenuShortcut3
                Layout.fillWidth: true
                Layout.preferredWidth: 95
                implicitContentWidthPolicy: ComboBox.ContentItemImplicitWidth
                firstInFocusChain: false
                model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                currentIndex: Chiaki.settings.streamMenuShortcut3
                onActivated: index => Chiaki.settings.streamMenuShortcut3 = index
                KeyNavigation.priority: {
                    if(!popup.visible)
                        KeyNavigation.BeforeItem
                    else
                        KeyNavigation.AfterItem
                }
                KeyNavigation.up: streamMenu
                KeyNavigation.down: streamMenuShortcut3
                KeyNavigation.left: streamMenuShortcut2
                KeyNavigation.right: streamMenuShortcut4
            }

            C.ComboBox {
                id: streamMenuShortcut4
                Layout.fillWidth: true
                Layout.preferredWidth: 95
                implicitContentWidthPolicy: ComboBox.ContentItemImplicitWidth
                firstInFocusChain: false
                model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                currentIndex: Chiaki.settings.streamMenuShortcut4
                onActivated: index => Chiaki.settings.streamMenuShortcut4 = index
                KeyNavigation.priority: {
                    if(!popup.visible)
                        KeyNavigation.BeforeItem
                    else
                        KeyNavigation.AfterItem
                }
                KeyNavigation.up: streamMenu
                KeyNavigation.down: streamMenuShortcut4
                KeyNavigation.left: streamMenuShortcut3
                KeyNavigation.right: streamMenuShortcut4
            }
            }

                Label {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    Layout.preferredWidth: 230
                    elide: Text.ElideRight
                    text: qsTr("(L1+R1+L3+R3)")
                    opacity: 0.45
                    font.pixelSize: 15
                }
            }
        }
    }
}
