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
    // combinaison de la croix « pavé tactile » : refusée si elle est identique à celle du menu en jeu
    function setDpadShortcut(n, index, combo) {
        const st = Chiaki.settings;
        let dpad = [st.dpadTouchShortcut1, st.dpadTouchShortcut2, st.dpadTouchShortcut3, st.dpadTouchShortcut4];
        dpad[n - 1] = index;
        const menu = [st.streamMenuShortcut1, st.streamMenuShortcut2, st.streamMenuShortcut3, st.streamMenuShortcut4];
        const key = list => list.filter(b => b > 0).sort((a, b) => a - b).join(",");
        if (key(dpad) !== "" && key(dpad) === key(menu)) {
            combo.currentIndex = Qt.binding(() => Chiaki.settings["dpadTouchShortcut" + n]);
            root.showInfoDialog(qsTr("Combination already used"), qsTr("This combination already opens the in-game menu. Choose different buttons for the touchpad, otherwise opening the menu would also switch the D-pad."));
            return;
        }
        st["dpadTouchShortcut" + n] = index;
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

            Item {
                // General
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
                                text: qsTr("Action On Disconnect:")
                                font.weight: Font.Medium
                                opacity: 0.92
                            }

                        C.ComboBox {
                            id: disconnectAction
                            Layout.preferredWidth: 400
                            firstInFocusChain: true
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

            Item {
                // Video
                Flickable {
                    id: videoFlick
                    anchors {
                        fill: parent
                        topMargin: 20
                        bottomMargin: 20
                    }
                    clip: true
                    contentWidth: width
                    contentHeight: (videoGrid.height * videoGrid.scale) + 10
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    ScrollBar.vertical: C.PsScrollBar {
                        visible: videoFlick.contentHeight > videoFlick.height
                    }
                    GridLayout {
                        id: videoGrid
                        // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
                        scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
                        transformOrigin: Item.Top
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        columns: 3
                        rowSpacing: 14
                        columnSpacing: 24

                        // avec 2 consoles : rappeler ce qui est propre à la console choisie
                        Rectangle {
                            visible: dialog.multiConsole
                            Layout.columnSpan: 3
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            implicitHeight: videoTagLabel.implicitHeight + 22
                            radius: 14
                            color: Qt.rgba(0.24, 0.48, 1, 0.10)
                            border.width: 1
                            border.color: Qt.rgba(0.36, 0.56, 0.88, 0.45)
                            Label {
                                id: videoTagLabel
                                anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                font.pixelSize: 14
                                text: dialog.chosenConsole ? qsTr("Resolution, frame rate, bitrate and video format apply to %1 only. The other settings apply to all consoles.").arg(dialog.chosenConsole.name) : ""
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Hardware Decoder:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                    RowLayout {
                        Layout.preferredWidth: 400
                        spacing: 12

                        C.ComboBox {
                            id: hwDecoderCombo
                            Layout.preferredWidth: 220
                            model: Chiaki.settings.availableDecoders
                            currentIndex: Math.max(0, model.indexOf(Chiaki.settings.decoder))
                            KeyNavigation.priority: KeyNavigation.BeforeItem
                            KeyNavigation.up: hwDecoderCombo
                            KeyNavigation.right: zeroCopyCheck
                            KeyNavigation.down: windowTypeCombo
                            onActivated: (index) => Chiaki.settings.decoder = index ? model[index] : ""
                        }

                        Label {
                            text: qsTr("Zero-Copy")
                        }

                        C.CheckBox {
                            id: zeroCopyCheck
                            KeyNavigation.priority: KeyNavigation.BeforeItem
                            KeyNavigation.up: zeroCopyCheck
                            KeyNavigation.left: hwDecoderCombo
                            KeyNavigation.down: windowTypeCombo
                            checked: Chiaki.settings.useZeroCopy
                            onToggled: Chiaki.settings.useZeroCopy = checked
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Auto)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Window Type:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        id: windowTypeCombo
                        Layout.preferredWidth: 400
                        popup.width: 500
                        model: [qsTr("Stream Resolution"), qsTr("Custom Resolution"), qsTr("Adjust Resolution Manually"), qsTr("Fullscreen"), qsTr("Zoom [adjust zoom using slider in stream menu]"), qsTr("Stretch")]
                        currentIndex: Chiaki.settings.windowType
                        onActivated: (index) => Chiaki.settings.windowType = index;
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Fullscreen)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("Custom Resolution Width")
                        visible: Chiaki.settings.windowType == 1
                    }

                    C.TextField {
                        id: customResolutionWidth
                        Layout.preferredWidth: 400
                        visible: Chiaki.settings.windowType == 1
                        text: Chiaki.settings.customResolutionWidth
                        Material.accent: text && !validate() ? Material.Red : undefined
                        onEditingFinished: {
                            if (validate()) {
                                Chiaki.settings.customResolutionWidth = parseInt(text);
                            } else {
                                Chiaki.settings.customResolutionWidth = 0;
                                text = "";
                            }
                        }
                        function validate() {
                            var num = parseInt(text);
                            return num >= 0 && num <= 9999;
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(1920)")
                        opacity: 0.45
                        font.pixelSize: 15
                        visible: Chiaki.settings.windowType == 1
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("Custom Resolution Height")
                        visible: Chiaki.settings.windowType == 1
                    }

                    C.TextField {
                        id: customResolutionHeight
                        Layout.preferredWidth: 400
                        visible: Chiaki.settings.windowType == 1
                        text: Chiaki.settings.customResolutionHeight
                        Material.accent: text && !validate() ? Material.Red : undefined
                        onEditingFinished: {
                            if (validate()) {
                                Chiaki.settings.customResolutionHeight = parseInt(text);
                            } else {
                                Chiaki.settings.customResolutionHeight = 0;
                                text = "";
                            }
                        }
                        function validate() {
                            var num = parseInt(text);
                            return num >= 0 && num <= 9999;
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(1080)")
                        opacity: 0.45
                        font.pixelSize: 15
                        visible: Chiaki.settings.windowType == 1
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Toggle Fullscreen on Double-click:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.CheckBox {
                        checked: Chiaki.settings.fullscreenDoubleClick
                        onToggled: Chiaki.settings.fullscreenDoubleClick = checked
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Unchecked)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("Hide Cursor during Stream")
                    }
                    C.CheckBox {
                        checked: Chiaki.settings.hideCursor
                        onToggled: Chiaki.settings.hideCursor = !Chiaki.settings.hideCursor
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Checked)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Vertical Sync:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.CheckBox {
                        checked: Chiaki.settings.vSyncEnabled
                        onClicked: {
                            Chiaki.settings.vSyncEnabled = checked
                            if (Chiaki.window.runtimeRendererBackend === 1 && Chiaki.settings.restartApplication())
                                Qt.quit()
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Unchecked)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Render Preset:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        Layout.preferredWidth: 400
                        popup.width: 560
                        model: [qsTr("Fast"), qsTr("Default"), qsTr("High Quality"), qsTr("High Quality + Spatial Upscaling"), qsTr("High Quality + Advanced Spatial Upscaling"), qsTr("Custom")]
                        currentIndex: Chiaki.settings.videoPreset
                        onActivated: (index) => {
                            Chiaki.settings.videoPreset = index;
                            switch (index) {
                            case 0: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Fast; break;
                            case 1: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Default; break;
                            case 2: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQuality; break;
                            case 3: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualitySpatial; break;
                            case 4: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.HighQualityAdvancedSpatial; break;
                            case 5: Chiaki.window.videoPreset = ChiakiWindow.VideoPreset.Custom; break;
                            }
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(High Quality)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Frame Delivery:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        Layout.preferredWidth: 400
                        model: [qsTr("Direct Mapping"), qsTr("Frame Queue")]
                        currentIndex: Chiaki.settings.directFrameMapping ? 0 : 1
                        onActivated: (index) => {
                            const direct = index === 0;
                            if (direct === Chiaki.settings.directFrameMapping)
                                return;
                            Chiaki.settings.directFrameMapping = direct;
                            if (Chiaki.settings.restartApplication())
                                Qt.quit();
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Direct Mapping)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Frame Mixer:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        Layout.preferredWidth: 400
                        model: [qsTr("None"), qsTr("Oversample"), qsTr("Hermite"), qsTr("Linear"), qsTr("Cubic")]
                        enabled: !Chiaki.settings.directFrameMapping
                        currentIndex: Chiaki.settings.directFrameMapping ? 0 : Chiaki.settings.placeboFrameMixer
                        onActivated: index => Chiaki.settings.placeboFrameMixer = index
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(None)")
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Renderer Backend:")
                        // sur Mac, l'appli force toujours OpenGL : ce choix ne changerait rien
                        visible: Qt.platform.os !== "osx"
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        Layout.preferredWidth: 400
                        model: [qsTr("Vulkan"), qsTr("OpenGL")]
                        visible: Qt.platform.os !== "osx"
                        currentIndex: Chiaki.settings.rendererBackend
                        onActivated: (index) => {
                            if (index === Chiaki.settings.rendererBackend)
                                return;
                            Chiaki.settings.rendererBackend = index;
                            if (Chiaki.settings.restartApplication())
                                Qt.quit();
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Vulkan)")
                        visible: Qt.platform.os !== "osx"
                        opacity: 0.45
                        font.pixelSize: 15
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Vulkan Deferred Swap:")
                        font.weight: Font.Medium
                        opacity: 0.92
                        visible: Chiaki.settings.rendererBackend == 0
                    }

                    C.CheckBox {
                        checked: Chiaki.settings.vulkanDeferredSwap
                        onToggled: Chiaki.settings.vulkanDeferredSwap = checked
                        visible: Chiaki.settings.rendererBackend == 0
                    }

                    Label {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                        Layout.preferredWidth: 230
                        elide: Text.ElideRight
                        text: qsTr("(Unchecked)")
                        opacity: 0.45
                        font.pixelSize: 15
                        visible: Chiaki.settings.rendererBackend == 0
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("Custom Renderer Settings")
                        visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
                    }

                    C.Button {
                        id: customRendererSettings
                        text: qsTr("Open")
                        onClicked: root.showPlaceboSettingsDialog()
                        Material.roundedScale: Material.SmallScale
                        visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom
                    }

                    Label { visible: Chiaki.window.videoPreset == ChiakiWindow.VideoPreset.Custom }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 360
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("Display Settings")
                    }

                    C.Button {
                        id: displaySettings
                        text: qsTr("Open")
                        onClicked: root.showDisplaySettingsDialog()
                        Material.roundedScale: Material.SmallScale
                        lastInFocusChain: true
                    }

                    Label {}
                    }
                }
            }

            Item {
                // Stream
                Flickable {
                    id: streamFlick
                    anchors {
                        fill: parent
                        topMargin: 20
                        bottomMargin: 20
                    }
                    clip: true
                    contentWidth: width
                    contentHeight: (streamGrid.height * streamGrid.scale) + 10
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    ScrollBar.vertical: C.PsScrollBar {
                        visible: streamFlick.contentHeight > streamFlick.height
                    }
                    GridLayout {
                        id: streamGrid
                        // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
                        scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
                        transformOrigin: Item.Top
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        columns: 3
                        rowSpacing: 14
                        columnSpacing: 24

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 180
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Settings for:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }


                    C.ComboBox {
                        id: consoleSelection
                        Layout.preferredWidth: 400
                        Layout.alignment: Qt.AlignLeft
                        model: [qsTr("PS4"), qsTr("PS5")]
                        currentIndex: selectedConsole
                        onActivated: (index) => selectedConsole = index
                        firstInFocusChain: true
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                        KeyNavigation.down: {
                            if(selectedConsole == SettingsDialog.Console.PS4)
                                resolutionLocalPS4
                            else
                                resolutionLocalPS5

                        }

                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("")
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("")
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("")
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("")
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        font.weight: Font.Medium
                        opacity: 0.92
                        text: qsTr("")
                    }

                    Label {
                        Layout.alignment: Qt.AlignCenter
                        text: qsTr("Local")
                    }

                    Label {
                        Layout.alignment: Qt.AlignCenter
                        text: qsTr("Remote")
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Resolution:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        id: resolutionLocalPS4
                        Layout.preferredWidth: 400
                        model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p (PS5 and PS4 Pro)")]
                        currentIndex: Chiaki.settings.resolutionLocalPS4 - 1
                        onActivated: (index) => {
                            Chiaki.settings.resolutionLocalPS4 = index + 1
                            Chiaki.settings.bitrateLocalPS4 = 0
                        }
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        KeyNavigation.right: resolutionRemotePS4
                        KeyNavigation.down: fpsLocalPS4
                        KeyNavigation.up: consoleSelection
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: resolutionRemotePS4
                        Layout.preferredWidth: 400
                        model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p (PS5 and PS4 Pro)")]
                        currentIndex: Chiaki.settings.resolutionRemotePS4 - 1
                        onActivated: (index) => {
                            Chiaki.settings.resolutionRemotePS4 = index + 1
                            Chiaki.settings.bitrateRemotePS4 = 0
                        }
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        KeyNavigation.left: resolutionLocalPS4
                        KeyNavigation.down: fpsRemotePS4
                        KeyNavigation.up: consoleSelection
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: resolutionLocalPS5
                        Layout.preferredWidth: 400
                        model: [qsTr("360p"), qsTr("540p"), qsTr("720p"), qsTr("1080p (Default)")]
                        currentIndex: Chiaki.settings.resolutionLocalPS5 - 1
                        onActivated: (index) => {
                            Chiaki.settings.resolutionLocalPS5 = index + 1
                            Chiaki.settings.bitrateLocalPS5 = 0
                        }
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        KeyNavigation.right: resolutionRemotePS5
                        KeyNavigation.up: consoleSelection
                        KeyNavigation.down: fpsLocalPS5
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: resolutionRemotePS5
                        Layout.preferredWidth: 400
                        model: [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p")]
                        currentIndex: Chiaki.settings.resolutionRemotePS5 - 1
                        onActivated: (index) => {
                            Chiaki.settings.resolutionRemotePS5 = index + 1
                            Chiaki.settings.bitrateRemotePS5 = 0
                        }
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        KeyNavigation.left: resolutionLocalPS5
                        KeyNavigation.up: consoleSelection
                        KeyNavigation.down: fpsRemotePS5
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("FPS:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.ComboBox {
                        id: fpsLocalPS4
                        Layout.preferredWidth: 400
                        model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
                        currentIndex: (Chiaki.settings.fpsLocalPS4 / 30) - 1
                        onActivated: (index) => Chiaki.settings.fpsLocalPS4 = (index + 1) * 30
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        KeyNavigation.up: resolutionLocalPS4
                        KeyNavigation.right: fpsRemotePS4
                        KeyNavigation.down: bitrateLocalPS4
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: fpsRemotePS4
                        Layout.preferredWidth: 400
                        model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
                        currentIndex: (Chiaki.settings.fpsRemotePS4 / 30) - 1
                        onActivated: (index) => Chiaki.settings.fpsRemotePS4 = (index + 1) * 30
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        KeyNavigation.up: resolutionRemotePS4
                        KeyNavigation.left: fpsLocalPS4
                        KeyNavigation.down: bitrateRemotePS4
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: fpsLocalPS5
                        Layout.preferredWidth: 400
                        model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
                        currentIndex: (Chiaki.settings.fpsLocalPS5 / 30) - 1
                        onActivated: (index) => Chiaki.settings.fpsLocalPS5 = (index + 1) * 30
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        KeyNavigation.up: resolutionLocalPS5
                        KeyNavigation.right: fpsRemotePS5
                        KeyNavigation.down: bitrateLocalPS5
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    C.ComboBox {
                        id: fpsRemotePS5
                        Layout.preferredWidth: 400
                        model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
                        currentIndex: (Chiaki.settings.fpsRemotePS5 / 30) - 1
                        onActivated: (index) => Chiaki.settings.fpsRemotePS5 = (index + 1) * 30
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        KeyNavigation.up: resolutionRemotePS5
                        KeyNavigation.left: fpsLocalPS5
                        KeyNavigation.down: bitrateRemotePS5
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Bitrate:")
                        font.weight: Font.Medium
                        opacity: 0.92
                    }

                    C.Slider {
                        id: bitrateLocalPS4
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        property var bitrate: {
                            var rate = 0;
                            switch (Chiaki.settings.resolutionLocalPS4) {
                            case 1: rate = 2; break; // 360p
                            case 2: rate = 6; break; // 540p
                            case 3: rate = 10; break; // 720p
                            case 4: rate = 15; break; // 1080p
                            }
                            return rate;
                        }
                        Layout.preferredWidth: 200
                        from: 2
                        to: 100
                        stepSize: 1
                        value: Chiaki.settings.bitrateLocalPS4 / 1000 ? (Chiaki.settings.bitrateLocalPS4 / 1000) : bitrate
                        onMoved: Chiaki.settings.bitrateLocalPS4 = value * 1000;
                        KeyNavigation.up: fpsLocalPS4
                        KeyNavigation.down: bitrateLocalPS4
                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        Label {
                            anchors {
                                left: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
                        }
                    }

                    C.Slider {
                        id: bitrateRemotePS4
                        visible: selectedConsole == SettingsDialog.Console.PS4
                        property var bitrate: {
                            var rate = 0;
                            switch (Chiaki.settings.resolutionRemotePS4) {
                            case 1: rate = 2; break; // 360p
                            case 2: rate = 6; break; // 540p
                            case 3: rate = 10; break; // 720p
                            case 4: rate = 15; break; // 1080p
                            }
                            return rate;
                        }
                        Layout.preferredWidth: 200
                        from: 2
                        to: 100
                        stepSize: 1
                        value: Chiaki.settings.bitrateRemotePS4 / 1000 ? (Chiaki.settings.bitrateRemotePS4 / 1000) : bitrate
                        onMoved: Chiaki.settings.bitrateRemotePS4 = value * 1000;
                        KeyNavigation.up: fpsRemotePS4
                        KeyNavigation.down: bitrateRemotePS4
                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        lastInFocusChain: true

                        Label {
                            anchors {
                                left: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
                        }
                    }

                    C.Slider {
                        id: bitrateLocalPS5
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        property var bitrate: {
                            var rate = 0;
                            switch (Chiaki.settings.resolutionLocalPS5) {
                            case 1: rate = 2; break; // 360p
                            case 2: rate = 6; break; // 540p
                            case 3: rate = 10; break; // 720p
                            case 4: rate = 15; break; // 1080p
                            }
                            return rate;
                        }
                        Layout.preferredWidth: 200
                        from: 2
                        to: 100
                        stepSize: 1
                        value: Chiaki.settings.bitrateLocalPS5 / 1000 ? (Chiaki.settings.bitrateLocalPS5 / 1000) : bitrate
                        onMoved: Chiaki.settings.bitrateLocalPS5 = value * 1000;
                        KeyNavigation.up: fpsLocalPS5
                        KeyNavigation.down: codecLocalPS5
                        KeyNavigation.priority: KeyNavigation.BeforeItem

                        Label {
                            anchors {
                                left: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
                        }
                    }

                    C.Slider {
                        id: bitrateRemotePS5
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        property var bitrate: {
                            var rate = 0;
                            switch (Chiaki.settings.resolutionRemotePS5) {
                            case 1: rate = 2; break; // 360p
                            case 2: rate = 6; break; // 540p
                            case 3: rate = 10; break; // 720p
                            case 4: rate = 15; break; // 1080p
                            }
                            return rate;
                        }
                        Layout.preferredWidth: 200
                        from: 2
                        to: 100
                        stepSize: 1
                        value: Chiaki.settings.bitrateRemotePS5 / 1000 ? (Chiaki.settings.bitrateRemotePS5 / 1000) : bitrate
                        onMoved: Chiaki.settings.bitrateRemotePS5 = value * 1000;
                        KeyNavigation.up: fpsRemotePS5
                        KeyNavigation.down: codecRemotePS5
                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        lastInFocusChain: true

                        Label {
                            anchors {
                                left: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: 10
                            }
                            text: (parent.value) + qsTr(" Mbps") + qsTr(" (%1 Mbps)").arg(parent.bitrate.toFixed(0))
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: 180
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.WordWrap
                        text: qsTr("Codec:")
                        font.weight: Font.Medium
                        opacity: 0.92
                        visible: selectedConsole == SettingsDialog.Console.PS5
                    }

                    C.ComboBox {
                        id: codecLocalPS5
                        Layout.preferredWidth: 400
                        property bool openGlBackend: Chiaki.settings.rendererBackend === 1
						model: openGlBackend ? [qsTr("H264"), qsTr("H265 (Default)")] : [qsTr("H264"), qsTr("H265 (Default)"), qsTr("H265 HDR")]
                        currentIndex: Chiaki.settings.codecLocalPS5
                        onActivated: (index) => Chiaki.settings.codecLocalPS5 = index
                        visible: selectedConsole == SettingsDialog.Console.PS5
                        Keys.onReturnPressed: {
                            if (popup.visible) {
                                activated(highlightedIndex);
                                popup.close();
                            } else
                                popup.open();
                        }
                        KeyNavigation.up: bitrateLocalPS5
                        KeyNavigation.right: codecRemotePS5
                        KeyNavigation.down: codecLocalPS5
                        KeyNavigation.priority: {
                            if(!popup.visible)
                                KeyNavigation.BeforeItem
                            else
                                KeyNavigation.AfterItem
                        }
                    }

                        C.ComboBox {
                            id: codecRemotePS5
                            Layout.preferredWidth: 400
                        property bool openGlBackend: Chiaki.settings.rendererBackend === 1
                        model: openGlBackend ? [qsTr("H264"), qsTr("H265 (Default)")] : [qsTr("H264"), qsTr("H265 (Default)"), qsTr("H265 HDR")]
                            currentIndex: Chiaki.settings.codecRemotePS5
                            onActivated: (index) => Chiaki.settings.codecRemotePS5 = index
                            visible: selectedConsole == SettingsDialog.Console.PS5
                            lastInFocusChain: true
                            Keys.onReturnPressed: {
                                if (popup.visible) {
                                    activated(highlightedIndex);
                                    popup.close();
                                } else
                                    popup.open();
                            }
                            KeyNavigation.up: bitrateRemotePS5
                            KeyNavigation.left: codecLocalPS5
                            KeyNavigation.priority: {
                                if(!popup.visible)
                                    KeyNavigation.BeforeItem
                                else
                                    KeyNavigation.AfterItem
                            }
                        }

                        // petite légende sous le codec, alignée sous les deux menus
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 180 + 24
                            Layout.preferredWidth: 824
                            Layout.topMargin: -4
                            visible: selectedConsole == SettingsDialog.Console.PS5
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("The codec is how the console compresses the picture before sending it. H265 gives a better picture for the same bitrate; H264 is lighter for the Mac and can lower the delay slightly.")
                        }
                    }
                }
            }

            Item {
                // Audio and Wifi
                Flickable {
                    id: audiowifiFlick
                    anchors {
                        fill: parent
                        topMargin: 20
                        bottomMargin: 20
                    }
                    clip: true
                    contentWidth: width
                    contentHeight: (audiowifigrid.height * audiowifigrid.scale) + 10
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    ScrollBar.vertical: C.PsScrollBar {
                        id: audiowifiScrollbar
                        policy: ScrollBar.AsNeeded
                        visible: audiowifiFlick.contentHeight > audiowifiFlick.height
                    }
                    GridLayout {
                        id: audiowifigrid
                        // fenêtre étroite : la grille rétrécit d'un bloc au lieu de déborder sur le côté
                        scale: Math.min(1, (parent.width - 40) / Math.max(1, width))
                        transformOrigin: Item.Top
                        columns: 3
                        rowSpacing: 14
                        columnSpacing: 24
                        onVisibleChanged: if (visible) Chiaki.settings.refreshAudioDevices()

                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.topMargin: 12
                            text: qsTr("SOUND")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }
                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Output Device:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.ComboBox {
                            id: audioOutDevice
                            Layout.preferredWidth: 400
                            popup.x: (width - popup.width) / 2
                            popup.width: 700
                            popup.font.pixelSize: 16
                            firstInFocusChain: true
                            model: [qsTr("Auto")].concat(Chiaki.settings.availableAudioOutDevices)
                            currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioOutDevice))
                            onActivated: (index) => Chiaki.settings.audioOutDevice = index ? model[index] : ""
                            KeyNavigation.down: audioInDevice
                            KeyNavigation.priority: popup.visible ? KeyNavigation.AfterItem : KeyNavigation.BeforeItem
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Auto)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Input Device:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.ComboBox {
                            id: audioInDevice
                            Layout.preferredWidth: 400
                            popup.x: (width - popup.width) / 2
                            popup.width: 700
                            popup.font.pixelSize: 16
                            model: [qsTr("Auto")].concat(Chiaki.settings.availableAudioInDevices)
                            currentIndex: Math.max(0, model.indexOf(Chiaki.settings.audioInDevice))
                            onActivated: (index) => Chiaki.settings.audioInDevice = index ? model[index] : ""
                            KeyNavigation.up: audioOutDevice
                            KeyNavigation.down: audioBufferSizeSlider
                            KeyNavigation.priority: popup.visible ? KeyNavigation.AfterItem : KeyNavigation.BeforeItem
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Auto)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Audio Buffer Size:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.Slider {
                            id: audioBufferSizeSlider
                            Layout.preferredWidth: 250
                            from: 1
                            to: 10
                            stepSize: 1
                            value: Chiaki.settings.audioBufferSize / 1920 ? (Chiaki.settings.audioBufferSize / 1920) : 5
                            onMoved: Chiaki.settings.audioBufferSize = value * 1920;
                            KeyNavigation.up: audioInDevice

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: {
                                    (parent.value * 10).toFixed(0) + qsTr(" ms")
                                }
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(50 ms)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("Sound memory before playback. Bigger avoids crackling on a weak network but adds a little delay.")
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Audio Volume:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.Slider {
                            Layout.preferredWidth: 250
                            from: 0
                            to: 128
                            stepSize: 1
                            value: Chiaki.settings.audioVolume
                            onMoved: Chiaki.settings.audioVolume = value

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: {
                                    ((parent.value / 128.0) * 100).toFixed(0) + qsTr("% volume")
                                }
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(100%)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Start Mic Unmuted:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.CheckBox {
                            checked: Chiaki.settings.startMicUnmuted
                            onToggled: Chiaki.settings.startMicUnmuted = checked
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Unchecked)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Speech Processing:")
                            font.weight: Font.Medium
                            opacity: 0.92
                            visible: typeof Chiaki.settings.speechProcessing !== "undefined"
                        }

                        C.CheckBox {
                            text: qsTr("Noise suppression + echo cancellation")
                            checked: Chiaki.settings.speechProcessing
                            onToggled: Chiaki.settings.speechProcessing = !Chiaki.settings.speechProcessing
                            visible: typeof Chiaki.settings.speechProcessing !== "undefined"
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Unchecked)")
                            opacity: 0.45
                            font.pixelSize: 15
                            visible: typeof Chiaki.settings.speechProcessing !== "undefined"
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {true} else {false}
                            text: qsTr("Cleans up your voice on the microphone: removes background noise and echo.")
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Noise To Suppress:")
                            font.weight: Font.Medium
                            opacity: 0.92
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                        }

                        C.Slider {
                            Layout.preferredWidth: 250
                            from: 0
                            to: 60
                            stepSize: 1
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                            value: Chiaki.settings.noiseSuppressLevel
                            onMoved: Chiaki.settings.noiseSuppressLevel = value

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: qsTr("%1 dB").arg(parent.value)
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(6 dB)")
                            opacity: 0.45
                            font.pixelSize: 15
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Echo To Suppress:")
                            font.weight: Font.Medium
                            opacity: 0.92
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                        }

                        C.Slider {
                            Layout.preferredWidth: 250
                            from: 0
                            to: 60
                            stepSize: 1
                            value: Chiaki.settings.echoSuppressLevel
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                            onMoved: Chiaki.settings.echoSuppressLevel = value

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: qsTr("%1 dB").arg(parent.value)
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(30 dB)")
                            opacity: 0.45
                            font.pixelSize: 15
                            visible: if (typeof Chiaki.settings.speechProcessing !== "undefined") {Chiaki.settings.speechProcessing} else {false}
                        }

                        Label {
                            Layout.columnSpan: 3
                            Layout.topMargin: 12
                            text: qsTr("WI-FI AND NETWORK")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }
                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Weak Wifi Notification:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.Slider {
                            Layout.preferredWidth: 250
                            from: 0
                            to: 100
                            stepSize: 1
                            value: Chiaki.settings.wifiDroppedNotif
                            onMoved: Chiaki.settings.wifiDroppedNotif = value

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: qsTr(">= %1% dropped packets").arg(parent.value)
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(3%)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("Shows a warning during the game when too many images are lost on the way.")
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            text: qsTr("Packet Loss Reported Max:")
                            font.weight: Font.Medium
                            opacity: 0.92
                        }

                        C.Slider {
                            Layout.preferredWidth: 250
                            from: 0
                            to: 100
                            stepSize: 1
                            value: Chiaki.settings.packetLossReportedMax
                            onMoved: Chiaki.settings.packetLossReportedMax = value

                            Label {
                                anchors {
                                    left: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 10
                                }
                                text: qsTr("%1% packet loss").arg(parent.value)
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(5%)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("Caps the losses reported to the console. Lower keeps the picture quality; higher lets the console lower quality faster to stay smooth.")
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            font.weight: Font.Medium
                            opacity: 0.92
                            text: qsTr("Request IDR Frame on FEC Failure")
                        }

                        C.CheckBox {
                            checked: Chiaki.settings.iDROnFECFailureEnabled
                            onToggled: Chiaki.settings.iDROnFECFailureEnabled = !Chiaki.settings.iDROnFECFailureEnabled
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Unchecked)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("When the picture gets corrupted, asks the console for a complete new image to fix it quickly.")
                        }

                        Label {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.preferredWidth: 360
                            horizontalAlignment: Text.AlignRight
                            wrapMode: Text.WordWrap
                            font.weight: Font.Medium
                            opacity: 0.92
                            text: qsTr("Show Stream Stats During Gameplay")
                        }

                        C.CheckBox {
                            lastInFocusChain: true
                            checked: Chiaki.settings.showStreamStats
                            onToggled: Chiaki.settings.showStreamStats = !Chiaki.settings.showStreamStats
                        }

                        Label {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            Layout.preferredWidth: 230
                            elide: Text.ElideRight
                            text: qsTr("(Unchecked)")
                            opacity: 0.45
                            font.pixelSize: 15
                        }
                        Label {
                            Layout.columnSpan: 3
                            Layout.leftMargin: 384
                            Layout.preferredWidth: 654
                            Layout.topMargin: -6
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.5
                            text: qsTr("Shows bitrate, losses and delay in a corner of the screen while playing.")
                        }
                    }
                }
            }

            Item {
                // Consoles
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
                            onClicked: root.showRegistDialog("255.255.255.255", true)
                        }

                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("%1 / %2 consoles · 2 at most").arg(Chiaki.consoles.registeredCount).arg(Chiaki.consoles.maxConsoles)
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

            Item {
                // Keys
                id: controllerMapping
                // sous-onglet : 0 = manette, 1 = clavier et souris
                property int keysSubTab: 0
                onKeysSubTabChanged: Qt.callLater(dialog.focusCurrentTabFirstItem)

                // sélecteur « Manette » / « Clavier et souris », même contour néon que « L'essentiel »
                Rectangle {
                    id: keysSwitch
                    anchors { top: parent.top; topMargin: 18; horizontalCenter: parent.horizontalCenter }
                    width: 420
                    height: 40
                    radius: height / 2
                    color: Qt.rgba(0.03, 0.07, 0.17, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(0.6, 0.75, 1, 0.22)

                    Rectangle {
                        width: parent.width / 2 - 6
                        height: parent.height - 8
                        y: 4
                        x: controllerMapping.keysSubTab === 0 ? 4 : parent.width / 2 + 2
                        radius: height / 2
                        color: Qt.rgba(0.0, 0.27, 0.75, 0.12)
                        border.width: 2
                        border.color: "#3d7bff"
                        Behavior on x { SpringAnimation { spring: 3; damping: 0.3; epsilon: 0.25 } }
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: [qsTr("Controller"), qsTr("Keyboard and mouse")]
                            delegate: Label {
                                required property int index
                                required property string modelData
                                width: keysSwitch.width / 2
                                height: keysSwitch.height
                                text: modelData
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 15
                                readonly property bool active: index === controllerMapping.keysSubTab
                                font.weight: active ? Font.DemiBold : Font.Normal
                                color: active ? "#9cc2ff" : "#ffffff"
                                opacity: active ? 1.0 : 0.6
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: controllerMapping.keysSubTab = index
                                }
                            }
                        }
                    }
                }

                // ——— sous-onglet Manette ———
                Flickable {
                    id: padFlick
                    visible: controllerMapping.keysSubTab === 0
                    anchors {
                        top: keysSwitch.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        topMargin: 12
                        bottomMargin: 20
                    }
                    clip: true
                    contentWidth: width
                    contentHeight: padColumn.implicitHeight + 20
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    ScrollBar.vertical: C.PsScrollBar {
                        visible: padFlick.contentHeight > padFlick.height
                    }

                    ColumnLayout {
                        id: padColumn
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: Math.min(padFlick.width - 60, 1150)
                        spacing: 10

                        Label {
                            text: qsTr("WHAT EACH BUTTON DOES")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }

                        // schéma de la manette : chaque bouton relié par un trait à ce qu'il fait
                        Item {
                            id: padDiagram
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 480 / 1400
                            readonly property real s: width / 1400
                            // position du dessin de la manette dans le schéma
                            readonly property real ox: 400
                            readonly property real oy: 70
                            // ancre = point du bouton (repère de la manette), ly = hauteur de la légende
                            // affectation enregistrée de la manette (bouton physique -> action), relue quand elle peut changer
                            readonly property var remap: {
                                Chiaki.controllerMapping.inProgress;
                                Chiaki.controllers;
                                bar.currentIndex;
                                return Chiaki.controllerMapping.physicalButtonActions();
                            }
                            // titre et rôle de chaque action PlayStation
                            function describe(action) {
                                switch (action) {
                                case 1: return { title: "✕  " + qsTr("Cross"), text: qsTr("Confirm") };
                                case 2: return { title: "○  " + qsTr("Circle"), text: qsTr("Back, cancel") };
                                case 4: return { title: "□  " + qsTr("Square"), text: qsTr("Game action") };
                                case 8: return { title: "△  " + qsTr("Triangle"), text: qsTr("Game action") };
                                case 256: return { title: "L1", text: qsTr("Depends on the game") };
                                case 512: return { title: "R1", text: qsTr("Depends on the game") };
                                case 65536: return { title: "L2", text: qsTr("Trigger: brake, aim…") };
                                case 131072: return { title: "R2", text: qsTr("Trigger: accelerate, shoot…") };
                                case 1024: return { title: "L3", text: qsTr("Press (L3)") };
                                case 2048: return { title: "R3", text: qsTr("Press (R3)") };
                                case 4096: return { title: qsTr("Options"), text: qsTr("Game menu (pause)") };
                                case 8192: return { title: qsTr("Share / Create"), text: qsTr("Screenshot or video clip") };
                                case 16384: return { title: qsTr("Touchpad"), text: qsTr("Press and swipe") };
                                case 32768: return { title: qsTr("PS button"), text: qsTr("Console menu (home screen)") };
                                case 64: return { title: "↑", text: qsTr("D-pad") };
                                case 128: return { title: "↓", text: qsTr("D-pad") };
                                case 16: return { title: "←", text: qsTr("D-pad") };
                                case 32: return { title: "→", text: qsTr("D-pad") };
                                case 0: return { title: "—", text: qsTr("No action") };
                                default: return { title: "?", text: "" };
                                }
                            }
                            // ancre = point du bouton (repère de la manette), ly = hauteur de la légende,
                            // phys = bouton physique (sa légende suit l'affectation), def = son action d'origine
                            readonly property var positions: [
                                { side: "left", ax: 155, ay: 37, ly: 100, phys: "a4", def: 65536, flags: [65536] },
                                { side: "left", ax: 155, ay: 59, ly: 140, phys: "b9", def: 256, flags: [256] },
                                { side: "left", ax: 205, ay: 95, ly: 185, phys: "b4", def: 8192, flags: [8192] },
                                { side: "left", ax: 140, ay: 150, ly: 230, title: qsTr("D-pad"), text: qsTr("Menus and game shortcuts"), flags: [64, 128, 16, 32] },
                                { side: "left", ax: 215, ay: 215, ly: 300, title: qsTr("Left stick · L3"), text: qsTr("Move · press: L3"), flags: [1024] },
                                { side: "right", ax: 445, ay: 37, ly: 100, phys: "a5", def: 131072, flags: [131072] },
                                { side: "right", ax: 445, ay: 59, ly: 140, phys: "b10", def: 512, flags: [512] },
                                { side: "right", ax: 395, ay: 95, ly: 180, phys: "b6", def: 4096, flags: [4096] },
                                { side: "right", ax: 460, ay: 118, ly: 220, phys: "b3", def: 8, flags: [8] },
                                { side: "right", ax: 492, ay: 150, ly: 255, phys: "b1", def: 2, flags: [2] },
                                { side: "right", ax: 460, ay: 182, ly: 290, phys: "b0", def: 1, flags: [1] },
                                { side: "right", ax: 428, ay: 150, ly: 325, phys: "b2", def: 4, flags: [4] },
                                { side: "right", ax: 385, ay: 215, ly: 365, title: qsTr("Right stick · R3"), text: qsTr("Camera · press: R3"), flags: [2048] },
                                { side: "top", ax: 300, ay: 85, ly: 32, phys: "b11", def: 16384, flags: [16384] },
                                { side: "bottom", ax: 300, ay: 200, ly: 455, phys: "b5", def: 32768, flags: [32768] }
                            ]
                            // ce que fait un bouton dans les menus de l'appli, s'il a été changé (Boutons dans l'appli)
                            function appChange(flag) {
                                navPrefs.navMapping;
                                const now = controllerMapping.navRoleOf(flag);
                                let before = "";
                                for (const a of controllerMapping.navAll())
                                    if (a.def === flag)
                                        before = a.role;
                                return now === before ? null : (now || qsTr("nothing"));
                            }
                            readonly property var legends: positions.map(p => {
                                let out = Object.assign({ changed: false }, p);
                                if (p.phys) {
                                    const known = Object.keys(remap).length > 0;
                                    const action = known ? (remap[p.phys] || remap["+" + p.phys] || 0) : p.def;
                                    const d = describe(action);
                                    out = Object.assign(out, { title: d.title, text: d.text, changed: action !== p.def, gameChanged: action !== p.def });
                                }
                                // réglages de l'appli : « Dans l'appli : … » en orange
                                let notes = [];
                                for (const f of p.flags) {
                                    const role = appChange(f);
                                    if (role !== null)
                                        notes.push((p.flags.length > 1 ? keysFlick.keyInfo(f, "").glyph + " " : "") + role);
                                }
                                if (notes.length)
                                    out = Object.assign(out, { text: qsTr("In the app: %1").arg(notes.join(", ")), changed: true });
                                return out;
                            })
                            onWidthChanged: padCanvas.requestPaint()

                            Canvas {
                                id: padCanvas
                                anchors.fill: parent
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.reset();
                                    ctx.scale(padDiagram.s, padDiagram.s);
                                    const ox = padDiagram.ox, oy = padDiagram.oy;
                                    ctx.translate(ox, oy);
                                    // trait néon : cœur clair + halo bleu
                                    ctx.lineJoin = "round";
                                    ctx.lineCap = "round";
                                    ctx.strokeStyle = "#5b8fe0";
                                    ctx.shadowColor = "#0046c0";
                                    ctx.shadowBlur = 14;
                                    ctx.lineWidth = 3;
                                    // corps de la manette
                                    ctx.beginPath();
                                    ctx.moveTo(150, 80);
                                    ctx.bezierCurveTo(200, 66, 400, 66, 450, 80);
                                    ctx.bezierCurveTo(520, 96, 560, 150, 575, 230);
                                    ctx.bezierCurveTo(590, 310, 565, 350, 525, 345);
                                    ctx.bezierCurveTo(495, 342, 475, 310, 450, 275);
                                    ctx.bezierCurveTo(430, 250, 400, 245, 300, 245);
                                    ctx.bezierCurveTo(200, 245, 170, 250, 150, 275);
                                    ctx.bezierCurveTo(125, 310, 105, 342, 75, 345);
                                    ctx.bezierCurveTo(35, 350, 10, 310, 25, 230);
                                    ctx.bezierCurveTo(40, 150, 80, 96, 150, 80);
                                    ctx.closePath();
                                    ctx.fillStyle = Qt.rgba(0.0, 0.27, 0.75, 0.08);
                                    ctx.fill();
                                    ctx.stroke();
                                    function roundRect(x, y, w, h, r) {
                                        ctx.beginPath();
                                        ctx.moveTo(x + r, y);
                                        ctx.arcTo(x + w, y, x + w, y + h, r);
                                        ctx.arcTo(x + w, y + h, x, y + h, r);
                                        ctx.arcTo(x, y + h, x, y, r);
                                        ctx.arcTo(x, y, x + w, y, r);
                                        ctx.closePath();
                                        ctx.stroke();
                                    }
                                    function circle(x, y, r) {
                                        ctx.beginPath();
                                        ctx.arc(x, y, r, 0, Math.PI * 2);
                                        ctx.stroke();
                                    }
                                    // gâchettes et boutons du haut
                                    roundRect(115, 28, 80, 18, 9);
                                    roundRect(405, 28, 80, 18, 9);
                                    roundRect(110, 52, 90, 14, 7);
                                    roundRect(400, 52, 90, 14, 7);
                                    // pavé tactile, Share, Options, PS
                                    roundRect(225, 85, 150, 75, 12);
                                    roundRect(197, 88, 16, 26, 8);
                                    roundRect(387, 88, 16, 26, 8);
                                    circle(300, 200, 12);
                                    // croix directionnelle
                                    ctx.beginPath();
                                    const dx = 140, dy = 150, a = 11, l = 30;
                                    ctx.moveTo(dx - a, dy - l); ctx.lineTo(dx + a, dy - l); ctx.lineTo(dx + a, dy - a);
                                    ctx.lineTo(dx + l, dy - a); ctx.lineTo(dx + l, dy + a); ctx.lineTo(dx + a, dy + a);
                                    ctx.lineTo(dx + a, dy + l); ctx.lineTo(dx - a, dy + l); ctx.lineTo(dx - a, dy + a);
                                    ctx.lineTo(dx - l, dy + a); ctx.lineTo(dx - l, dy - a); ctx.lineTo(dx - a, dy - a);
                                    ctx.closePath();
                                    ctx.stroke();
                                    // sticks
                                    circle(215, 215, 30);
                                    circle(215, 215, 18);
                                    circle(385, 215, 30);
                                    circle(385, 215, 18);
                                    // boutons de façade et leurs symboles
                                    for (const b of [[460, 118], [492, 150], [460, 182], [428, 150]])
                                        circle(b[0], b[1], 14);
                                    ctx.lineWidth = 2.2;
                                    ctx.beginPath(); // △
                                    ctx.moveTo(460, 111); ctx.lineTo(467, 123); ctx.lineTo(453, 123); ctx.closePath();
                                    ctx.stroke();
                                    circle(492, 150, 6.5); // ○
                                    ctx.beginPath(); // ✕
                                    ctx.moveTo(454, 176); ctx.lineTo(466, 188); ctx.moveTo(466, 176); ctx.lineTo(454, 188);
                                    ctx.stroke();
                                    ctx.beginPath(); // □
                                    ctx.rect(422, 144, 12, 12);
                                    ctx.stroke();

                                    // traits vers les légendes
                                    ctx.translate(-ox, -oy);
                                    ctx.shadowBlur = 0;
                                    ctx.lineWidth = 1.4;
                                    ctx.strokeStyle = Qt.rgba(0.61, 0.76, 1, 0.45);
                                    ctx.fillStyle = "#9cc2ff";
                                    for (const g of padDiagram.legends) {
                                        const x = ox + g.ax, y = oy + g.ay;
                                        ctx.beginPath();
                                        ctx.moveTo(x, y);
                                        if (g.side === "left") {
                                            ctx.lineTo(400, g.ly);
                                            ctx.lineTo(382, g.ly);
                                        } else if (g.side === "right") {
                                            ctx.lineTo(1000, g.ly);
                                            ctx.lineTo(1018, g.ly);
                                        } else {
                                            ctx.lineTo(x, g.ly + (g.side === "top" ? 12 : -12));
                                        }
                                        ctx.stroke();
                                        ctx.beginPath();
                                        ctx.arc(x, y, 3.5, 0, Math.PI * 2);
                                        ctx.fill();
                                    }
                                }
                            }

                            Repeater {
                                model: padDiagram.legends
                                Label {
                                    required property var modelData
                                    readonly property real s: padDiagram.s
                                    textFormat: Text.RichText
                                    text: "<b><font color='" + (modelData.changed ? "#ffc46b" : "#9cc2ff") + "'>" + modelData.title + "</font></b>&nbsp;&nbsp;"
                                        + (modelData.changed ? "<font color='#ffc46b'>" + modelData.text + "</font>" : modelData.text)
                                    font.pixelSize: Math.max(12, 15 * s)
                                    x: modelData.side === "left" ? 374 * s - width
                                        : modelData.side === "right" ? 1026 * s
                                        : (padDiagram.ox + modelData.ax) * s - width / 2
                                    y: modelData.ly * s - height / 2
                                }
                            }
                        }

                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 4
                            text: qsTr("During a game, open the Mac'n'Play menu by pressing %1 together.").arg(controllerMapping.streamMenuCombo())
                            font.pixelSize: 15
                            opacity: 0.7
                        }

                        Label {
                            Layout.topMargin: 22
                            text: qsTr("BUTTONS IN THE APP")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr("Click a button, then press the new button on your controller. The small box adds a second button for the same action. This only changes the Mac'n'Play menus: in game, the controller stays normal.")
                            font.pixelSize: 15
                            opacity: 0.6
                        }

                        Repeater {
                            model: controllerMapping.navGroups

                            ColumnLayout {
                                id: navSection
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                spacing: 10

                                Label {
                                    text: navSection.modelData.title
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.0
                                    opacity: 0.6
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 14
                                    rowSpacing: 12

                                    Repeater {
                                        model: navSection.modelData.actions

                                        // [bouton de la manette ▾] → action dans l'appli
                                        Rectangle {
                                            id: navCard
                                            required property var modelData
                                            readonly property var slots: controllerMapping.navSlots(modelData.key)
                                            readonly property int flag: slots[0]
                                            readonly property int second: slots[1]
                                            readonly property var info: keysFlick.keyInfo(flag, "?")
                                            readonly property var secondInfo: keysFlick.keyInfo(second, "?")
                                            readonly property bool changed: flag !== modelData.def || second !== 0
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 68
                                            radius: 16
                                            readonly property bool focused: navButton.visualFocus || navSecond.visualFocus
                                            color: Qt.rgba(0.35, 0.55, 1, focused ? 0.13 : 0.05)
                                            border.width: focused ? 2 : 1
                                            border.color: focused ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.16)

                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                                                spacing: 14

                                                C.Button {
                                                    id: navButton
                                                    property bool keysNav: true
                                                    readonly property int navKey: navCard.modelData.key
                                                    readonly property int navSlot: 0
                                                    navHandler: controllerMapping.padNav
                                                    Layout.preferredWidth: 120
                                                    Layout.preferredHeight: 46
                                                    topInset: 0
                                                    bottomInset: 0
                                                    leftPadding: 12
                                                    rightPadding: 12
                                                    contentItem: RowLayout {
                                                        spacing: 6
                                                        Item {
                                                            Layout.fillWidth: true
                                                            Layout.fillHeight: true
                                                            Image {
                                                                anchors.centerIn: parent
                                                                visible: !!navCard.info.icon
                                                                width: 26
                                                                height: 26
                                                                sourceSize: Qt.size(52, 52)
                                                                source: navCard.info.icon || ""
                                                            }
                                                            Text {
                                                                anchors.centerIn: parent
                                                                visible: !navCard.info.icon
                                                                text: navCard.info.glyph || ""
                                                                color: "#9cc2ff"
                                                                font.pixelSize: text.length > 1 ? 15 : 22
                                                                font.bold: true
                                                            }
                                                        }
                                                        Text {
                                                            text: "▾"
                                                            color: "#9cc2ff"
                                                            font.pixelSize: 14
                                                        }
                                                    }
                                                    background: Rectangle {
                                                        radius: 12
                                                        color: Qt.rgba(0.35, 0.55, 1, navButton.down ? 0.22 : (navButton.hovered ? 0.16 : 0.10))
                                                        border.width: navButton.visualFocus ? 2 : 1
                                                        border.color: navButton.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.28)
                                                    }
                                                    onActiveFocusChanged: if (activeFocus) controllerMapping.padEnsureVisible(navCard)
                                                    onClicked: navPicker.show(navCard.modelData.key, navCard.modelData.role, navCard.flag, 0)
                                                }

                                                // second bouton (facultatif) : « + » tant qu'il est vide
                                                C.Button {
                                                    id: navSecond
                                                    property bool keysNav: true
                                                    readonly property int navKey: navCard.modelData.key
                                                    readonly property int navSlot: 1
                                                    readonly property bool filled: navCard.second !== 0
                                                    navHandler: controllerMapping.padNav
                                                    Layout.preferredWidth: 52
                                                    Layout.preferredHeight: 46
                                                    topInset: 0
                                                    bottomInset: 0
                                                    leftPadding: 4
                                                    rightPadding: 4
                                                    contentItem: Item {
                                                        Image {
                                                            anchors.centerIn: parent
                                                            visible: navSecond.filled && !!navCard.secondInfo.icon
                                                            width: 22
                                                            height: 22
                                                            sourceSize: Qt.size(44, 44)
                                                            source: navSecond.filled ? (navCard.secondInfo.icon || "") : ""
                                                        }
                                                        Text {
                                                            anchors.centerIn: parent
                                                            visible: !navSecond.filled || !navCard.secondInfo.icon
                                                            text: navSecond.filled ? (navCard.secondInfo.glyph || "") : "+"
                                                            color: navSecond.filled ? "#9cc2ff" : "#eef4ff"
                                                            opacity: navSecond.filled ? 1 : 0.55
                                                            font.pixelSize: navSecond.filled ? (text.length > 1 ? 12 : 18) : 20
                                                            font.bold: navSecond.filled
                                                        }
                                                    }
                                                    background: Rectangle {
                                                        radius: 12
                                                        color: Qt.rgba(0.35, 0.55, 1, navSecond.down ? 0.22 : (navSecond.hovered ? 0.16 : (navSecond.filled ? 0.10 : 0.04)))
                                                        border.width: navSecond.visualFocus ? 2 : 1
                                                        border.color: navSecond.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, navSecond.filled ? 0.28 : 0.18)
                                                    }
                                                    // retirer le second bouton : bouton « Supprimer » de la manette (□ d'origine) ou petit ×
                                                    Keys.onNoPressed: (event) => {
                                                        if (navSecond.filled)
                                                            controllerMapping.navRemoveSecond(navKey);
                                                        event.accepted = true;
                                                    }
                                                    Rectangle {
                                                        visible: navSecond.filled
                                                        anchors { top: parent.top; right: parent.right; topMargin: -7; rightMargin: -7 }
                                                        width: 20
                                                        height: 20
                                                        radius: 10
                                                        color: navRemoveArea.containsMouse ? "#c0392b" : "#3a1a28"
                                                        border.width: 1
                                                        border.color: Qt.rgba(1, 0.55, 0.6, 0.7)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "×"
                                                            color: "white"
                                                            font.pixelSize: 14
                                                            font.bold: true
                                                        }
                                                        MouseArea {
                                                            id: navRemoveArea
                                                            anchors.fill: parent
                                                            anchors.margins: -4
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: controllerMapping.navRemoveSecond(navSecond.navKey)
                                                        }
                                                    }
                                                    onActiveFocusChanged: if (activeFocus) controllerMapping.padEnsureVisible(navCard)
                                                    onClicked: navPicker.show(navCard.modelData.key, navCard.modelData.role, navCard.second, 1)
                                                }

                                                Text {
                                                    text: "→"
                                                    color: "#9cc2ff"
                                                    opacity: 0.6
                                                    font.pixelSize: 20
                                                }
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: navCard.modelData.role
                                                    font.pixelSize: 17
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                // pastille quand l'action n'est plus sur son bouton d'origine
                                                Rectangle {
                                                    visible: navCard.changed
                                                    Layout.preferredWidth: navChanged.implicitWidth + 16
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Qt.rgba(1, 0.77, 0.42, 0.14)
                                                    border.width: 1
                                                    border.color: "#ffc46b"
                                                    Label {
                                                        id: navChanged
                                                        anchors.centerIn: parent
                                                        text: qsTr("Changed")
                                                        font.pixelSize: 12
                                                        color: "#ffc46b"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // en bas, au milieu : remettre les boutons d'origine
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 28
                            spacing: 16
                            C.Button {
                                id: navReset
                                property bool keysNav: true
                                navHandler: controllerMapping.padNav
                                enabled: navPrefs.navMapping !== ""
                                opacity: enabled ? 1 : 0.45
                                text: "↺  " + qsTr("Reset the buttons")
                                onClicked: navPrefs.navMapping = ""
                            }
                            // l'ancienne affectation (manette entière, jeux compris) : seulement pour l'annuler
                            C.Button {
                                id: controllerMappingReset
                                property bool keysNav: true
                                navHandler: controllerMapping.padNav
                                visible: padDiagram.legends.some(l => l.gameChanged)
                                text: "↺  " + qsTr("Restore the controller for games")
                                onClicked: controllerMappingDialog.show({
                                    reset: true
                                });
                            }
                            // conservé pour l'enchaînement de la fenêtre de capture (plus affiché)
                            C.Button {
                                id: controllerMappingChange
                                visible: false
                                onClicked: controllerMappingDialog.show({
                                    reset: false
                                });
                            }
                        }
                    }
                }
                // ——— boutons de navigation dans l'appli (lus par le pont manette, jamais envoyés en jeu) ———
                Settings {
                    id: navPrefs
                    category: "macnplay"
                    property string navMapping: ""
                }
                // chaque action = une touche envoyée aux menus ; def = bouton d'origine
                readonly property var navGroups: [
                    { title: qsTr("MENUS"), actions: [
                        { key: Qt.Key_Return, def: 1, role: qsTr("Selection") },
                        { key: Qt.Key_Escape, def: 2, role: qsTr("Back") },
                        { key: Qt.Key_Yes, def: 8, role: qsTr("Wake the console · switch view") },
                        { key: Qt.Key_No, def: 4, role: qsTr("Delete a console") },
                        { key: Qt.Key_Menu, def: 4096, role: qsTr("Open / close settings") },
                        { key: Qt.Key_F2, def: 2048, role: qsTr("Add a console") } ] },
                    { title: qsTr("MOVE AROUND"), actions: [
                        { key: Qt.Key_Up, def: 64, role: qsTr("Up") },
                        { key: Qt.Key_Down, def: 128, role: qsTr("Down") },
                        { key: Qt.Key_Left, def: 16, role: qsTr("Left") },
                        { key: Qt.Key_Right, def: 32, role: qsTr("Right") } ] },
                    { title: qsTr("TABS AND PAGES"), actions: [
                        { key: Qt.Key_PageUp, def: 256, role: qsTr("Previous tab") },
                        { key: Qt.Key_PageDown, def: 512, role: qsTr("Next tab") },
                        { key: Qt.Key_F3, def: 65536, role: qsTr("Essentials") },
                        { key: Qt.Key_F4, def: 131072, role: qsTr("All settings") } ] }
                ]
                function navAll() {
                    let all = [];
                    for (const g of navGroups)
                        all = all.concat(g.actions);
                    return all;
                }
                // boutons d'une action : [principal, second] (0 = pas de second) ; réglage, sinon ceux d'origine
                function navSlots(key) {
                    let map = {};
                    try { map = navPrefs.navMapping ? JSON.parse(navPrefs.navMapping) : {}; } catch (e) { }
                    const v = map[String(key)];
                    if (Array.isArray(v))
                        return [v[0] || 0, v[1] || 0];
                    if (v !== undefined)
                        return [v, 0];
                    for (const a of navAll())
                        if (a.key === key)
                            return [a.def, 0];
                    return [0, 0];
                }
                function navFlag(key) {
                    return navSlots(key)[0];
                }
                // action (rôle) que fait un bouton dans l'appli, ou ""
                function navRoleOf(flag) {
                    for (const a of navAll())
                        if (navSlots(a.key).indexOf(flag) >= 0)
                            return a.role;
                    return "";
                }
                function navSave(map) {
                    let same = true;
                    for (const a of navAll()) {
                        const sl = map[String(a.key)];
                        if (sl[0] !== a.def || sl[1])
                            same = false;
                    }
                    navPrefs.navMapping = same ? "" : JSON.stringify(map);
                }
                function navCurrent() {
                    let map = {};
                    for (const a of navAll())
                        map[String(a.key)] = navSlots(a.key).slice();
                    return map;
                }
                // le bouton « flag » devient le principal (slot 0) ou le second (slot 1) de l'action « key ».
                // Un bouton ne fait qu'une action : s'il était le principal d'une autre, on échange ;
                // s'il était le second d'une autre, il y est retiré.
                function navAssign(key, flag, slot) {
                    let map = navCurrent();
                    const mine = map[String(key)];
                    if (mine[slot] === flag)
                        return;
                    if (slot === 1 && mine[0] === flag)
                        return;
                    const old = mine[slot];
                    for (const k in map) {
                        if (k === String(key))
                            continue;
                        const sl = map[k];
                        if (sl[0] === flag) {
                            if (slot === 0 || !sl[1])
                                sl[0] = old;
                            else {
                                sl[0] = sl[1];
                                sl[1] = 0;
                            }
                        } else if (sl[1] === flag) {
                            sl[1] = 0;
                        }
                    }
                    if (slot === 0 && mine[1] === flag)
                        mine[1] = 0;
                    mine[slot] = flag;
                    navSave(map);
                }
                function navRemoveSecond(key) {
                    let map = navCurrent();
                    map[String(key)][1] = 0;
                    navSave(map);
                }
                // flèches dans la page Manette ; tout en haut, ↑ remonte jusqu'au schéma (rien de sélectionnable au-dessus)
                function padNav(from, key) {
                    const best = keysFlick.moveFocusIn(padColumn, from, key);
                    if (best)
                        padEnsureVisible(best);
                    else if (key === Qt.Key_Up)
                        padScroll.to = 0, padScroll.restart();
                    else if (key === Qt.Key_Down)
                        padScroll.to = Math.max(0, padFlick.contentHeight - padFlick.height), padScroll.restart();
                }
                NumberAnimation {
                    id: padScroll
                    target: padFlick
                    property: "contentY"
                    duration: 350
                    easing.type: Easing.OutCubic
                }
                function firstNavButton() {
                    let items = [];
                    keysFlick.collectNav(padColumn, items);
                    return items.length ? items[0] : null;
                }
                function padEnsureVisible(item) {
                    if (!item)
                        return;
                    const top = item.mapToItem(padColumn, 0, 0).y - 40;
                    const bottom = top + item.height + 80;
                    if (top < padFlick.contentY)
                        padFlick.contentY = Math.max(0, top);
                    else if (bottom > padFlick.contentY + padFlick.height)
                        padFlick.contentY = Math.min(padFlick.contentHeight - padFlick.height, bottom - padFlick.height);
                }

                // fenêtre « Appuyez sur la nouvelle touche » : le premier bouton pressé devient celui de l'action
                C.CaptureDialog {
                    id: navPicker
                    property int navKey: 0
                    property int navSlot: 0
                    property string role: ""
                    parent: Overlay.overlay
                    x: Math.round((root.width - width) / 2)
                    y: Math.round((root.height - height) / 2)
                    glyph: "🎮"
                    heading: qsTr("Press the new button")
                    detail: qsTr("for « %1 »").arg(role) + "\n" + qsTr("If that button already did something, the two are swapped.")
                    function show(key, roleName, flag, slot) {
                        navKey = key;
                        navSlot = slot;
                        role = roleName;
                        const info = keysFlick.keyInfo(flag, "?");
                        icon = flag ? (info.icon || "") : "";
                        glyph = flag ? (info.glyph || "") : "+";
                        open();
                    }
                    onOpened: Chiaki.controllerMapping.startNavCapture()
                    onClosed: {
                        Chiaki.controllerMapping.stopNavCapture();
                        const key = navKey, slot = navSlot;
                        Qt.callLater(() => {
                            let items = [];
                            keysFlick.collectNav(padColumn, items);
                            for (const it of items)
                                if (it.navKey === key && it.navSlot === slot) {
                                    it.forceActiveFocus(Qt.TabFocusReason);
                                    return;
                                }
                        });
                    }
                    Connections {
                        target: Chiaki.controllerMapping
                        function onNavButtonCaptured(button) {
                            if (!navPicker.opened)
                                return;
                            controllerMapping.navAssign(navPicker.navKey, button, navPicker.navSlot);
                            navPicker.close();
                        }
                    }
                }

                // combinaison du menu en jeu, en noms lisibles (réglages : numéro du bouton + 1)
                function streamMenuCombo() {
                    const s = Chiaki.settings;
                    let names = [];
                    for (const n of [s.streamMenuShortcut1, s.streamMenuShortcut2, s.streamMenuShortcut3, s.streamMenuShortcut4])
                        if (n)
                            names.push(keysFlick.keyInfo(1 << (n - 1), "?").label);
                    return names.join(" + ");
                }

                // ——— sous-onglet Clavier et souris ———
                Flickable {
                    id: keysFlick
                    visible: controllerMapping.keysSubTab === 1
                    anchors {
                        top: keysSwitch.bottom
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        topMargin: 12
                        bottomMargin: 20
                    }
                    clip: true
                    contentWidth: width
                    contentHeight: keysColumn.implicitHeight + 20
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    ScrollBar.vertical: C.PsScrollBar {
                        visible: keysFlick.contentHeight > keysFlick.height
                    }

                    // boutons de la manette rangés par familles (les valeurs sont celles de la bibliothèque)
                    readonly property var groups: [
                        { title: qsTr("FACE BUTTONS"), values: [1, 2, 4, 8] },
                        { title: qsTr("DIRECTIONAL BUTTONS"), values: [64, 128, 16, 32] },
                        { title: qsTr("SHOULDER BUTTONS AND TRIGGERS"), values: [256, 512, 65536, 131072] },
                        { title: qsTr("LEFT STICK"), values: [1 << 20, 1 << 21, 1 << 19, 1 << 18, 1024] },
                        { title: qsTr("RIGHT STICK"), values: [1 << 24, 1 << 25, 1 << 23, 1 << 22, 2048] },
                        { title: qsTr("OTHER BUTTONS"), values: [4096, 8192, 16384, 32768], rest: true }
                    ]
                    function groupEntries(group) {
                        const mapping = Chiaki.settings.controllerMapping;
                        let out = [];
                        for (const v of group.values)
                            for (let i = 0; i < mapping.length; i++)
                                if (mapping[i].buttonValue === v)
                                    out.push(mapping[i]);
                        // boutons rares non classés (micro…) : à la fin
                        if (group.rest) {
                            let known = [];
                            for (const g of groups)
                                known = known.concat(g.values);
                            for (let i = 0; i < mapping.length; i++)
                                if (known.indexOf(mapping[i].buttonValue) < 0)
                                    out.push(mapping[i]);
                        }
                        return out;
                    }
                    // nom court et symbole néon de chaque bouton
                    property C.PsButtonInfo psButtons: C.PsButtonInfo { }
                    function keyInfo(value, fallback) {
                        return psButtons.info(value, fallback);
                    }
                    // nom de touche lisible (Qt donne « Return », « Backspace »…)
                    function prettyKey(name) {
                        const names = {
                            "Return": qsTr("Enter"), "Enter": qsTr("Enter"), "Backspace": qsTr("Backspace"),
                            "Esc": qsTr("Esc"), "Space": qsTr("Space"), "Tab": "Tab ⇥", "Ins": qsTr("Insert"),
                            "Del": qsTr("Delete"), "PgUp": qsTr("Page") + " ↑", "PgDown": qsTr("Page") + " ↓",
                            "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Home": "↖", "End": "↘"
                        };
                        return names[name] || name;
                    }
                    function ensureItemVisible(item) {
                        if (!item)
                            return;
                        const top = item.mapToItem(keysColumn, 0, 0).y - 40;
                        const bottom = top + item.height + 80;
                        if (top < contentY)
                            contentY = Math.max(0, top);
                        else if (bottom > contentY + height)
                            contentY = Math.min(contentHeight - height, bottom - height);
                    }
                    // navigation dans les quatre directions : on va à l'élément le plus proche dans le sens demandé
                    function collectNav(item, out) {
                        for (let i = 0; i < item.children.length; i++) {
                            const child = item.children[i];
                            if (!child.visible)
                                continue;
                            if (child.keysNav === true && child.enabled)
                                out.push(child);
                            collectNav(child, out);
                        }
                    }
                    function moveFocus(from, key) {
                        ensureItemVisible(moveFocusIn(keysColumn, from, key));
                    }
                    function moveFocusIn(root, from, key) {
                        let items = [];
                        collectNav(root, items);
                        const p = from.mapToItem(root, from.width / 2, from.height / 2);
                        let best = null, bestScore = Number.MAX_VALUE;
                        for (const it of items) {
                            if (it === from)
                                continue;
                            const q = it.mapToItem(root, it.width / 2, it.height / 2);
                            const dx = q.x - p.x, dy = q.y - p.y;
                            let main = 0, side = 0;
                            switch (key) {
                            case Qt.Key_Up: main = -dy; side = dx; break;
                            case Qt.Key_Down: main = dy; side = dx; break;
                            case Qt.Key_Left: main = -dx; side = dy; break;
                            case Qt.Key_Right: main = dx; side = dy; break;
                            }
                            if (main <= 4)
                                continue;
                            // ← → restent sur la même ligne
                            if ((key === Qt.Key_Left || key === Qt.Key_Right) && Math.abs(side) > 30)
                                continue;
                            const score = main + Math.abs(side) * 2.5;
                            if (score < bestScore) {
                                bestScore = score;
                                best = it;
                            }
                        }
                        if (best)
                            best.forceActiveFocus(Qt.TabFocusReason);
                        return best;
                    }

                    // touches d'origine (pour signaler ce qui a changé et savoir si la réinitialisation sert)
                    readonly property var defaultKeys: ({
                        1: "Return", 2: "Backspace", 4: "\\", 8: "C", 16: "Left", 32: "Right", 64: "Up", 128: "Down",
                        256: "2", 512: "3", 1024: "5", 2048: "6", 4096: "O", 8192: "F", 16384: "T", 32768: "Esc",
                        65536: "1", 131072: "4", [1 << 18]: "]", [1 << 19]: "[", [1 << 20]: "Ins", [1 << 21]: "Del",
                        [1 << 22]: "=", [1 << 23]: "-", [1 << 24]: "PgUp", [1 << 25]: "PgDown"
                    })
                    readonly property bool anyKeyChanged: Chiaki.settings.controllerMapping.some(m => (defaultKeys[m.buttonValue] !== undefined && defaultKeys[m.buttonValue] !== m.keyName) || !!m.keyName2)
                    // touche du clavier -> bouton PlayStation qu'elle fait
                    readonly property var keyToButton: {
                        let map = {};
                        for (const m of Chiaki.settings.controllerMapping) {
                            map[m.keyName] = m.buttonValue;
                            if (m.keyName2)
                                map[m.keyName2] = m.buttonValue;
                        }
                        return map;
                    }
                    // bouton dont la touche est sélectionnée dans la liste (sa touche brille sur le clavier dessiné)
                    property int focusedButton: -1
                    readonly property bool activeFocusInList: {
                        const item = dialog.Window.window ? dialog.Window.window.activeFocusItem : null;
                        return !!item && item.keyValue !== undefined;
                    }
                    function refocusKey(value, slot) {
                        let items = [];
                        collectNav(keysColumn, items);
                        for (const it of items)
                            if (it.keyValue === value && (slot === undefined || it.keySlot === slot)) {
                                it.forceActiveFocus(Qt.TabFocusReason);
                                ensureItemVisible(it);
                                return;
                            }
                    }
                    // clavier dessiné (disposition AZERTY de Mac, simplifiée) : l = inscription, n = nom de la touche, w = largeur
                    readonly property var keyboardRows: [
                        [{ l: "esc", n: "Esc", w: 1.3 }, { l: "1" }, { l: "2" }, { l: "3" }, { l: "4" }, { l: "5" }, { l: "6" }, { l: "7" }, { l: "8" }, { l: "9" }, { l: "0" }, { l: "-" }, { l: "=" }, { l: "⌫", n: "Backspace", w: 1.7 }],
                        [{ l: "⇥", n: "Tab", w: 1.5 }, { l: "A" }, { l: "Z" }, { l: "E" }, { l: "R" }, { l: "T" }, { l: "Y" }, { l: "U" }, { l: "I" }, { l: "O" }, { l: "P" }, { l: "[" }, { l: "]" }, { l: "", w: 1.5, gap: true }],
                        [{ l: "⇪", n: "CapsLock", w: 1.8 }, { l: "Q" }, { l: "S" }, { l: "D" }, { l: "F" }, { l: "G" }, { l: "H" }, { l: "J" }, { l: "K" }, { l: "L" }, { l: "M" }, { l: "\\" }, { l: "↵", n: "Return", w: 2.2 }],
                        [{ l: "⇧", n: "Shift", w: 2.3 }, { l: "W" }, { l: "X" }, { l: "C" }, { l: "V" }, { l: "B" }, { l: "N" }, { l: "," }, { l: "." }, { l: "/" }, { l: "⇧", n: "Shift", w: 2.7 }],
                        [{ l: "", w: 4, gap: true }, { l: "", n: "Space", w: 6 }]
                    ]
                    readonly property var clusterRows: [
                        [{ l: "ins", n: "Ins" }, { l: "↖", n: "Home" }, { l: "pg↑", n: "PgUp" }],
                        [{ l: "del", n: "Del" }, { l: "↘", n: "End" }, { l: "pg↓", n: "PgDown" }],
                        [{ l: "", gap: true }, { l: "", gap: true }, { l: "", gap: true }],
                        [{ l: "", gap: true }, { l: "↑", n: "Up" }, { l: "", gap: true }],
                        [{ l: "←", n: "Left" }, { l: "↓", n: "Down" }, { l: "→", n: "Right" }]
                    ]

                    // une touche du clavier dessiné : allumée en néon (avec le symbole du bouton) si elle sert en jeu
                    component DrawnKey: Rectangle {
                        id: drawnKey
                        property var spec: ({})
                        // données de la page (un composant interne ne voit pas les identifiants de la page)
                        property var buttons: ({})
                        property int focused: -1
                        property var infoOf: null
                        readonly property string keyName: spec.n !== undefined ? spec.n : spec.l
                        readonly property int button: !spec.gap && buttons[keyName] !== undefined ? buttons[keyName] : 0
                        readonly property var info: button && infoOf ? infoOf(button, "") : null
                        readonly property bool lit: button !== 0
                        readonly property bool hot: lit && button === focused
                        width: (spec.w || 1) * 44 + ((spec.w || 1) - 1) * 6
                        height: 44
                        radius: 8
                        visible: true
                        opacity: spec.gap ? 0 : 1
                        color: hot ? Qt.rgba(0.24, 0.48, 1, 0.38) : (lit ? Qt.rgba(0.24, 0.48, 1, 0.16) : Qt.rgba(1, 1, 1, 0.03))
                        border.width: lit ? (hot ? 2 : 1.5) : 1
                        border.color: hot ? "#eef4ff" : (lit ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.16))
                        Behavior on color { ColorAnimation { duration: 150 } }
                        // inscription de la touche : au centre, ou en petit dans le coin quand le symbole s'affiche
                        Text {
                            x: drawnKey.lit ? 5 : (parent.width - width) / 2
                            y: drawnKey.lit ? 3 : (parent.height - height) / 2
                            text: drawnKey.spec.l || ""
                            color: "#eef4ff"
                            opacity: drawnKey.lit ? 0.7 : 0.45
                            font.pixelSize: drawnKey.lit ? 9 : 13
                        }
                        Item {
                            visible: drawnKey.lit
                            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                            width: 20
                            height: 20
                            Image {
                                anchors.fill: parent
                                visible: !!drawnKey.info && !!drawnKey.info.icon
                                sourceSize: Qt.size(40, 40)
                                source: drawnKey.info && drawnKey.info.icon ? drawnKey.info.icon : ""
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: !!drawnKey.info && !drawnKey.info.icon
                                // directions de stick : « L » ou « R » devant la flèche, pour ne pas les confondre avec la croix
                                readonly property string side: drawnKey.button >= (1 << 18) && drawnKey.button <= (1 << 21) ? "L"
                                    : (drawnKey.button >= (1 << 22) && drawnKey.button <= (1 << 25) ? "R" : "")
                                text: side + (drawnKey.info ? (drawnKey.info.glyph || "") : "")
                                color: "#9cc2ff"
                                font.pixelSize: text.length > 1 ? 11 : 16
                                font.bold: true
                            }
                        }
                    }

                    ColumnLayout {
                        id: keysColumn
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: Math.min(keysFlick.width - 60, 1096)
                        spacing: 10

                        // réglages du clavier et de la souris
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 16
                            C.CheckBox {
                                id: keyboardAsController
                                property bool keysNav: true
                                navHandler: keysFlick.moveFocus
                                text: qsTr("Keyboard as controller")
                                checked: Chiaki.settings.keyboardEnabled
                                onToggled: Chiaki.settings.keyboardEnabled = checked
                            }
                            C.CheckBox {
                                property bool keysNav: true
                                navHandler: keysFlick.moveFocus
                                text: qsTr("Enable Mouse Touchpad")
                                checked: Chiaki.settings.mouseTouchEnabled
                                onToggled: Chiaki.settings.mouseTouchEnabled = checked
                            }
                        }

                        Label {
                            Layout.topMargin: 12
                            text: qsTr("YOUR KEYBOARD IN GAME")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: Chiaki.settings.keyboardEnabled
                                ? qsTr("Lit keys play the PlayStation button shown on them. Select a key in the list below to find it on the keyboard.")
                                : qsTr("Turn on « Keyboard as controller » to play with these keys.")
                            font.pixelSize: 15
                            color: Chiaki.settings.keyboardEnabled ? "#eef4ff" : "#9cc2ff"
                            opacity: Chiaki.settings.keyboardEnabled ? 0.6 : 0.85
                        }

                        // clavier + bloc des flèches + souris, réduits si la fenêtre est étroite
                        Item {
                            id: drawnArea
                            Layout.fillWidth: true
                            readonly property real naturalWidth: drawnBoard.implicitWidth
                            readonly property real fit: Math.min(1, width / naturalWidth)
                            Layout.preferredHeight: drawnBoard.implicitHeight * fit + 8
                            opacity: Chiaki.settings.keyboardEnabled ? 1 : 0.5
                            Row {
                                id: drawnBoard
                                spacing: 28
                                scale: drawnArea.fit
                                transformOrigin: Item.Top
                                anchors.horizontalCenter: parent.horizontalCenter
                                // le clavier
                                Column {
                                    spacing: 6
                                    Repeater {
                                        model: keysFlick.keyboardRows
                                        Row {
                                            required property var modelData
                                            spacing: 6
                                            Repeater {
                                                model: parent.modelData
                                                DrawnKey {
                                                    required property var modelData
                                                    spec: modelData
                                                    buttons: keysFlick.keyToButton
                                                    focused: keysFlick.focusedButton
                                                    infoOf: keysFlick.keyInfo
                                                }
                                            }
                                        }
                                    }
                                }
                                // flèches et touches d'édition
                                Column {
                                    spacing: 6
                                    Repeater {
                                        model: keysFlick.clusterRows
                                        Row {
                                            required property var modelData
                                            spacing: 6
                                            Repeater {
                                                model: parent.modelData
                                                DrawnKey {
                                                    required property var modelData
                                                    spec: modelData
                                                    buttons: keysFlick.keyToButton
                                                    focused: keysFlick.focusedButton
                                                    infoOf: keysFlick.keyInfo
                                                }
                                            }
                                        }
                                    }
                                }
                                // la souris : sert de pavé tactile quand l'option est cochée
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 10
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 64
                                        height: 100
                                        radius: 32
                                        readonly property bool on: Chiaki.settings.mouseTouchEnabled
                                        color: on ? Qt.rgba(0.24, 0.48, 1, 0.16) : Qt.rgba(1, 1, 1, 0.03)
                                        border.width: on ? 2 : 1
                                        border.color: on ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.16)
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 0
                                            width: 1.5
                                            height: 40
                                            color: parent.border.color
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 14
                                            width: 6
                                            height: 14
                                            radius: 3
                                            color: parent.border.color
                                        }
                                        Text {
                                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 18 }
                                            text: "▭"
                                            visible: parent.on
                                            color: "#9cc2ff"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: 130
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        text: Chiaki.settings.mouseTouchEnabled ? qsTr("Mouse = touchpad (click and drag)") : qsTr("Mouse not used in game")
                                        font.pixelSize: 12
                                        opacity: 0.6
                                    }
                                }
                            }
                        }

                        Label {
                            Layout.topMargin: 18
                            text: qsTr("KEYS IN GAME")
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: qsTr("Click a key, then press the new key on your keyboard. The small box adds a second key for the same button. If that key already played another button, the two are swapped.")
                            font.pixelSize: 15
                            opacity: 0.6
                        }

                        Repeater {
                            model: keysFlick.groups

                            ColumnLayout {
                                id: keysSection
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                spacing: 10
                                // touches grisées tant que le clavier ne sert pas de manette
                                opacity: Chiaki.settings.keyboardEnabled ? 1.0 : 0.5

                                Label {
                                    text: keysSection.modelData.title
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.0
                                    opacity: 0.6
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    columnSpacing: 14
                                    rowSpacing: 12

                                    Repeater {
                                        model: keysFlick.groupEntries(keysSection.modelData)

                                        // [touche du clavier] → bouton PlayStation qu'elle fait en jeu
                                        Rectangle {
                                            id: keyCard
                                            required property var modelData
                                            readonly property var info: keysFlick.keyInfo(modelData.buttonValue, modelData.buttonName)
                                            readonly property bool changed: (keysFlick.defaultKeys[modelData.buttonValue] !== undefined
                                                && keysFlick.defaultKeys[modelData.buttonValue] !== modelData.keyName) || !!modelData.keyName2
                                            readonly property bool focused: keysFlick.focusedButton === modelData.buttonValue && keysFlick.activeFocusInList
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            Layout.preferredHeight: 68
                                            radius: 16
                                            color: Qt.rgba(0.35, 0.55, 1, focused ? 0.13 : 0.05)
                                            border.width: focused ? 2 : 1
                                            border.color: focused ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.16)

                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 16 }
                                                spacing: 14

                                                // touche principale et seconde touche : même dessin que la page Manette
                                                Repeater {
                                                    model: 2
                                                    C.Button {
                                                        id: keyCap
                                                        required property int index
                                                        property bool keysNav: true
                                                        readonly property int keyValue: keyCard.modelData.buttonValue
                                                        readonly property int keySlot: index
                                                        readonly property string name: index === 0 ? keyCard.modelData.keyName : (keyCard.modelData.keyName2 || "")
                                                        readonly property bool filled: name !== ""
                                                        navHandler: keysFlick.moveFocus
                                                        Layout.preferredWidth: index === 0 ? 120 : 52
                                                        Layout.preferredHeight: 46
                                                        topInset: 0
                                                        bottomInset: 0
                                                        leftPadding: index === 0 ? 12 : 4
                                                        rightPadding: index === 0 ? 12 : 4
                                                        contentItem: RowLayout {
                                                            spacing: 6
                                                            Text {
                                                                Layout.fillWidth: true
                                                                Layout.fillHeight: true
                                                                text: keyCap.filled ? keysFlick.prettyKey(keyCap.name) : "+"
                                                                color: keyCap.filled && keyCap.index === 0 ? "#eef4ff" : "#9cc2ff"
                                                                opacity: keyCap.filled ? 1 : 0.55
                                                                font.pixelSize: keyCap.index === 0 ? 15 : (keyCap.filled ? 12 : 20)
                                                                font.weight: Font.DemiBold
                                                                horizontalAlignment: Text.AlignHCenter
                                                                verticalAlignment: Text.AlignVCenter
                                                                elide: Text.ElideRight
                                                            }
                                                            Text {
                                                                visible: keyCap.index === 0
                                                                text: "▾"
                                                                color: "#9cc2ff"
                                                                font.pixelSize: 14
                                                            }
                                                        }
                                                        background: Rectangle {
                                                            radius: 12
                                                            color: Qt.rgba(0.35, 0.55, 1, keyCap.down ? 0.22 : (keyCap.hovered ? 0.16 : (keyCap.filled ? 0.10 : 0.04)))
                                                            border.width: keyCap.visualFocus ? 2 : 1
                                                            border.color: keyCap.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, keyCap.filled ? 0.28 : 0.18)
                                                        }
                                                        // retirer la seconde touche : bouton « Supprimer » de la manette (□ d'origine) ou petit ×
                                                        Keys.onNoPressed: (event) => {
                                                            if (keyCap.index === 1 && keyCap.filled)
                                                                Chiaki.settings.clearControllerKey2(keyValue);
                                                            event.accepted = true;
                                                        }
                                                        Rectangle {
                                                            visible: keyCap.index === 1 && keyCap.filled
                                                            anchors { top: parent.top; right: parent.right; topMargin: -7; rightMargin: -7 }
                                                            width: 20
                                                            height: 20
                                                            radius: 10
                                                            color: keyRemoveArea.containsMouse ? "#c0392b" : "#3a1a28"
                                                            border.width: 1
                                                            border.color: Qt.rgba(1, 0.55, 0.6, 0.7)
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "×"
                                                                color: "white"
                                                                font.pixelSize: 14
                                                                font.bold: true
                                                            }
                                                            MouseArea {
                                                                id: keyRemoveArea
                                                                anchors.fill: parent
                                                                anchors.margins: -4
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: Chiaki.settings.clearControllerKey2(keyCap.keyValue)
                                                            }
                                                        }
                                                        onActiveFocusChanged: {
                                                            if (activeFocus) {
                                                                keysFlick.focusedButton = keyValue;
                                                                keysFlick.ensureItemVisible(keyCard);
                                                            } else if (keysFlick.focusedButton === keyValue) {
                                                                keysFlick.focusedButton = -1;
                                                            }
                                                        }
                                                        onHoveredChanged: keysFlick.focusedButton = hovered ? keyValue : (activeFocus ? keyValue : -1)
                                                        onClicked: keyDialog.show({
                                                            value: keyValue,
                                                            slot: index,
                                                            label: keysFlick.psButtons.role(keyValue, keyCard.info.label),
                                                            item: keyCap,
                                                            callback: (name) => {},
                                                        })
                                                    }
                                                }

                                                Text {
                                                    text: "→"
                                                    color: "#9cc2ff"
                                                    opacity: 0.6
                                                    font.pixelSize: 20
                                                }
                                                Label {
                                                    Layout.fillWidth: true
                                                    text: keysFlick.psButtons.role(keyCard.modelData.buttonValue, keyCard.info.label)
                                                    font.pixelSize: 17
                                                    font.weight: Font.Medium
                                                    elide: Text.ElideRight
                                                }
                                                Rectangle {
                                                    visible: keyCard.changed
                                                    Layout.preferredWidth: keyChanged.implicitWidth + 16
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Qt.rgba(1, 0.77, 0.42, 0.14)
                                                    border.width: 1
                                                    border.color: "#ffc46b"
                                                    Label {
                                                        id: keyChanged
                                                        anchors.centerIn: parent
                                                        text: qsTr("Changed")
                                                        font.pixelSize: 12
                                                        color: "#ffc46b"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // en bas, au milieu : remettre les touches d'origine
                        C.Button {
                            id: resetAllKeys
                            property bool keysNav: true
                            navHandler: keysFlick.moveFocus
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 28
                            enabled: keysFlick.anyKeyChanged
                            opacity: enabled ? 1 : 0.45
                            text: "↺  " + qsTr("Reset the keys")
                            onClicked: Chiaki.settings.clearKeyMapping()
                        }
                    }
                }
            }

            Item {
                // Controllers
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
                    // une carte par réglage : nom et explication à gauche, commande à droite
                    component ControllerCard: Rectangle {
                        property alias title: cardTitle.text
                        property alias hint: cardHint.text
                        default property alias control: cardHolder.data
                        property real controlWidth: 420
                        Layout.fillWidth: true
                        implicitHeight: Math.max(cardText.implicitHeight, cardHolder.implicitHeight) + 36
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
                                    visible: text !== ""
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
                    component SectionLabel: Label {
                        Layout.topMargin: 14
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        color: "#9cc2ff"
                    }

                    ColumnLayout {
                        id: controllersLayout
                        anchors {
                            top: parent.top
                            horizontalCenter: parent.horizontalCenter
                        }
                        width: Math.min(controllersFlick.width - 80, 1100)
                        spacing: 12

                        SectionLabel { text: qsTr("FEEL") }

                        ControllerCard {
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

                        ControllerCard {
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

                        SectionLabel { text: qsTr("BUTTON LAYOUT") }

                        ControllerCard {
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

                        SectionLabel { text: qsTr("TOUCHPAD WITH THE D-PAD") }

                        ControllerCard {
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

                        ControllerCard {
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

                        SectionLabel { text: qsTr("IN THE BACKGROUND") }

                        ControllerCard {
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

            Item {
                // Remote (PSN and Hole Punching)
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
                        readonly property bool psnConnected: !!(Chiaki.settings.psnRefreshToken && Chiaki.settings.psnAuthToken && Chiaki.settings.psnAuthTokenExpiry && Chiaki.settings.psnAccountId)

                        SectionLabel { text: qsTr("PSN ACCOUNT") }

                        ControllerCard {
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
                                    Chiaki.settings.psnRefreshToken = ""
                                    Chiaki.settings.psnAuthToken = ""
                                    Chiaki.settings.psnAuthTokenExpiry = ""
                                    Chiaki.settings.psnAccountId = ""
                                    openPsnLogin.forceActiveFocus(Qt.TabFocusReason);
                                }
                            }
                        }

                        SectionLabel { text: qsTr("REMOTE CONNECTION (ADVANCED)") }

                        Label {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 4
                            wrapMode: Text.WordWrap
                            font.pixelSize: 14
                            opacity: 0.6
                            text: qsTr("Away from home, the Mac and the console must find each other through both Internet routers. These settings only help if the remote connection fails: otherwise leave them as they are.")
                        }

                        ControllerCard {
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

                        ControllerCard {
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

                        ControllerCard {
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

            Item {
                // Config (Options such as Import/Export and Logging)
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
                            lastInFocusChain: true
                            onToggled: Chiaki.settings.logVerbose = checked
                        }
                    }
                }
            }
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
