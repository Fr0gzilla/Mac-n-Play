// Barre du haut de l'accueil : logo, actualisation PSN, état du compte, ajout de console, Paramètres.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import "controls" as C

import org.streetpea.chiaking

ToolBar {
    // largeur de la page d'accueil, pour replier les libellés quand la fenêtre est étroite
    property real pageWidth: width
    function openSettings() { settingsButton.clicked(); }
    function refreshPsn() { if (Chiaki.settings.psnAuthToken) psnRefresh.clicked(); }
    id: toolBar
    anchors {
        top: parent.top
        left: parent.left
        right: parent.right
    }
    height: 64
    background: Item { }

    // la barre sert aussi de poignée pour déplacer la fenêtre
    DragHandler {
        target: null
        onActiveChanged: if (active) Chiaki.window.startSystemMove()
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10 + root.titleBarInset
            rightMargin: 24
        }
        spacing: 12

        Button {
            Layout.fillHeight: true
            Layout.preferredWidth: 100
            flat: true
            text: "×"
            font.pixelSize: 60
            focusPolicy: Qt.NoFocus
            onClicked: Qt.quit()
            Material.roundedScale: Material.SmallScale
            // sur Mac, la pastille rouge fait déjà ce travail
            visible: Qt.platform.os !== "osx"
        }

        // logo : petite manette néon
        Image {
            Layout.leftMargin: Qt.platform.os === "osx" ? 10 : 0
            Layout.preferredWidth: 46
            Layout.preferredHeight: 30
            source: "qrc:/icons/ps/manette.svg"
            sourceSize: Qt.size(138, 90)
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#0046c0"
                shadowBlur: 0.8
                shadowOpacity: 1.0
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        // titre en Orbitron, avec un léger halo bleu
        Label {
            id: appTitle
            text: "Mac'n'Play"
            font.family: titleFont.name
            font.pixelSize: 24
            font.weight: Font.Bold
            font.letterSpacing: 1.5
            color: "#eaf2ff"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#0046c0"
                shadowBlur: 0.8
                shadowOpacity: 0.9
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Item { Layout.fillWidth: true }

        Button {
            Layout.fillHeight: true
            Layout.preferredWidth: 350
            flat: true
            text: qsTr("Create Steam Shortcut")
            focusPolicy: Qt.NoFocus
            onClicked: root.showSteamShortcutDialog(false)
            Material.roundedScale: Material.SmallScale
            visible: typeof Chiaki.createSteamShortcut === "function" && Qt.platform.os !== "osx"
            Image {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    leftMargin: 12
                }
                width: 28
                height: 28
                sourceSize: Qt.size(width, height)
                source: "qrc:/icons/l3.svg"
            }
        }

        // actualise la liste des consoles du compte PSN ; montre que ça travaille puis que c'est fait
        C.GlassButton {
            id: psnRefresh
            property int step: 0 // 0 repos, 1 en cours, 2 terminé
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 48
            topInset: 0
            bottomInset: 0
            // fenêtre étroite : juste le symbole, le texte prendrait trop de place
            readonly property bool compact: pageWidth < 1150
            text: step === 1 ? "↻" + (compact ? "" : "  " + qsTr("Refreshing…")) : (step === 2 ? "✓" + (compact ? "" : "  " + qsTr("Up to date")) : (compact ? "↻" : qsTr("Refresh PSN Hosts")))
            font.pixelSize: 15
            topPadding: 0
            bottomPadding: 0
            badge: "qrc:/icons/r1.svg"
            focusPolicy: Qt.NoFocus
            onClicked: {
                if (step === 1)
                    return;
                step = 1;
                psnRefreshMin.restart();
                psnRefreshMax.restart();
                Chiaki.psn.refresh();
            }
            visible: Chiaki.settings.psnAuthToken
            property bool answered: false
            Connections {
                target: Chiaki.consoles
                function onListChanged() {
                    if (psnRefresh.step !== 1)
                        return;
                    psnRefresh.answered = true;
                    if (!psnRefreshMin.running)
                        psnRefresh.finish();
                }
            }
            function finish() {
                psnRefreshMax.stop();
                step = 2;
                answered = false;
                psnRefreshDone.restart();
            }
            // reste au moins un instant sur « Actualisation… » pour qu'on le voie
            Timer { id: psnRefreshMin; interval: 900; onTriggered: if (psnRefresh.answered) psnRefresh.finish() }
            Timer { id: psnRefreshMax; interval: 10000; onTriggered: psnRefresh.finish() }
            Timer { id: psnRefreshDone; interval: 2500; onTriggered: psnRefresh.step = 0 }
        }

        // état du compte PSN : clic pour se connecter s'il ne l'est pas
        C.StatusPill {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 48
            readonly property bool connected: !!Chiaki.settings.psnAuthToken
            dot: connected ? "#4ade80" : "#6b7280"
            text: pageWidth < 950 ? "PSN" : (connected ? qsTr("Connected to PSN") : qsTr("PSN not connected"))
            opacity: psnArea.containsMouse ? 1.0 : 0.85
            MouseArea {
                id: psnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: parent.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: if (!parent.connected) root.showPSNTokenDialog(false)
            }
        }

        // « + » dans un rond en verre ; le texte se déplie au survol
        C.GlassButton {
            id: addButton
            Layout.alignment: Qt.AlignVCenter
            // avec une manette : repère R3 (enfoncer le joystick droit) à côté du « + »
            badge: Chiaki.controllers.length ? "qrc:/icons/r3.svg" : ""
            Layout.preferredWidth: (hovered ? addMetrics.width + 70 : 48) + (badge ? 40 : 0)
            Layout.preferredHeight: 48
            topInset: 0
            bottomInset: 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            clip: true
            leftPadding: badge ? 40 : 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            text: hovered ? "+  " + qsTr("Add Manual Host") : "+"
            font.pixelSize: hovered ? 17 : 26
            focusPolicy: Qt.NoFocus
            onClicked: root.showRegistDialog("", true)
            TextMetrics {
                id: addMetrics
                font.pixelSize: 17
                text: "+  " + qsTr("Add Manual Host")
            }
        }

        // roue crantée néon : s'illumine et tourne d'un cran au survol
        Button {
            id: settingsButton
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: root.showSettingsDialog()
            topInset: 0
            bottomInset: 0
            background: Rectangle {
                radius: height / 2
                color: Qt.rgba(1, 1, 1, settingsButton.down ? 0.20 : (settingsButton.hovered ? 0.16 : 0.10))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                source: "qrc:/icons/reglages.svg"
                sourceSize: Qt.size(108, 108)
                rotation: settingsButton.hovered ? 45 : 0
                scale: settingsButton.down ? 0.9 : 1.0
                Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                Behavior on scale { NumberAnimation { duration: 100 } }
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#0046c0"
                    shadowBlur: 0.8
                    shadowOpacity: settingsButton.hovered ? 1.0 : 0.5
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }
            }
        }
    }
}
