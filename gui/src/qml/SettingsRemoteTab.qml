// Onglet À distance : compte PSN et connexion par Internet.
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
    // Remote (PSN and Hole Punching)
    property alias openPsnLoginItem: openPsnLogin
    property alias resetPsnTokensItem: resetPsnTokens
    property alias holePunchGuessingCheckboxItem: holePunchGuessingCheckbox
    property alias portGuessCountSliderItem: portGuessCountSlider
    property alias portGuessSocketSliderItem: portGuessSocketSlider
    property alias remoteFlickItem: remoteFlick
    Flickable {
        id: remoteFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: remoteGrid.height + 20
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            visible: remoteFlick.contentHeight > remoteFlick.height
        }
        ColumnLayout {
            id: remoteGrid
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(remoteFlick.width - 80, 1100)
            spacing: 12
            readonly property bool psnConnected: Chiaki.psn.connected

            SettingSection { text: qsTr("PSN ACCOUNT") }

            SettingCard {
                title: remoteGrid.psnConnected ? qsTr("Connected to PSN") : qsTr("PSN not connected")
                hint: remoteGrid.psnConnected
                    ? qsTr("You can play away from home, over the Internet, without setting up your router. Log out to remove this Mac's access to your account.")
                    : qsTr("Log in to play away from home, over the Internet, without setting up your router.")
                controlWidth: 260
                C.Button {
                    id: openPsnLogin
                    anchors.right: parent.right
                    firstInFocusChain: visible
                    visible: !remoteGrid.psnConnected
                    text: qsTr("Login to PSN")
                    onClicked: root.showPSNTokenDialog(false)
                }
                C.Button {
                    id: resetPsnTokens
                    anchors.right: parent.right
                    firstInFocusChain: visible
                    visible: remoteGrid.psnConnected
                    text: qsTr("Log out")
                    onClicked: {
                        Chiaki.psn.logout()
                        openPsnLogin.forceActiveFocus(Qt.TabFocusReason);
                    }
                }
            }

            SettingSection { text: qsTr("REMOTE CONNECTION (ADVANCED)") }

            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.6
                text: qsTr("Away from home, the Mac and the console must find each other through both Internet routers. These settings only help if the remote connection fails: otherwise leave them as they are.")
            }

            SettingCard {
                title: qsTr("Force port guessing")
                hint: qsTr("If the remote connection fails, the Mac tries to guess which door the router on the other side will open. Useful with some routers and 4G/5G networks. Default: off.")
                controlWidth: 120
                C.CheckBox {
                    id: holePunchGuessingCheckbox
                    anchors.right: parent.right
                    checked: Chiaki.settings.portGuessingEnabled
                    onToggled: Chiaki.settings.portGuessingEnabled = checked
                }
            }

            SettingCard {
                title: qsTr("Number of tries")
                hint: qsTr("How many different doors are tried. More gives a better chance to connect, but connecting can take longer. Default: 75.")
                RowLayout {
                    width: parent.width
                    spacing: 14
                    C.Slider {
                        id: portGuessCountSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 75
                        stepSize: 1
                        value: Chiaki.settings.portGuessCount
                        onMoved: Chiaki.settings.portGuessCount = value
                    }
                    Label {
                        Layout.preferredWidth: 110
                        horizontalAlignment: Text.AlignRight
                        text: qsTr("%1 tries").arg(portGuessCountSlider.value)
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                }
            }

            SettingCard {
                title: qsTr("Connections at once")
                hint: qsTr("How many small connections the Mac opens at the same time for these tries. Lower it if your router struggles; raise it if the connection still fails. Default: 250.")
                RowLayout {
                    width: parent.width
                    spacing: 14
                    C.Slider {
                        id: portGuessSocketSlider
                        Layout.fillWidth: true
                        from: 0
                        to: 500
                        stepSize: 1
                        value: Chiaki.settings.portGuessSocketCount
                        onMoved: Chiaki.settings.portGuessSocketCount = value
                        lastInFocusChain: true
                    }
                    Label {
                        Layout.preferredWidth: 110
                        horizontalAlignment: Text.AlignRight
                        text: portGuessSocketSlider.value
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
