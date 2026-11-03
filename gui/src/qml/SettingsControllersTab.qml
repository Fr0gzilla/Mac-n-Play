// Onglet Manettes : vibrations, disposition, pavé tactile.
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
    // Controllers
    property alias rumbleHapticsItem: rumbleHaptics
    property alias controllersFlickItem: controllersFlick
    Flickable {
        id: controllersFlick
        anchors {
            fill: parent
            topMargin: 20
            bottomMargin: 20
        }
        clip: true
        contentWidth: width
        contentHeight: controllersLayout.height + 20
        flickableDirection: Flickable.AutoFlickIfNeeded
        ScrollBar.vertical: C.PsScrollBar {
            id: controllersScrollbar
            policy: ScrollBar.AsNeeded
            visible: controllersFlick.contentHeight > controllersFlick.height
        }

        ColumnLayout {
            id: controllersLayout
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: Math.min(controllersFlick.width - 80, 1100)
            spacing: 12

            SettingSection { text: qsTr("FEEL") }

            SettingCard {
                title: qsTr("Vibration")
                hint: qsTr("How strongly the controller vibrates in game. Default: Normal.")
                C.ComboBox {
                    id: rumbleHaptics
                    firstInFocusChain: true
                    width: parent.width
                    model: [qsTr("Off"), qsTr("Very Weak"), qsTr("Weak"), qsTr("Normal"), qsTr("Strong"), qsTr("Very Strong")]
                    currentIndex: Chiaki.settings.rumbleHapticsIntensity
                    onActivated: (index) => Chiaki.settings.rumbleHapticsIntensity = index;
                }
            }

            SettingCard {
                title: qsTr("True Haptics Intensity")
                hint: qsTr("Fine vibrations of the DualSense (PS5 games). 100 % follows the console setting.")
                RowLayout {
                    width: parent.width
                    spacing: 14
                    C.Slider {
                        id: hapticOverride
                        Layout.fillWidth: true
                        from: 0
                        to: 2
                        stepSize: 0.1
                        value: Chiaki.settings.hapticOverride
                        onMoved: Chiaki.settings.hapticOverride = value;
                    }
                    Label {
                        Layout.preferredWidth: 130
                        horizontalAlignment: Text.AlignRight
                        text: hapticOverride.value > 0.99 && hapticOverride.value < 1.01
                            ? qsTr("console setting")
                            : (hapticOverride.value * 100).toFixed(0) + " %"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                }
            }

            SettingSection { text: qsTr("BUTTON LAYOUT") }

            SettingCard {
                title: qsTr("Buttons by position")
                hint: qsTr("For Nintendo or Xbox style controllers: the button at the bottom always does ✕, whatever its letter. Default: off.")
                controlWidth: 120
                C.CheckBox {
                    id: posButtons
                    anchors.right: parent.right
                    checked: Chiaki.settings.buttonsByPosition
                    onToggled: Chiaki.settings.buttonsByPosition = checked
                }
            }

            SettingSection { text: qsTr("TOUCHPAD WITH THE D-PAD") }

            SettingCard {
                title: qsTr("Dpad Touchpad Emulation")
                hint: qsTr("Hold the combination below, then the D-pad swipes on the touchpad, for games that need it. Default: on.")
                controlWidth: 120
                C.CheckBox {
                    id: dpadTouch
                    anchors.right: parent.right
                    checked: Chiaki.settings.dpadTouchEnabled
                    onToggled: Chiaki.settings.dpadTouchEnabled = checked
                }
            }

            SettingCard {
                visible: Chiaki.settings.dpadTouchEnabled
                title: qsTr("Swipe length")
                hint: qsTr("How far one press of the D-pad moves on the touchpad. Default: 0.3 mm.")
                RowLayout {
                    width: parent.width
                    spacing: 14
                    C.Slider {
                        id: touchIncrement
                        Layout.fillWidth: true
                        from: 1
                        to: 1079
                        stepSize: 1
                        value: Chiaki.settings.dpadTouchIncrement
                        onMoved: Chiaki.settings.dpadTouchIncrement = value
                    }
                    Label {
                        Layout.preferredWidth: 90
                        horizontalAlignment: Text.AlignRight
                        text: qsTr("%1 mm").arg(touchIncrement.value / 100)
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                }
            }

            // la combinaison prend toute la largeur : quatre listes reliées par des « + »
            Rectangle {
                visible: Chiaki.settings.dpadTouchEnabled
                Layout.fillWidth: true
                implicitHeight: comboColumn.implicitHeight + 36
                radius: 18
                color: Qt.rgba(0.35, 0.55, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.16)
                ColumnLayout {
                    id: comboColumn
                    anchors { fill: parent; leftMargin: 22; rightMargin: 22; topMargin: 18; bottomMargin: 18 }
                    spacing: 12
                    Label {
                        text: qsTr("Switch combination")
                        font.pixelSize: 17
                        font.weight: Font.Medium
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("Buttons to hold together to switch the D-pad between normal and touchpad. Default: L1 + R1 + Up.")
                        font.pixelSize: 14
                        opacity: 0.55
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 10
                        C.ComboBox {
                            id: dpadShortcut1
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitContentWidthPolicy: ComboBox.WidestText
                            model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                            currentIndex: Chiaki.settings.dpadTouchShortcut1
                            onActivated: index => dialog.setDpadShortcut(1, index, this)
                        }
                        Label {
                            text: "+"
                            font.pixelSize: 20
                            color: "#9cc2ff"
                            opacity: 0.7
                        }
                        C.ComboBox {
                            id: dpadShortcut2
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitContentWidthPolicy: ComboBox.WidestText
                            model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                            currentIndex: Chiaki.settings.dpadTouchShortcut2
                            onActivated: index => dialog.setDpadShortcut(2, index, this)
                        }
                        Label {
                            text: "+"
                            font.pixelSize: 20
                            color: "#9cc2ff"
                            opacity: 0.7
                        }
                        C.ComboBox {
                            id: dpadShortcut3
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitContentWidthPolicy: ComboBox.WidestText
                            model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                            currentIndex: Chiaki.settings.dpadTouchShortcut3
                            onActivated: index => dialog.setDpadShortcut(3, index, this)
                        }
                        Label {
                            text: "+"
                            font.pixelSize: 20
                            color: "#9cc2ff"
                            opacity: 0.7
                        }
                        C.ComboBox {
                            id: dpadShortcut4
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitContentWidthPolicy: ComboBox.WidestText
                            model: [qsTr("Not Used"), qsTr("Cross"), qsTr("Moon"), qsTr("Box"), qsTr("Pyramid"), qsTr("Dpad Left"), qsTr("Dpad Right"), qsTr("Dpad Up"), qsTr("Dpad Down"), qsTr("L1"), qsTr("R1"), qsTr("L3"), qsTr("R3"), qsTr("Options"), qsTr("Share"), qsTr("Touchpad"), qsTr("PS")]
                            currentIndex: Chiaki.settings.dpadTouchShortcut4
                            onActivated: index => dialog.setDpadShortcut(4, index, this)
                        }
                    }
                }
            }

            SettingSection { text: qsTr("IN THE BACKGROUND") }

            SettingCard {
                title: qsTr("Controller in the background")
                hint: qsTr("The controller keeps working when another app is in front of Mac'n'Play. Default: on.")
                controlWidth: 120
                C.CheckBox {
                    id: backgroundController
                    lastInFocusChain: true
                    anchors.right: parent.right
                    checked: Chiaki.settings.allowJoystickBackgroundEvents
                    onToggled: Chiaki.settings.allowJoystickBackgroundEvents = checked
                }
            }
        }
    }
}
