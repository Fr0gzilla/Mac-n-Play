// Onglet Consoles : consoles associées, ajout, réaffichage.
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
    // Consoles
    property alias registerNewButtonItem: registerNewButton
    property alias consolesFlickItem: consolesFlick
    Flickable {
        id: consolesFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: consolesLayout.height + 20
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: consolesFlick.contentHeight > consolesFlick.height
        }
        ColumnLayout {
            id: consolesLayout
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(consolesFlick.width - 80, 1000)
            spacing: 12

            // flèches : vers l'élément le plus proche dans la direction (comme la page Touches)
            function nav(from, key) {
                const best = keysFlick.moveFocusIn(consolesLayout, from, key);
                if (best)
                    dialog.ensureItemVisibleInFlick(consolesFlick, best);
            }
            function prettyMac(mac) {
                return Chiaki.settings.streamerMode ? "" : (mac || "").replace(/(..)(?!$)/g, "$1:").toUpperCase();
            }

            Label {
                Layout.topMargin: 14
                text: qsTr("YOUR CONSOLES")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                color: "#9cc2ff"
            }

            // une carte par console associée : image, nom, puis connexion auto et suppression
            Repeater {
                model: Chiaki.settings.registeredHosts
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 104
                    radius: 18
                    color: Qt.rgba(0.35, 0.55, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(0.6, 0.75, 1, 0.16)

                    RowLayout {
                        anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                        spacing: 22

                        Image {
                            Layout.preferredWidth: modelData.ps5 ? 40 : 110
                            Layout.preferredHeight: modelData.ps5 ? 80 : 55
                            Layout.leftMargin: modelData.ps5 ? 35 : 0
                            Layout.rightMargin: modelData.ps5 ? 35 : 0
                            fillMode: Image.PreserveAspectFit
                            source: "image://svg/console-ps" + (modelData.ps5 ? "5" : "4") + "#light_on"
                            sourceSize: Qt.size(220, 110)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                text: modelData.name
                                font.pixelSize: 19
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: (modelData.ps5 ? "PS5" : "PS4") + (Chiaki.settings.streamerMode ? "" : "  ·  " + consolesLayout.prettyMac(modelData.mac))
                                font.pixelSize: 14
                                opacity: 0.55
                            }
                        }

                        C.CheckBox {
                            property bool keysNav: true
                            firstInFocusChain: false
                            navHandler: consolesLayout.nav
                            text: qsTr("Auto-Connect")
                            checked: Chiaki.settings.autoConnectMac == modelData.mac
                            onToggled: Chiaki.settings.autoConnectMac = checked ? modelData.mac : ""
                        }

                        C.Button {
                            property bool keysNav: true
                            navHandler: consolesLayout.nav
                            text: qsTr("Delete")
                            Material.accent: "#ff5c7a"
                            onClicked: root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"), () => Chiaki.settings.deleteRegisteredHost(index))
                        }
                    }
                }
            }

            Label {
                visible: Chiaki.settings.registeredHosts.length === 0
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("No console registered yet.")
                font.pixelSize: 16
                opacity: 0.55
            }

            // associer une nouvelle console : grand bouton centré
            C.Button {
                id: registerNewButton
                property bool keysNav: true
                navHandler: consolesLayout.nav
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                topPadding: 18
                bottomPadding: 18
                leftPadding: 34
                rightPadding: 34
                firstInFocusChain: true
                text: "+  " + qsTr("Register New")
                onClicked: root.showRegistDialog(Chiaki.consoles.broadcastAddress, true)
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("%1 / %2 consoles · %2 at most").arg(Chiaki.consoles.registeredCount).arg(Chiaki.consoles.maxConsoles)
                font.pixelSize: 14
                color: Chiaki.consoles.limitReached ? "#fbbf24" : Qt.rgba(1, 1, 1, 0.5)
            }

            Label {
                Layout.topMargin: 22
                text: qsTr("HIDDEN CONSOLES")
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2
                color: "#9cc2ff"
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("Consoles you hid from the home screen. Unhide one to see it again.")
                font.pixelSize: 14
                opacity: 0.55
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: Chiaki.consoles.hidden
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 76
                    radius: 18
                    color: Qt.rgba(0.35, 0.55, 1, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(0.6, 0.75, 1, 0.16)

                    RowLayout {
                        anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
                        spacing: 22
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: modelData.name
                                font.pixelSize: 17
                                font.weight: Font.Medium
                            }
                            Label {
                                visible: !Chiaki.settings.streamerMode
                                text: consolesLayout.prettyMac(modelData.mac)
                                font.pixelSize: 13
                                opacity: 0.5
                            }
                        }
                        C.Button {
                            property bool keysNav: true
                            navHandler: consolesLayout.nav
                            text: qsTr("Unhide")
                            onClicked: root.showConfirmDialog(qsTr("Unhide Console"), qsTr("Are you sure you want to unhide this console?"), () => Chiaki.consoles.unhide(modelData.mac))
                        }
                    }
                }
            }

            Rectangle {
                visible: Chiaki.consoles.hidden.length === 0
                Layout.fillWidth: true
                implicitHeight: 64
                radius: 18
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.12)
                Label {
                    anchors.centerIn: parent
                    text: qsTr("No hidden console.")
                    font.pixelSize: 15
                    opacity: 0.45
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
