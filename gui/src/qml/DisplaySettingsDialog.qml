import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs

import org.streetpea.chiaking

import "controls" as C

// Réglages de l'écran pendant une partie : une carte par réglage, expliquée simplement.
// ○, la flèche ou la combinaison du menu ramènent au menu en jeu.
DialogView {
    id: dialog
    property alias gridHeight: displayGrid.height
    title: qsTr("Display Settings")
    buttonVisible: false

    function close() {
        root.backToStreamMenu();
    }

    component SettingCard: Rectangle {
        property alias title: cardTitle.text
        property alias hint: cardHint.text
        default property alias control: cardHolder.data
        property real controlWidth: 420
        Layout.fillWidth: true
        implicitHeight: Math.max(cardText.implicitHeight, cardHolder.implicitHeight) + 32
        radius: 18
        color: Qt.rgba(0.35, 0.55, 1, 0.05)
        border.width: 1
        border.color: Qt.rgba(0.6, 0.75, 1, 0.16)
        RowLayout {
            anchors { fill: parent; leftMargin: 22; rightMargin: 22 }
            spacing: 24
            ColumnLayout {
                id: cardText
                Layout.fillWidth: true
                spacing: 4
                Label {
                    id: cardTitle
                    Layout.fillWidth: true
                    font.pixelSize: 17
                    font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
                Label {
                    id: cardHint
                    Layout.fillWidth: true
                    font.pixelSize: 14
                    opacity: 0.55
                    wrapMode: Text.WordWrap
                }
            }
            Item {
                id: cardHolder
                Layout.preferredWidth: controlWidth
                Layout.preferredHeight: childrenRect.height
                implicitHeight: childrenRect.height
            }
        }
    }

    Item {
        ColumnLayout {
            id: displayGrid
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                topMargin: 10
            }
            width: Math.min(parent.width - 80, 1100)
            spacing: 12

            Label {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.6
                text: qsTr("These settings describe your screen so the picture looks right on it. Auto works for almost every screen: only change them if colours or brightness look wrong.")
            }

            SettingCard {
                title: qsTr("Screen colours")
                hint: qsTr("The range of colours your screen can show. Default: Auto.")
                C.ComboBox {
                    firstInFocusChain: true
                    width: parent.width
                    model: [qsTr("Auto"), qsTr("ITU-R Rec. BT.601 NTSC (Standard Gamut)"), qsTr("ITU-R Rec. BT.601 PAL (Standard Gamut)"), qsTr("ITU-R Rec. BT.709 (Standard Gamut)"), qsTr("ITU-R Rec. BT.470 M (Standard Gamut)"), qsTr("EBU Tech. 3213-E (Standard Gamut)"), qsTr("ITU-R Rec. BT.2020 (Wide Gamut)"), qsTr("Apple RGB (Wide Gamut)"), qsTr("Adobe RGB (Wide Gamut)"), qsTr("ProPhoto RGB (Wide Gamut)"), qsTr("CIE 1931 RGB primaries (Wide Gamut)"), qsTr("DCI-P3 (Wide Gamut)"), qsTr("DCI-P3 with D65 white point (Wide Gamut)"), qsTr("Panasonic V-Gamut (Wide Gamut)"), qsTr("Sony S-Gamut (Wide Gamut)"), qsTr("Traditional film primaries with Illuminant C (Wide Gamut)"), qsTr("ACES Primaries #0 (Wide Gamut)"), qsTr("ACES Primaries #1 (Wide Gamut)")]
                    currentIndex: Chiaki.settings.displayTargetPrim
                    onActivated: index => Chiaki.settings.displayTargetPrim = index
                }
            }

            SettingCard {
                title: qsTr("Brightness curve")
                hint: qsTr("How shadows and highlights are spread. HDR curves are for HDR screens only. Default: Auto.")
                C.ComboBox {
                    width: parent.width
                    model: [qsTr("Auto"), qsTr("ITU-R Rec. BT.1886 (SDR)"), qsTr("IEC 61966-2-4 sRGB (SDR)"), qsTr("Linear light content (SDR)"), qsTr("IPure power gamma 1.8 (SDR)"), qsTr("Pure power gamma 2.0 (SDR)"), qsTr("Pure power gamma 2.2 (SDR)"), qsTr("Pure power gamma 2.4 (SDR)"), qsTr("Pure power gamma 2.6 (SDR)"), qsTr("Pure power gamma 2.8 (SDR)"), qsTr("ProPhoto RGB (SDR)"), qsTr("Digital Cinema Distribution Master (SDR)"), qsTr("ITU-R BT.2100 PQ / SMPTE ST2048 (HDR)"), qsTr("ITU-R BT.2100 HLG / ARIB STD-B67 (HDR)"), qsTr("Panasonic V-Log (HDR)"), qsTr("Sony S-Log1 (HDR)"), qsTr("Sony S-Log2 (HDR)")]
                    currentIndex: Chiaki.settings.displayTargetTrc
                    onActivated: index => Chiaki.settings.displayTargetTrc = index
                }
            }

            SettingCard {
                title: qsTr("Maximum brightness")
                hint: qsTr("The brightest your screen can go, mostly useful in HDR. Auto reads it from the screen. Default: Auto.")
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    C.ComboBox {
                        id: targetPeakChoice
                        Layout.fillWidth: true
                        model: [qsTr("Auto"), qsTr("Numeric Value")]
                        currentIndex: Chiaki.settings.displayTargetPeak == 0 ? 0 : 1
                        onActivated: index => Chiaki.settings.displayTargetPeak = index == 0 ? 0 : 1000
                    }
                    RowLayout {
                        visible: targetPeakChoice.currentIndex == 1
                        Layout.fillWidth: true
                        spacing: 14
                        C.Slider {
                            id: targetPeakValue
                            Layout.fillWidth: true
                            from: 10
                            to: 10000
                            stepSize: 10
                            value: Chiaki.settings.displayTargetPeak
                            onMoved: Chiaki.settings.displayTargetPeak = value
                        }
                        Label {
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignRight
                            text: targetPeakValue.value + qsTr(" nits")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#9cc2ff"
                        }
                    }
                }
            }

            SettingCard {
                title: qsTr("Contrast")
                hint: qsTr("The gap between the deepest black and the brightest white. Infinity suits OLED screens. Default: Auto.")
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    C.ComboBox {
                        id: targetContrastChoice
                        Layout.fillWidth: true
                        lastInFocusChain: currentIndex != 2
                        model: [qsTr("Auto"), qsTr("Infinity"), qsTr("Numeric Value")]
                        currentIndex: Chiaki.settings.displayTargetContrast == -1 ? 1 : (Chiaki.settings.displayTargetContrast == 0 ? 0 : 2)
                        onActivated: index => Chiaki.settings.displayTargetContrast = index == 0 ? 0 : (index == 1 ? -1 : 1000)
                    }
                    RowLayout {
                        visible: targetContrastChoice.currentIndex == 2
                        Layout.fillWidth: true
                        spacing: 14
                        C.Slider {
                            id: targetContrastValue
                            Layout.fillWidth: true
                            from: 10
                            to: 1000000
                            stepSize: 1000
                            value: Chiaki.settings.displayTargetContrast
                            onMoved: Chiaki.settings.displayTargetContrast = value
                            lastInFocusChain: true
                        }
                        Label {
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignRight
                            text: targetContrastValue.value + " : 1"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            color: "#9cc2ff"
                        }
                    }
                }
            }
        }
    }
}
