// Accueil : une carte par console, avec ses actions (jouer, code, réveil, masquer).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import "controls" as C

import org.streetpea.chiaking

Pane {
    padding: 0
    id: consolePane
    // fond animé, en pause dès que l'écran d'accueil n'est plus affiché (pendant le jeu notamment)
    background: C.PsBackground {
        topReserve: 80
        running: consolePane.StackView.status === StackView.Active && Qt.application.state === Qt.ApplicationActive
    }
    FontLoader {
        id: titleFont
        source: "qrc:/fonts/Orbitron.ttf"
    }

    // nombre de consoles affichées, pour l'écran vide
    readonly property int shownHosts: {
        let n = 0;
        for (let i = 0; i < Chiaki.consoles.list.length; i++)
            if (Chiaki.consoles.list[i].display)
                n++;
        return n;
    }

    StackView.onActivated: {
        forceActiveFocus(Qt.TabFocusReason);
        if(!Chiaki.autoConnect && !root.initialAsk && !Chiaki.window.directStream)
        {
            root.initialAsk = true;
            if(Chiaki.settings.addSteamShortcutAsk && (typeof Chiaki.createSteamShortcut === "function"))
                root.showRemindDialog(qsTr("Official Steam artwork + controller layout"), qsTr("Would you like to either create a new non-Steam game for chiaki-ng\nor update an existing non-Steam game with the official artwork and controller layout?") + "\n\n" + qsTr("(Note: If you select no now and want to do this later, click the button or press R3 from the main menu.)"), false, () => root.showSteamShortcutDialog(true));
            else if(Chiaki.settings.remotePlayAsk)
            {
                if(!Chiaki.psn.connected)
                    root.showRemindDialog(qsTr("Remote Play via PSN"), qsTr("Would you like to connect to PSN?\nThis enables:\n- Automatic registration\n- Playing outside of your home network without port forwarding?") + "\n\n" + qsTr("(Note: If you select no now and want to do this later, go to the Config section of the settings.)"), true, () => root.showPSNTokenDialog(false));
                else
                    Chiaki.settings.remotePlayAsk = false;
            }
        }
    }
    Keys.onUpPressed: {
        if(hostsView.currentItem && hostsView.currentItem.visible)
        {
            hostsView.decrementCurrentIndex()
            while(!hostsView.currentItem.visible)
                hostsView.decrementCurrentIndex()
        }
    }
    Keys.onDownPressed: {
        if(hostsView.currentItem && hostsView.currentItem.visible)
        {
            hostsView.incrementCurrentIndex()
            while(!hostsView.currentItem.visible)
                 hostsView.incrementCurrentIndex()
        }
    }
    Keys.onMenuPressed: toolBar.openSettings()
    Keys.onReturnPressed: if (hostsView.currentItem) hostsView.currentItem.connectToHost()
    Keys.onYesPressed: if (hostsView.currentItem) hostsView.currentItem.wakeUpHost()
    Keys.onNoPressed: if (hostsView.currentItem) hostsView.currentItem.deleteHost()
    Keys.onEscapePressed: root.showConfirmDialog(qsTr("Quit"), qsTr("Are you sure you want to quit?"), () => Qt.quit())
    // repères de boutons : à la manette (touches) on les montre sur la carte choisie,
    // dès que la souris bouge on ne les montre plus que sous le curseur
    property bool padMode: Chiaki.controllers.length > 0
    // l'interface renvoie des survols « immobiles » quand quelque chose s'anime : on ne repasse
    // en mode souris que si le curseur a vraiment bougé
    property point lastMouse: Qt.point(-1, -1)
    property bool mouseSelecting: false
    function selectByMouse(i) {
        if (hostsView.currentIndex === i)
            return;
        mouseSelecting = true;
        hostsView.currentIndex = i;
        mouseSelecting = false;
    }
    HoverHandler {
        onPointChanged: {
            const p = point.scenePosition;
            if (Math.abs(p.x - consolePane.lastMouse.x) > 3 || Math.abs(p.y - consolePane.lastMouse.y) > 3) {
                if (consolePane.lastMouse.x >= 0) {
                    consolePane.padMode = false;
                    // la carte sous le curseur devient la carte choisie : ✕, L1, △… agissent sur elle
                    const q = hostsView.mapFromItem(null, p.x, p.y);
                    const i = hostsView.indexAt(q.x + hostsView.contentX, q.y + hostsView.contentY);
                    if (i >= 0)
                        consolePane.selectByMouse(i);
                }
                consolePane.lastMouse = p;
            }
        }
    }

    Keys.onPressed: (event) => {
        consolePane.padMode = true;
        if (event.modifiers)
            return;
        switch (event.key) {
        case Qt.Key_PageUp:
            if (hostsView.currentItem) hostsView.currentItem.setConsolePin();
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            toolBar.refreshPsn();
            event.accepted = true;
            break;
        case Qt.Key_F1:
            if (typeof Chiaki.createSteamShortcut === "function") root.showSteamShortcutDialog(false);
            event.accepted = true;
            break;
        case Qt.Key_F2:
            root.showRegistDialog("", true);
            event.accepted = true;
            break;
        }
    }

    // barre du haut, fine et transparente : le fond noir monte jusqu'en haut
    HomeTopBar {
        id: toolBar
        pageWidth: consolePane.width
    }

    ListView {
        id: hostsView
        // la manette (ou les flèches) change la carte choisie : on montre ses repères de boutons
        onCurrentIndexChanged: if (!consolePane.mouseSelecting) consolePane.padMode = true
        Keys.onPressed: (event) => { consolePane.padMode = true; event.accepted = false; }
        keyNavigationWraps: true
        anchors {
            top: toolBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 16
            bottomMargin: 90
        }
        clip: true
        spacing: 4
        model: Chiaki.consoles.list
        onCountChanged: {
            if(!hostsView.currentItem)
                hostsView.incrementCurrentIndex();
            if(!hostsView.currentItem)
                return;
            if(!hostsView.currentItem.visible)
            {
                for(var i = 0; i < hostsView.count; i++)
                {
                    hostsView.incrementCurrentIndex()
                    if(hostsView.currentItem.visible)
                    {
                        break;
                    }
                }
            }
        }
        delegate: ItemDelegate {
            visible: modelData.display
            id: delegate
            width: parent ? parent.width : 0
            height: modelData.display ? 320 : 0
            highlighted: ListView.isCurrentItem
            hoverEnabled: true
            leftInset: 24
            rightInset: 24
            topInset: 8
            bottomInset: 8
            // la carte se soulève légèrement au survol
            scale: hovered ? 1.008 : 1.0
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            readonly property bool ready: modelData.state == "ready"
            readonly property bool paired: modelData.paired
            // repères de boutons (✕, L1, △, □) : seulement sous la souris, ou sur la carte choisie à la manette
            readonly property bool showBadges: consolePane.padMode ? highlighted : hovered
            // qualité choisie dans les réglages pour cette console (en local ou à distance)
            property string quality: Chiaki.settings.qualityLabel(modelData.ps5, modelData.remote)
            Connections {
                target: Chiaki.settings
                function onQualityLabelsChanged() { delegate.quality = Chiaki.settings.qualityLabel(modelData.ps5, modelData.remote); }
            }
            background: Rectangle {
                radius: 30
                // fond presque opaque : les symboles néon de la page ne traversent plus la carte
                color: "#050b1d"
                border.width: delegate.highlighted ? 2 : 1
                border.color: delegate.highlighted ? Material.accent : Qt.rgba(0.6, 0.75, 1, delegate.hovered ? 0.35 : 0.2)
                Behavior on border.color { ColorAnimation { duration: 150 } }
                // dégradé bleu PlayStation venu de la gauche
                Rectangle {
                    anchors { fill: parent; margins: parent.border.width }
                    radius: parent.radius - parent.border.width
                    opacity: delegate.highlighted ? 1.0 : (delegate.hovered ? 0.8 : 0.6)
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.22, 0.6, 0.6) }
                        GradientStop { position: 0.65; color: "transparent" }
                    }
                }
                // reflet du verre sur le haut de la carte
                Rectangle {
                    anchors { fill: parent; margins: 1 }
                    radius: parent.radius - 1
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.07) }
                        GradientStop { position: 0.4; color: "transparent" }
                    }
                }
                // contour lumineux quand la carte est sélectionnée
                Rectangle {
                    anchors { fill: parent; margins: -6 }
                    radius: parent.radius + 6
                    color: "transparent"
                    border.width: 6
                    border.color: Qt.rgba(0.18, 0.49, 1, 0.18)
                    visible: delegate.highlighted
                }
            }
            onClicked: connectToHost()

            function connectToHost() {
                if (modelData.demo)
                    return root.showInfoDialog(qsTr("Demo console"), qsTr("This PS5 is only a demonstration, to preview the home screen with two consoles."));
                if(modelData.discovered)
                    Chiaki.connectToHost(modelData.key, modelData.name);
                else
                    Chiaki.connectToHost(modelData.key);
            }

            function wakeUpHost() {
                if (modelData.demo)
                    return root.showInfoDialog(qsTr("Demo console"), qsTr("This PS5 is only a demonstration, to preview the home screen with two consoles."));
                if(modelData.canWake)
                    Chiaki.consoles.wakeUp(modelData.key);
            }

            function deleteHost() {
                if (modelData.demo)
                    return root.showInfoDialog(qsTr("Demo console"), qsTr("This PS5 is only a demonstration, to preview the home screen with two consoles."));
                if (modelData.manual)
                    root.showConfirmDialog(qsTr("Delete Console"), qsTr("Are you sure you want to delete this console?"), () => {Chiaki.consoles.deleteManualHost(modelData.key)});
                        
                else if (modelData.discovered && !modelData.registered)
                    root.showConfirmDialog(qsTr("Hide Console"), qsTr("Are you sure you want to hide this console?") + "\n\n" + qsTr("Note: You can unhide from the Consoles section of the Settings under Hidden Consoles"), () => Chiaki.consoles.hide(modelData.mac, modelData.name));

            }

            function setConsolePin() {
                if (modelData.demo)
                    return root.showInfoDialog(qsTr("Demo console"), qsTr("This PS5 is only a demonstration, to preview the home screen with two consoles."));
                root.showConsolePinDialog(modelData.key);
            }

            // la console en grand à droite, avec le halo de la couleur du voyant
            Item {
                id: consoleArt
                anchors {
                    right: parent.right
                    // la PS5, plus étroite, se place au milieu de l'espace de la PS4
                    rightMargin: 70 + (modelData.ps5 ? (Math.min(430, delegate.width * 0.36) - 150) / 2 : 0)
                    verticalCenter: parent.verticalCenter
                }
                // PS4 couchée (large), PS5 debout (haute)
                width: modelData.ps5 ? 150 : Math.min(430, delegate.width * 0.36)
                height: modelData.ps5 ? 270 : width / 2

                Image {
                    id: consoleImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    source: "image://svg/console-ps" + (modelData.ps5 ? "5" : "4") + (modelData.state == "standby" ? "#light_standby" : "#light_on")
                    sourceSize: Qt.size(width * 2, height * 2)
                    visible: false
                }

                // halo qui respire quand la console est allumée
                MultiEffect {
                    anchors.fill: consoleImage
                    source: consoleImage
                    shadowEnabled: true
                    shadowColor: modelData.state == "standby" ? "#ffae2f" : "#3fb6ff"
                    shadowBlur: 1.0
                    shadowOpacity: modelData.state == "standby" ? 0.35 : 0.0

                    SequentialAnimation on shadowOpacity {
                        running: delegate.ready
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.3; to: 0.85; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.85; to: 0.3; duration: 1600; easing.type: Easing.InOutSine }
                    }
                }
            }

            // compte PSN : avatar, pseudo, PS Plus, niveau et trophées, entre les boutons et la console ;
            // seulement sur une console associée : une console vue sur le Wi-Fi peut être celle d'un autre
            PsnAccountPanel {
                id: accountPanel
                cardWidth: delegate.width
                shown: !!modelData.registered
            }

            // nom, étiquettes et boutons en bas à gauche, comme une bannière de l'écran d'accueil
            ColumnLayout {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 64
                }
                width: accountPanel.visible ? accountPanel.x - 64 - 40 : delegate.width * 0.58
                spacing: 0

                Label {
                    text: modelData.name || ""
                    font.pixelSize: 42
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    spacing: 12

                    C.StatusPill {
                        visible: !modelData.duid
                        dot: modelData.state == "ready" ? "#4ade80" : (modelData.state == "standby" ? "#fbbf24" : "#9ca3af")
                        text: ({ "ready": qsTr("ready"), "standby": qsTr("standby"), "unknown": qsTr("unknown") })[modelData.state] || (modelData.state || "")
                    }

                    C.StatusPill {
                        visible: !!modelData.duid
                        dot: "#a78bfa"
                        text: qsTr("Remote Connection via PSN")
                    }

                    C.StatusPill {
                        visible: !delegate.paired
                        dot: "#ff6b8b"
                        text: qsTr("not paired")
                    }

                    Repeater {
                        model: [modelData.ps5 ? "PS5" : "PS4", delegate.quality]
                        Rectangle {
                            implicitWidth: chipLabel.implicitWidth + 24
                            implicitHeight: 34
                            radius: 10
                            color: Qt.rgba(0.6, 0.75, 1, 0.12)
                            Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                font.letterSpacing: 0.5
                                color: "#b9d3ff"
                            }
                        }
                    }

                    Label {
                        visible: !modelData.duid && modelData.discovered && !!modelData.app
                        height: 34
                        verticalAlignment: Text.AlignVCenter
                        text: "▶  " + (modelData.app || "")
                        font.pixelSize: 16
                        opacity: 0.75
                    }

                    Label {
                        visible: !!modelData.address && !Chiaki.settings.streamerMode
                        height: 34
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.address || ""
                        font.pixelSize: 16
                        opacity: 0.5
                    }
                }

                RowLayout {
                    Layout.topMargin: 24
                    spacing: 14

                    // action principale de la carte
                    C.GlassButton {
                        Layout.preferredWidth: 200
                        primary: true
                        text: delegate.paired ? "▶  " + qsTr("Play") : qsTr("Pair")
                        font.pixelSize: 22
                        topPadding: 16
                        bottomPadding: 16
                        badge: delegate.showBadges ? root.controllerButton("cross") : ""
                        focusPolicy: Qt.NoFocus
                        onClicked: delegate.connectToHost()
                    }

                    C.GlassButton {
                        text: qsTr("Console PIN")
                        font.pixelSize: 15
                        topPadding: 9
                        bottomPadding: 9
                        badge: delegate.showBadges ? "qrc:/icons/l1.svg" : ""
                        visible: modelData.registered
                        focusPolicy: Qt.NoFocus
                        onClicked: delegate.setConsolePin()
                    }

                    C.GlassButton {
                        text: qsTr("Wake Up")
                        font.pixelSize: 15
                        topPadding: 9
                        bottomPadding: 9
                        badge: delegate.showBadges ? root.controllerButton("pyramid") : ""
                        visible: modelData.canWake
                        focusPolicy: Qt.NoFocus
                        onClicked: delegate.wakeUpHost()
                    }

                    C.GlassButton {
                        text: modelData.manual ? qsTr("Delete") : qsTr("Hide")
                        font.pixelSize: 15
                        topPadding: 9
                        bottomPadding: 9
                        badge: delegate.showBadges ? root.controllerButton("box") : ""
                        visible: modelData.manual || (modelData.discovered && !modelData.registered)
                        focusPolicy: Qt.NoFocus
                        onClicked: delegate.deleteHost()
                    }
                }
            }
        }
    }

    // écran vide : aucune console pour l'instant
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 30
        spacing: 18
        visible: consolePane.shownHosts === 0

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: "qrc:/icons/relais-logo.svg"
            sourceSize: Qt.size(180, 180)
            opacity: 0.85
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("No console found")
            font.pixelSize: 30
            font.weight: Font.DemiBold
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Turn on your PS4 and connect it to the same network as this Mac.")
            font.pixelSize: 18
            opacity: 0.65
        }

        C.GlassButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            primary: true
            text: "+  " + qsTr("Add Manual Host")
            focusPolicy: Qt.NoFocus
            onClicked: root.showRegistDialog("", true)
        }
    }

    // recherche des consoles sur le réseau : pastille en verre avec un point qui pulse
    Button {
        id: discoveryButton
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 24
        }
        flat: true
        focusPolicy: Qt.NoFocus
        checkable: true
        checked: Chiaki.consoles.discoveryEnabled
        onToggled: Chiaki.consoles.discoveryEnabled = !Chiaki.consoles.discoveryEnabled
        leftPadding: 42
        rightPadding: 22
        topPadding: 10
        bottomPadding: 10
        font.pixelSize: 16
        text: checked ? qsTr("Searching for consoles…") : qsTr("Search paused")
        background: Rectangle {
            implicitHeight: 44
            radius: height / 2
            color: Qt.rgba(1, 1, 1, discoveryButton.hovered ? 0.15 : 0.09)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        Rectangle {
            id: discoveryDot
            anchors {
                left: parent.left
                leftMargin: 20
                verticalCenter: parent.verticalCenter
            }
            width: 10
            height: 10
            radius: 5
            color: discoveryButton.checked ? Material.accent : "#9ca3af"

            // onde qui s'élargit tant que la recherche tourne
            Rectangle {
                id: discoveryRing
                anchors.centerIn: parent
                width: parent.width
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 2
                border.color: Material.accent
                visible: discoveryButton.checked
                opacity: 0

                ParallelAnimation {
                    running: discoveryButton.checked
                    loops: Animation.Infinite
                    NumberAnimation { target: discoveryRing; property: "width"; from: 10; to: 30; duration: 1400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: discoveryRing; property: "opacity"; from: 0.8; to: 0; duration: 1400 }
                }
            }
        }
    }

    Label {
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 24
        }
        visible: !Chiaki.updates.available
        text: "Mac'n'Play " + Qt.application.version
        opacity: 0.45
        font.pixelSize: 15
    }

    // nouvelle version publiée sur GitHub : l'utilisateur choisit de la télécharger ou non
    Rectangle {
        id: updateBanner
        visible: Chiaki.updates.available
        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 20
        }
        width: updateRow.implicitWidth + 32
        height: 68
        radius: 34
        color: Qt.rgba(0.25, 0.5, 1, 0.16)
        border.width: 1
        border.color: Qt.rgba(0.6, 0.78, 1, 0.45)
        RowLayout {
            id: updateRow
            anchors.centerIn: parent
            spacing: 14
            Label {
                text: qsTr("Mac'n'Play %1 is available").arg(Chiaki.updates.latestVersion)
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            C.GlassButton {
                primary: true
                text: qsTr("Download")
                onClicked: Qt.openUrlExternally(Chiaki.updates.pageUrl)
            }
            C.GlassButton {
                text: qsTr("Later")
                onClicked: Chiaki.updates.dismiss()
            }
        }
    }
}
