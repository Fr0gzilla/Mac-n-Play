// Onglet Configuration : profils, import/export, journal.
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
    // Config (Options such as Import/Export and Logging)
    property alias profileItem: profile
    property alias configFlickItem: configFlick
    property alias aboutButtonItem: aboutButton
    Flickable {
        id: configFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: (configGrid.y + configGrid.height * configGrid.scale) + 10
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: configFlick.contentHeight > configFlick.height
        }
        GridLayout {
            id: configGrid
            // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
            scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
            transformOrigin: Item.Top
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 30
            }
            columns: 1
            rowSpacing: 20
            columnSpacing: 24

            Label {
                text: {
                    if(Chiaki.settings.currentProfile)
                        qsTr("Current Profile: ") + Chiaki.settings.currentProfile
                    else
                        qsTr("Current Profile: default")
                }
            }

            C.Button {
                id: profile
                firstInFocusChain: true
                text: qsTr("Manage Profiles")
                onClicked: {
                    root.showProfileDialog()
                }
                Material.roundedScale: Material.SmallScale
            }

        C.Button {
            id: exportButton
            text: qsTr("Export settings to file")
            onClicked: {
                Chiaki.settings.exportSettings();
            }
            Material.roundedScale: Material.SmallScale
        }

        Label {
            text: qsTr("The exported file contains your console pairings (not your PSN account): keep it to yourself.")
            opacity: 0.6
        }

        C.Button {
            id: importButton
            text: qsTr("Import settings from file")
            onClicked: {
                Chiaki.settings.importSettings();
            }
            Material.roundedScale: Material.SmallScale
        }

        C.Button {
            id: aboutButton
            text: qsTr("About %1-ng").arg(Qt.application.name)
            onClicked: aboutDialog.open()
            Material.roundedScale: Material.SmallScale
        }

        C.CheckBox {
            text: qsTr("Sanitize Logs (checked)")
            checked: Chiaki.settings.logSanitize
            onToggled: Chiaki.settings.logSanitize = checked
        }

            C.CheckBox {
                text: qsTr("Verbose Logging (unchecked)")
                checked: Chiaki.settings.logVerbose
                onToggled: Chiaki.settings.logVerbose = checked
            }

            C.CheckBox {
                text: qsTr("Check for new versions (once a day, on GitHub)")
                checked: Chiaki.updates.enabled
                onToggled: Chiaki.updates.enabled = checked
            }

            // diagnostic : vérifie le réseau, Internet, le compte PSN et la console, et l'explique
            Label {
                Layout.topMargin: 10
                text: qsTr("Can't connect? Test what a game needs, step by step.")
                opacity: 0.6
            }
            C.Button {
                text: Chiaki.diagnostic.running ? qsTr("Testing…") : qsTr("Test my connection")
                enabled: !Chiaki.diagnostic.running
                onClicked: Chiaki.diagnostic.start()
                Material.roundedScale: Material.SmallScale
            }
            Repeater {
                model: Chiaki.diagnostic.results
                delegate: RowLayout {
                    required property var modelData
                    Layout.maximumWidth: 760
                    spacing: 12
                    Label {
                        Layout.alignment: Qt.AlignTop
                        text: modelData.status === "ok" ? "✓" : (modelData.status === "warning" ? "!" : "✕")
                        color: modelData.status === "ok" ? "#4ade80" : (modelData.status === "warning" ? "#fbbf24" : "#f87171")
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: modelData.title
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.fillWidth: true
                            text: modelData.detail
                            wrapMode: Text.WordWrap
                            opacity: 0.75
                        }
                    }
                }
            }

            // journal de l'appli : à joindre à un ticket quand quelque chose ne marche pas
            Label {
                Layout.topMargin: 10
                text: qsTr("If something goes wrong, copy the journal and paste it into your report on GitHub. The copy hides addresses, identifiers, your PSN name and console names.")
                opacity: 0.6
            }
            RowLayout {
                spacing: 12
                C.Button {
                    id: copyJournalButton
                    text: copied ? qsTr("Journal copied ✓") : qsTr("Copy the journal")
                    property bool copied: false
                    onClicked: copied = Chiaki.journal.copyToClipboard()
                    Material.roundedScale: Material.SmallScale
                }
                C.Button {
                    text: qsTr("Open the journal folder")
                    lastInFocusChain: true
                    onClicked: Chiaki.journal.openFolder()
                    Material.roundedScale: Material.SmallScale
                }
            }
        }
    }
}
