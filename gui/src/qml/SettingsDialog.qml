// Cadre des Paramètres : onglets, navigation à la manette, choix de la console réglée.
import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtQuick.Effects

import org.streetpea.chiaking

import "controls" as C

DialogView {
    enum Console {
        PS4,
        PS5
    }
    property int selectedConsole: SettingsDialog.Console.PS5
    property bool quitControllerMapping: true
    // « L'essentiel » à l'ouverture ; « Tous les réglages » montre les onglets détaillés
    property bool simpleMode: true
    function showAdvanced(tab) {
        selectedConsole = essentialPage.consoleIndex;
        simpleMode = false;
        if (tab >= 0)
            bar.currentIndex = tab;
        Qt.callLater(focusCurrentTabFirstItem);
    }
    function showEssentials() {
        simpleMode = true;
        essentialPage.focusFirst();
    }
    // marge du bas : on y loge les repères de boutons quand une manette est branchée
    readonly property int bottomInset: Chiaki.controllers.length > 0 ? 64 : 20
    id: dialog
    title: qsTr("Settings")
    header: qsTr("* Defaults in () to right of value or marked with (Default)")
    buttonVisible: false
    readonly property bool isSettingsPage: true
    // éléments des onglets dont la fenêtre a besoin (focus, défilement, raccourcis)
    readonly property var disconnectAction: generalTab.disconnectActionItem
    readonly property var generalFlick: generalTab.generalFlickItem
    readonly property var hwDecoderCombo: videoTab.hwDecoderComboItem
    readonly property var videoFlick: videoTab.videoFlickItem
    readonly property var consoleSelection: streamTab.consoleSelectionItem
    readonly property var streamFlick: streamTab.streamFlickItem
    readonly property var audioOutDevice: audioWifiTab.audioOutDeviceItem
    readonly property var audiowifiFlick: audioWifiTab.audiowifiFlickItem
    readonly property var registerNewButton: consolesTab.registerNewButtonItem
    readonly property var consolesFlick: consolesTab.consolesFlickItem
    readonly property var keyboardAsController: controllerMapping.keyboardAsControllerItem
    readonly property var keysFlick: controllerMapping.keysFlickItem
    readonly property var padFlick: controllerMapping.padFlickItem
    readonly property var controllerMappingChange: controllerMapping.controllerMappingChangeItem
    readonly property var controllerMappingReset: controllerMapping.controllerMappingResetItem
    readonly property var rumbleHaptics: controllersTab.rumbleHapticsItem
    readonly property var controllersFlick: controllersTab.controllersFlickItem
    readonly property var openPsnLogin: remoteTab.openPsnLoginItem
    readonly property var resetPsnTokens: remoteTab.resetPsnTokensItem
    readonly property var holePunchGuessingCheckbox: remoteTab.holePunchGuessingCheckboxItem
    readonly property var portGuessCountSlider: remoteTab.portGuessCountSliderItem
    readonly property var portGuessSocketSlider: remoteTab.portGuessSocketSliderItem
    readonly property var remoteFlick: remoteTab.remoteFlickItem
    readonly property var profile: configTab.profileItem
    readonly property var configFlick: configTab.configFlickItem
    readonly property var aboutButton: configTab.aboutButtonItem

    // consoles associées (plus la PS5 de démonstration si elle est lancée) ; avec 2 consoles,
    // un sélecteur en haut choisit celle dont on règle la qualité, la fluidité, etc.
    readonly property var consoleList: {
        let list = Chiaki.settings.registeredHosts.map(h => ({ mac: h.mac, name: h.name, ps5: h.ps5 }));
        for (const h of Chiaki.consoles.list)
            if (h.demo && !list.some(c => c.mac === h.mac))
                list.push({ mac: h.mac, name: h.name, ps5: h.ps5 });
        return list;
    }
    readonly property bool multiConsole: consoleList.length > 1
    readonly property var chosenConsole: {
        if (!multiConsole)
            return null;
        return consoleList.find(c => c.mac === Chiaki.settings.activeConsole) || consoleList[0];
    }
    // combinaison de la croix « pavé tactile » : le modèle refuse celle du menu en jeu, on prévient
    function setDpadShortcut(n, index, combo) {
        if (Chiaki.settings.trySetDpadTouchShortcut(n, index))
            return;
        combo.currentIndex = Qt.binding(() => Chiaki.settings["dpadTouchShortcut" + n]);
        root.showInfoDialog(qsTr("Combination already used"), qsTr("This combination already opens the in-game menu. Choose different buttons for the touchpad, otherwise opening the menu would also switch the D-pad."));
    }
    function selectConsole(mac) {
        Chiaki.settings.activateConsole(mac);
    }
    function nextConsole() {
        if (!multiConsole)
            return;
        const i = consoleList.findIndex(c => c.mac === chosenConsole.mac);
        selectConsole(consoleList[(i + 1) % consoleList.length].mac);
    }
    Component.onCompleted: {
        if (multiConsole && chosenConsole.mac !== Chiaki.settings.activeConsole)
            selectConsole(chosenConsole.mac);
    }
    // l'onglet Streaming montre les réglages PS4 ou PS5 : suivre le type de la console choisie
    onChosenConsoleChanged: if (chosenConsole) selectedConsole = chosenConsole.ps5 ? SettingsDialog.Console.PS5 : SettingsDialog.Console.PS4
    function flickContainsItem(flick, item) {
        let current = item;
        while (current) {
            if (current === flick || current === flick.contentItem)
                return true;
            current = current.parent;
        }
        return false;
    }
    function flickVisibilityTarget(flick, item) {
        let current = item;
        while (current && current !== flick && current !== flick.contentItem) {
            if (current.parent === flick.contentItem)
                return current;
            if (current.parent && current.parent.parent === flick.contentItem)
                return current;
            current = current.parent;
        }
        return item;
    }
    function ensureItemVisibleInFlick(flick, item) {
        if (!flick || !item || !flickContainsItem(flick, item))
            return;
        const target = flickVisibilityTarget(flick, item);
        const top = target.mapToItem(flick.contentItem, 0, 0).y;
        const bottom = top + target.height;
        if (top < flick.contentY)
            flick.contentY = top;
        else if (bottom > flick.contentY + flick.height)
            flick.contentY = bottom - flick.height;
    }
    function itemIsInsideNestedScrollable(flick, item) {
        let current = item ? item.parent : null;
        while (current && current !== flick && current !== flick.contentItem) {
            if (current.contentY !== undefined && current.contentHeight !== undefined && current !== flick)
                return true;
            current = current.parent;
        }
        return false;
    }
    function nestedScrollableTarget(flick, item) {
        let current = item;
        while (current && current !== flick && current !== flick.contentItem) {
            if (current.contentY !== undefined && current.contentHeight !== undefined && current !== flick)
                return current;
            current = current.parent;
        }
        return item;
    }
    function ensureActiveFocusVisible() {
        const flick = activeSettingsFlick();
        const window = dialog.Window.window;
        if (!flick || !window || !window.activeFocusItem)
            return;
        const target = itemIsInsideNestedScrollable(flick, window.activeFocusItem)
            ? nestedScrollableTarget(flick, window.activeFocusItem)
            : window.activeFocusItem;
        ensureItemVisibleInFlick(flick, target);
    }
    function scrollFlickKeepingItemVisible(flick, item, delta) {
        if (!flick || !item)
            return;
        const maxContentY = Math.max(0, flick.contentHeight - flick.height);
        if (maxContentY <= 0)
            return;
        flick.contentY = Math.max(0, Math.min(maxContentY, flick.contentY + delta));
    }
    function focusCurrentTabFirstItem() {
        let item = null;
        switch (bar.currentIndex) {
        case 0: item = disconnectAction; break;
        case 1: item = hwDecoderCombo; break;
        case 2: item = consoleSelection; break;
        case 3: item = audioOutDevice; break;
        case 4: item = registerNewButton; break;
        case 5: item = controllerMapping.keysSubTab === 0 ? controllerMapping.firstNavButton() : keyboardAsController; break;
        case 6: item = rumbleHaptics; break;
        case 7: item = firstRemoteFocusableItem(); break;
        case 8: item = profile; break;
        }
        if (item)
            item.forceActiveFocus(Qt.TabFocusReason);
    }
    function activeSettingsFlick() {
        if (simpleMode)
            return essentialPage;
        switch (bar.currentIndex) {
        case 0: return generalFlick;
        case 1: return videoFlick;
        case 2: return streamFlick;
        case 3: return audiowifiFlick;
        case 4: return consolesFlick;
        case 5: return controllerMapping.keysSubTab === 0 ? padFlick : keysFlick;
        case 6: return controllersFlick;
        case 7: return remoteFlick;
        case 8: return configFlick;
        default: return null;
        }
    }

    function firstRemoteFocusableItem() {
        if (openPsnLogin.visible)
            return openPsnLogin;
        if (resetPsnTokens.visible)
            return resetPsnTokens;
        if (holePunchGuessingCheckbox.visible)
            return holePunchGuessingCheckbox;
        if (portGuessCountSlider.visible)
            return portGuessCountSlider;
        if (portGuessSocketSlider.visible)
            return portGuessSocketSlider;
        return remoteFlick;
    }
    // focus perdu (clic dans le vide…) : la première flèche le remet sur le premier réglage de la page
    function focusIsOutsidePage() {
        const flick = activeSettingsFlick();
        const window = dialog.Window.window;
        return !!flick && !!window && (!window.activeFocusItem || !flickContainsItem(flick, window.activeFocusItem));
    }
    function focusFirstOfPage() {
        if (simpleMode)
            essentialPage.focusFirst();
        else
            focusCurrentTabFirstItem();
    }
    Keys.onPressed: (event) => {
        if (event.modifiers)
            return;
        if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].indexOf(event.key) >= 0 && focusIsOutsidePage()) {
            focusFirstOfPage();
            event.accepted = true;
            return;
        }
        switch (event.key) {
        // Options : ferme les réglages, comme il les a ouverts
        case Qt.Key_Menu:
            dialog.close();
            event.accepted = true;
            break;
        // L2 / R2 : « L'essentiel » / « Tous les réglages » ; L1 / R1 : onglets
        case Qt.Key_F3:
            if (!simpleMode)
                showEssentials();
            event.accepted = true;
            break;
        case Qt.Key_F4:
            if (simpleMode)
                showAdvanced(-1);
            event.accepted = true;
            break;
        // △ dans l'onglet Touches : Manette / Clavier et souris
        case Qt.Key_Yes:
            if (!simpleMode && bar.currentIndex === 5) {
                controllerMapping.keysSubTab = 1 - controllerMapping.keysSubTab;
                event.accepted = true;
            } else if (multiConsole) {
                nextConsole();
                event.accepted = true;
            }
            break;
        case Qt.Key_PageUp:
            if (!simpleMode)
                bar.decrementCurrentIndex();
            event.accepted = true;
            break;
        case Qt.Key_PageDown:
            if (!simpleMode)
                bar.incrementCurrentIndex();
            event.accepted = true;
            break;
        case Qt.Key_Up:
        {
            const flick = activeSettingsFlick();
            if (!flick || flick.contentHeight <= flick.height || flick.contentY <= 0.001)
                return;
            flick.flick(0, 500);
            event.accepted = true;
            break;
        }
        case Qt.Key_Down:
        {
            const flick = activeSettingsFlick();
            if (!flick || flick.contentHeight <= flick.height || flick.contentY >= flick.contentHeight - flick.height - 0.001)
                return;
            flick.flick(0, -500);
            event.accepted = true;
            break;
        }
        }
    }

    Item {
        // sélecteur « L'essentiel » / « Tous les réglages » : un contour néon glisse de l'un à l'autre
        Rectangle {
            id: modeSwitch
            anchors { top: parent.top; topMargin: 4; horizontalCenter: parent.horizontalCenter }
            width: 460
            height: 42
            radius: height / 2
            color: Qt.rgba(0.03, 0.07, 0.17, 0.55)
            border.width: 1
            border.color: Qt.rgba(0.6, 0.75, 1, 0.22)

            Rectangle {
                width: parent.width / 2 - 6
                height: parent.height - 8
                y: 4
                x: dialog.simpleMode ? 4 : parent.width / 2 + 2
                radius: height / 2
                color: Qt.rgba(0.0, 0.27, 0.75, 0.12)
                border.width: 2
                border.color: "#3d7bff"
                Behavior on x { SpringAnimation { spring: 3; damping: 0.3; epsilon: 0.25 } }
            }

            Row {
                anchors.fill: parent
                Repeater {
                    model: [qsTr("Essentials"), qsTr("All settings")]
                    delegate: Label {
                        required property int index
                        required property string modelData
                        width: modeSwitch.width / 2
                        height: modeSwitch.height
                        text: modelData
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 16
                        readonly property bool active: (index === 0) === dialog.simpleMode
                        font.weight: active ? Font.DemiBold : Font.Normal
                        color: active ? "#9cc2ff" : "#ffffff"
                        opacity: active ? 1.0 : 0.6
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: index === 0 ? dialog.showEssentials() : dialog.showAdvanced(-1)
                        }
                    }
                }
            }
        }

        // repères manette, seulement quand une manette est branchée :
        // L2 / R2 autour du sélecteur, L1 / R1 autour des onglets
        Image {
            anchors { verticalCenter: modeSwitch.verticalCenter; right: modeSwitch.left; rightMargin: 12 }
            width: 30; height: 30
            sourceSize: Qt.size(60, 60)
            source: "qrc:/icons/l2.svg"
            visible: Chiaki.controllers.length > 0
            opacity: !dialog.simpleMode ? 0.9 : 0.3
        }
        Image {
            anchors { verticalCenter: modeSwitch.verticalCenter; left: modeSwitch.right; leftMargin: 12 }
            width: 30; height: 30
            sourceSize: Qt.size(60, 60)
            source: "qrc:/icons/r2.svg"
            visible: Chiaki.controllers.length > 0
            opacity: dialog.simpleMode ? 0.9 : 0.3
        }
        Image {
            anchors { verticalCenter: bar.verticalCenter; right: bar.left; rightMargin: 12 }
            width: 30; height: 30
            sourceSize: Qt.size(60, 60)
            source: "qrc:/icons/l1.svg"
            visible: Chiaki.controllers.length > 0 && !dialog.simpleMode
            opacity: bar.currentIndex > 0 ? 0.9 : 0.3
        }
        Image {
            anchors { verticalCenter: bar.verticalCenter; left: bar.right; leftMargin: 12 }
            width: 30; height: 30
            sourceSize: Qt.size(60, 60)
            source: "qrc:/icons/r1.svg"
            visible: Chiaki.controllers.length > 0 && !dialog.simpleMode
            opacity: bar.currentIndex < bar.count - 1 ? 0.9 : 0.3
        }

        TabBar {
            id: bar
            visible: !dialog.simpleMode
            anchors {
                top: modeSwitch.bottom
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 70
                rightMargin: 70
            }
            spacing: 4
            padding: 6
            background: C.GlassBackground {
                radius: height / 2
                tint: 0.55
            }
            // pastille bleue qui glisse d'un onglet à l'autre (remplace le soulignement)
            contentItem: ListView {
                id: tabsView
                model: bar.contentModel
                currentIndex: bar.currentIndex
                spacing: bar.spacing
                orientation: ListView.Horizontal
                interactive: false
                highlightFollowsCurrentItem: false
                // goutte de verre liquide : elle file vers l'onglet choisi avec un ressort,
                // s'étire pendant le trajet puis rebondit en arrivant
                highlight: Item {
                    id: drop
                    readonly property real targetX: tabsView.currentItem ? tabsView.currentItem.x : 0
                    readonly property real targetW: tabsView.currentItem ? tabsView.currentItem.width : 0
                    readonly property real gap: Math.abs(x - targetX)
                    x: targetX
                    width: targetW
                    height: tabsView.height
                    Behavior on x { SpringAnimation { spring: 2.6; damping: 0.26; epsilon: 0.25 } }
                    Behavior on width { SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.25 } }
                    transform: Scale {
                        origin.x: drop.width / 2
                        origin.y: drop.height / 2
                        xScale: 1 + Math.min(0.22, drop.gap / 700)
                        yScale: 1 - Math.min(0.2, drop.gap / 650)
                    }

                    // contour néon bleu, comme les symboles du fond
                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: "transparent"
                        border.width: 2
                        border.color: "#3d7bff"
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#0046c0"
                            shadowBlur: 0.7
                            shadowOpacity: 1.0
                            shadowHorizontalOffset: 0
                            shadowVerticalOffset: 0
                        }

                        // lueur intérieure du tube
                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: height / 2
                            color: Qt.rgba(0.0, 0.27, 0.75, 0.10)
                            border.width: 3
                            border.color: Qt.rgba(0.0, 0.27, 0.75, 0.35)
                        }
                    }
                }
            }

            C.PsTab {
                id: general
                text: qsTr("General")
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                id: video
                text: qsTr("Video")
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                id: stream
                text: qsTr("Stream")
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Audio/Wifi")
                id: audio
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Consoles")
                id: consoles
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Keys")
                id: keys
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Controllers")
                id: controllers
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Remote")
                id: remote
                focusPolicy: Qt.NoFocus
            }

            C.PsTab {
                text: qsTr("Config")
                id: config
                focusPolicy: Qt.NoFocus
            }
        }

        // grand panneau de verre derrière le contenu de l'onglet
        C.GlassBackground {
            anchors {
                top: dialog.simpleMode ? modeSwitch.bottom : bar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 16
                leftMargin: 24
                rightMargin: 24
                bottomMargin: dialog.bottomInset
            }
            tint: 0.6
        }

        // page « L'essentiel »
        EssentialSettings {
            id: essentialPage
            selectedConsole: dialog.chosenConsole
            visible: dialog.simpleMode
            anchors {
                top: modeSwitch.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 16
                leftMargin: 24
                rightMargin: 24
                bottomMargin: dialog.bottomInset
            }
            onOpenAdvanced: (tab) => dialog.showAdvanced(tab)
            onSwitchConsole: dialog.nextConsole()
        }

        StackLayout {
            id: settingsPages
            visible: !dialog.simpleMode
            anchors {
                top: bar.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 16
                leftMargin: 24
                rightMargin: 24
                bottomMargin: dialog.bottomInset
            }
            currentIndex: bar.currentIndex
            property int previousIndex: 0
            property real pageBlur: 0
            property real pageShift: 0
            transform: Translate { x: settingsPages.pageShift }
            layer.enabled: pageSwitch.running
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: settingsPages.pageBlur
                blurMax: 40
            }
            ParallelAnimation {
                id: pageSwitch
                NumberAnimation { target: settingsPages; property: "pageBlur"; from: 0.7; to: 0; duration: 380; easing.type: Easing.OutCubic }
                NumberAnimation { target: settingsPages; property: "opacity"; from: 0.35; to: 1; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { id: shiftAnim; target: settingsPages; property: "pageShift"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            }
            onCurrentIndexChanged: {
                shiftAnim.from = currentIndex > previousIndex ? 60 : -60;
                previousIndex = currentIndex;
                pageSwitch.restart();
                dialog.focusCurrentTabFirstItem()
                Qt.callLater(dialog.ensureActiveFocusVisible)
            }

            SettingsGeneralTab { id: generalTab }

            SettingsVideoTab { id: videoTab }

            SettingsStreamTab { id: streamTab }

            SettingsAudioWifiTab { id: audioWifiTab }

            SettingsConsolesTab { id: consolesTab }

            SettingsKeysTab { id: controllerMapping }

            SettingsControllersTab { id: controllersTab }

            SettingsRemoteTab { id: remoteTab }

            SettingsConfigTab { id: configTab }
        }

        // repères manette : ce que fait chaque bouton dans les Paramètres
        Row {
            anchors { bottom: parent.bottom; bottomMargin: 16; horizontalCenter: parent.horizontalCenter }
            visible: Chiaki.controllers.length > 0
            spacing: 34
            Repeater {
                model: [
                    { icon: root.controllerButton("cross"), text: qsTr("Select") },
                    { icon: root.controllerButton("moon"), text: qsTr("Back") },
                    { icon: "qrc:/icons/l2.svg", icon2: "qrc:/icons/r2.svg", text: qsTr("Essentials") + " / " + qsTr("All settings") }
                ].concat(dialog.simpleMode ? [] : [{ icon: "qrc:/icons/l1.svg", icon2: "qrc:/icons/r1.svg", text: qsTr("Change tab") }])
                 .concat(!dialog.simpleMode && bar.currentIndex === 5 ? [{ icon: root.controllerButton("pyramid"), text: qsTr("Controller") + " / " + qsTr("Keyboard and mouse") }]
                        : (dialog.multiConsole ? [{ icon: root.controllerButton("pyramid"), text: qsTr("Change console") }] : []))
                delegate: Row {
                    required property var modelData
                    spacing: 8
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 26
                        sourceSize: Qt.size(52, 52)
                        source: modelData.icon
                    }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!modelData.icon2
                        width: 26; height: 26
                        sourceSize: Qt.size(52, 52)
                        source: modelData.icon2 || ""
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text
                        font.pixelSize: 15
                        opacity: 0.7
                    }
                }
            }
        }

        Connections {
            target: dialog.Window.window
            function onActiveFocusItemChanged() {
                dialog.ensureActiveFocusVisible()
            }
        }

        Item {
            Timer {
                id: openTimer
                interval: 100
                running: false
                onTriggered: {
                    if(controllerMappingDialog.resetMapping)
                    {
                        if(!Chiaki.controllerMapping.defaultMapping)
                        {
                            quitControllerMapping = false;
                            Chiaki.controllerMapping.reset();
                        }
                        controllerMappingDialog.close();
                    }
                    else
                    {
                        controllerMappingChange.forceActiveFocus(Qt.TabFocusReason);
                        root.showControllerMappingDialog();
                        quitControllerMapping = false;
                        controllerMappingDialog.resetFocus = false;
                        controllerMappingDialog.close();
                    }
                }
            }
        }

        Dialog {
            // petite fenêtre en verre sombre au contour bleu, comme les listes déroulantes
            background: Rectangle {
                radius: 22
                color: "#0a1430"
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
            }
            padding: 28
            id: aboutDialog
            parent: Overlay.overlay
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            title: qsTr("About %1-ng").arg(Qt.application.name)
            modal: true
            standardButtons: Dialog.Ok
            Material.roundedScale: Material.MediumScale
            onAboutToHide: aboutButton.forceActiveFocus(Qt.TabFocusReason)

            RowLayout {
                spacing: 50
                onVisibleChanged: if (visible) forceActiveFocus(Qt.TabFocusReason)
                Keys.onReturnPressed: aboutDialog.close()
                Keys.onEscapePressed: aboutDialog.close()

                Image {
                    Layout.preferredWidth: 200
                    fillMode: Image.PreserveAspectFit
                    verticalAlignment: Image.AlignTop
                    source: "qrc:icons/relais.svg"
                }

                Label {
                    Layout.preferredWidth: 400
                    verticalAlignment: Text.AlignTop
                    wrapMode: Text.Wrap
                    text: "<h1>Mac'n'Play</h1> version %1
                        <h2>Basé sur chiaki-ng</h2> de Street Pea, lui-même dérivé de Chiaki de Florian Markl (version 2.1.1)

                        <p>This program is free software: you can redistribute it and/or modify
                        it under the terms of the GNU Affero General Public License version 3
                        as published by the Free Software Foundation.</p>

                        <p>This program is distributed in the hope that it will be useful,
                        but WITHOUT ANY WARRANTY; without even the implied warranty of
                        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
                        GNU General Public License for more details.</p>".arg(Qt.application.version)
                }
            }
        }

        C.CaptureDialog {
            id: keyDialog
            heading: qsTr("Press a key on your keyboard")
            detail: qsTr("for « %1 »").arg(buttonLabel)
            focus: false
            property int buttonValue
            property var buttonCallback
            property Item keyItem
            property string buttonLabel
            property int keySlot: 0
            parent: Overlay.overlay
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            // ✕ ouvre cette fenêtre : son relâchement ne doit pas être pris pour la nouvelle touche
            property double openedAt: 0
            onOpened: {
                openedAt = Date.now();
                keyLabel.forceActiveFocus(Qt.TabFocusReason);
            }
            onClosed: {
                // la liste a pu être recréée entre-temps : à défaut, premier réglage de la page
                const value = buttonValue, slot = keySlot;
                Qt.callLater(() => keysFlick.refocusKey(value, slot));
                keyLabel.focus = false;
                focus = false;
            }

            function show(opts) {
                buttonValue = opts.value;
                buttonCallback = opts.callback;
                keyItem = opts.item;
                buttonLabel = opts.label;
                keySlot = opts.slot || 0;
                const info = keysFlick.keyInfo(opts.value, opts.label);
                icon = info.icon || "";
                glyph = info.glyph || "";
                open();
            }

            Label {
                id: keyLabel
                Layout.preferredHeight: 0
                opacity: 0
                focus: true
                Keys.onReleased: (event) => {
                    if (event.isAutoRepeat || Date.now() - keyDialog.openedAt < 300)
                        return;
                    var name = keyDialog.keySlot === 1
                        ? Chiaki.settings.changeControllerKey2(keyDialog.buttonValue, event.key)
                        : Chiaki.settings.changeControllerKey(keyDialog.buttonValue, event.key);
                    keyDialog.buttonCallback(name);
                    keyDialog.close();
                }
            }
        }

        C.CaptureDialog {
            id: controllerMappingDialog
            icon: "qrc:/icons/ps/manette.svg"
            heading: qsTr("Press any button on the controller")
            detail: qsTr("to choose which controller to set up.")
            property bool resetFocus: true
            property bool resetMapping: false
            parent: Overlay.overlay
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            onOpened: {
                controllerLabel.forceActiveFocus(Qt.TabFocusReason);
                Chiaki.controllerMapping.begin(resetMapping);
            }
            onClosed: {
                if(resetFocus)
                {
                    if(resetMapping)
                        controllerMappingReset.forceActiveFocus(Qt.TabFocusReason);
                    else
                        controllerMappingChange.forceActiveFocus(Qt.TabFocusReason);
                    focus = false;
                }
                else
                {
                    resetFocus = true;
                    focus = false;
                }
                if(quitControllerMapping)
                    Chiaki.controllerMapping.quit();
                else
                    quitControllerMapping = true;
            }

            function show(opts) {
                resetMapping = opts.reset;
                open();
            }
            Label {
                id: controllerLabel
                Layout.preferredHeight: 0
                opacity: 0
            }
        }

        Dialog {
            // petite fenêtre en verre sombre au contour bleu, comme les listes déroulantes
            background: Rectangle {
                radius: 22
                color: "#0a1430"
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
            }
            padding: 28
            id: steamControllerMappingDialog
            property bool resetMapping: false
            parent: Overlay.overlay
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            title: qsTr("Controller Managed by Steam")
            modal: true
            standardButtons: Dialog.Close
            closePolicy: Popup.NoAutoClose
            onOpened: {
                steamLabel.forceActiveFocus(Qt.TabFocusReason);
            }
            onClosed: {
                if(resetMapping)
                    controllerMappingReset.forceActiveFocus(Qt.TabFocusReason);
                else
                    controllerMappingChange.forceActiveFocus(Qt.TabFocusReason);
                focus = false;
            }
            Material.roundedScale: Material.MediumScale

            Label {
                id: steamLabel
                wrapMode: TextEdit.Wrap
                text: qsTr("This controller is managed by Steam.\nPlease use Steam to map controller or disable Steam Input for the controller before mapping here.")
                Keys.onReturnPressed: steamControllerMappingDialog.close();
                Keys.onEscapePressed: steamControllerMappingDialog.close();
            }
        }

        Connections {
            target: Chiaki.controllerMapping

            function onInProgressChanged()
            {
                if(Chiaki.controllerMapping.inProgress)
                    openTimer.start();
            }

            function onSteamControllerSelected()
            {
                controllerMappingDialog.resetFocus = false;
                quitControllerMapping = false;
                steamControllerMappingDialog.resetMapping = controllerMappingDialog.resetMapping;
                controllerMappingDialog.close();
                steamControllerMappingDialog.open();
            }
        }
    }
}
