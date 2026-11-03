// Panneau du compte PSN sur la carte d'une console : avatar, pseudo, PS Plus, niveau, trophées.
// Affichage seul : les données viennent de Chiaki.psn.profile.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import "controls" as C

import org.streetpea.chiaking

Rectangle {
    // largeur de la carte : le panneau se cache si elle est trop étroite
    property real cardWidth: 0
    id: accountPanel
    readonly property var p: Chiaki.psn.profile
    visible: !!p.onlineId && !Chiaki.settings.streamerMode && cardWidth > 1350
    anchors {
        horizontalCenter: parent.horizontalCenter
        horizontalCenterOffset: 20
        verticalCenter: parent.verticalCenter
    }
    width: 400
    height: accountColumn.implicitHeight + 40
    radius: 24
    color: Qt.rgba(0.35, 0.55, 1, 0.07)
    border.width: 1
    border.color: Qt.rgba(0.6, 0.75, 1, 0.18)

    ColumnLayout {
        id: accountColumn
        anchors { fill: parent; margins: 20 }
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            // avatar rond avec un liseré bleu
            Item {
                Layout.preferredWidth: 76
                Layout.preferredHeight: 76
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "#0b1530"
                    border.width: 2
                    border.color: "#3d7bff"
                }
                Image {
                    id: avatarImage
                    anchors { fill: parent; margins: 4 }
                    source: accountPanel.p.avatar || ""
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                }
                Rectangle {
                    id: avatarMask
                    anchors.fill: avatarImage
                    radius: width / 2
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: avatarImage
                    source: avatarImage
                    maskEnabled: true
                    maskSource: avatarMask
                }
                // point vert quand le compte est en ligne
                Rectangle {
                    visible: !!accountPanel.p.online
                    anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                    width: 18
                    height: 18
                    radius: 9
                    color: "#4ade80"
                    border.width: 3
                    border.color: "#050b1d"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    spacing: 10
                    Label {
                        Layout.maximumWidth: 200
                        text: accountPanel.p.onlineId || ""
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    // badge PlayStation Plus doré
                    Rectangle {
                        visible: !!accountPanel.p.plus
                        implicitWidth: plusLabel.implicitWidth + 16
                        implicitHeight: 22
                        radius: 6
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffd75e" }
                            GradientStop { position: 1.0; color: "#e8a317" }
                        }
                        Label {
                            id: plusLabel
                            anchors.centerIn: parent
                            text: "PS Plus"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: "#3a2500"
                        }
                    }
                }

                Label {
                    text: accountPanel.p.game ? "▶  " + accountPanel.p.game : (accountPanel.p.online ? qsTr("Online") : qsTr("Offline"))
                    font.pixelSize: 14
                    opacity: 0.6
                    elide: Text.ElideRight
                    Layout.maximumWidth: 250
                }

                // niveau de trophées et progression vers le suivant
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Label {
                        text: qsTr("Level %1").arg(accountPanel.p.level || 0)
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Qt.rgba(1, 1, 1, 0.1)
                        Rectangle {
                            width: parent.width * (accountPanel.p.progress || 0) / 100
                            height: parent.height
                            radius: 3
                            color: "#3d9bff"
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#3d9bff"; shadowBlur: 0.6; shadowVerticalOffset: 0; shadowHorizontalOffset: 0 }
                        }
                    }
                }
            }
        }

        // les quatre trophées : platine, or, argent, bronze
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(0.6, 0.75, 1, 0.14)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -4
            spacing: 0
            Repeater {
                model: [
                    { n: accountPanel.p.platinum, c: "#c9dcff" },
                    { n: accountPanel.p.gold, c: "#f5c542" },
                    { n: accountPanel.p.silver, c: "#c3cad6" },
                    { n: accountPanel.p.bronze, c: "#d18a52" }
                ]
                Item {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 26
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Canvas {
                        id: cup
                        width: 20
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        property color tint: modelData.c
                        onTintChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.fillStyle = tint;
                            ctx.strokeStyle = tint;
                            ctx.lineWidth = 2;
                            // coupe, anses, pied
                            ctx.beginPath();
                            ctx.moveTo(4, 2); ctx.lineTo(16, 2); ctx.lineTo(15, 9);
                            ctx.quadraticCurveTo(10, 15, 5, 9); ctx.closePath(); ctx.fill();
                            ctx.beginPath(); ctx.arc(3.5, 6, 2.5, Math.PI * 0.5, Math.PI * 1.5); ctx.stroke();
                            ctx.beginPath(); ctx.arc(16.5, 6, 2.5, -Math.PI * 0.5, Math.PI * 0.5); ctx.stroke();
                            ctx.fillRect(9, 13, 2, 4);
                            ctx.fillRect(5, 17, 10, 3);
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.n || 0
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                }
                }
            }
        }
    }
}
