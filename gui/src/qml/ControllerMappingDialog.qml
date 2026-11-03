// Attribution des boutons d'une manette : vue de Chiaki.controllerMapping.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects

import org.streetpea.chiaking

import "controls" as C

DialogView {
    id: dialog
    property bool finalClosing: false
    title: Chiaki.controllerMapping.controllerType
    buttonText: qsTr("Update Controller Mapping")
    buttonEnabled: Chiaki.controllerMapping.altered
    onAccepted: {
        Chiaki.controllerMapping.apply();
        Chiaki.controllerMapping.quit();
    }
    // flèches sans rien de sélectionné : on reprend sur le premier bouton
    Keys.onPressed: (event) => {
        if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].indexOf(event.key) >= 0) {
            mappingPage.refocus(-1);
            event.accepted = true;
        }
    }
    Component.onDestruction: {
        if(Chiaki.controllerMapping.inProgress)
        {
            finalClosing = true;
            Chiaki.controllerMapping.quit();
        }
    }

    Item {
        // Controller Mapping : chaque bouton de la manette et l'action PlayStation qu'il fait
        id: mappingPage
        property C.PsButtonInfo psButtons: C.PsButtonInfo { }
        // manette PlayStation : on connaît le vrai nom (et le symbole) de chacun de ses boutons
        readonly property bool playStation: /PS[345]|DualSense|DualShock/i.test(Chiaki.controllerMapping.controllerType)
        // actions PlayStation rangées par familles, avec le bouton de la manette qui fait chacune
        readonly property var groups: [
            { title: qsTr("FACE BUTTONS"), values: [1, 2, 4, 8] },
            { title: qsTr("DIRECTIONAL BUTTONS"), values: [64, 128, 16, 32] },
            { title: qsTr("SHOULDER BUTTONS AND TRIGGERS"), values: [256, 512, 65536, 131072] },
            { title: qsTr("LEFT STICK"), values: [1 << 26, 1 << 27, 1024] },
            { title: qsTr("RIGHT STICK"), values: [1 << 28, 1 << 29, 2048] },
            { title: qsTr("OTHER BUTTONS"), values: [4096, 8192, 16384, 32768], rest: true }
        ]
        readonly property var stickAxes: [1 << 26, 1 << 27, 1 << 28, 1 << 29]
        function groupEntries(group) {
            const mapping = Chiaki.controllerMapping.mapping;
            let out = [];
            for (const v of group.values)
                for (let i = 0; i < mapping.length; i++)
                    if (mapping[i].buttonValue === v)
                        out.push(mapping[i]);
            if (group.rest) {
                let known = [];
                for (const g of groups)
                    known = known.concat(g.values);
                for (let i = 0; i < mapping.length; i++)
                    if (known.indexOf(mapping[i].buttonValue) < 0)
                        out.push(mapping[i]);
            }
            // les axes des sticks seulement si on autorise leur association
            if (!Chiaki.controllerMapping.analogStickMapping)
                out = out.filter(e => stickAxes.indexOf(e.buttonValue) < 0);
            return out;
        }
        // tous les boutons physiques de la manette et ce que fait chacun ; relu à chaque changement
        readonly property var physicalList: {
            Chiaki.controllerMapping.mapping;
            return Chiaki.controllerMapping.physicalButtons();
        }
        // bouton d'origine de chaque action sur une manette PlayStation (pour signaler ce qui a changé)
        readonly property var psDefault: ({
            1: "b0", 2: "b1", 4: "b2", 8: "b3", 8192: "b4", 32768: "b5", 4096: "b6", 1024: "b7", 2048: "b8",
            256: "b9", 512: "b10", 16384: "b11", 64: "h0.1", 128: "h0.4", 16: "h0.8", 32: "h0.2",
            [1 << 26]: "a0", [1 << 27]: "a1", [1 << 28]: "a2", [1 << 29]: "a3", 65536: "a4", 131072: "a5"
        })
        // ordre d'affichage des boutons d'une manette PlayStation dans la liste de choix
        readonly property var psOrder: ["b0", "b1", "b2", "b3", "h0.1", "h0.4", "h0.8", "h0.2", "b9", "b10", "a4", "a5", "b7", "b8", "a0", "a1", "a2", "a3", "b4", "b6", "b5", "b11"]

        function bare(raw) {
            return raw.replace(/^[+-]/, "").replace("~", "");
        }
        function isAxis(raw) {
            return bare(raw)[0] === "a";
        }
        // boutons proposés pour une action : un axe de stick ne peut venir que d'un axe, une touche que d'un bouton
        // (L2 / R2 acceptent les deux)
        function choicesFor(action) {
            let list = physicalList.slice();
            if (stickAxes.indexOf(action) >= 0)
                list = list.filter(b => isAxis(b.physical));
            else if (action !== 65536 && action !== 131072)
                list = list.filter(b => !isAxis(b.physical));
            const rank = (b) => {
                const i = psOrder.indexOf(bare(b.physical));
                return i < 0 ? 1000 + parseInt(bare(b.physical).replace(/\D/g, "") || "0") : i;
            };
            list.sort((x, y) => rank(x) - rank(y));
            return list;
        }
        function roleOf(value, fallback) {
            return psButtons.role(value, fallback);
        }
        function physicalLabel(raw) {
            return raw ? psButtons.physicalName(raw, playStation) : qsTr("None");
        }

        function ensureItemVisible(item) {
            if (!item)
                return;
            const top = item.mapToItem(mappingColumn, 0, 0).y - 40;
            const bottom = top + item.height + 80;
            if (top < mappingFlick.contentY)
                mappingFlick.contentY = Math.max(0, top);
            else if (bottom > mappingFlick.contentY + mappingFlick.height)
                mappingFlick.contentY = Math.min(mappingFlick.contentHeight - mappingFlick.height, bottom - mappingFlick.height);
        }
        // navigation dans les quatre directions : l'élément le plus proche dans le sens demandé
        function collectNav(item, out) {
            for (let i = 0; i < item.children.length; i++) {
                const child = item.children[i];
                if (!child.visible)
                    continue;
                if (child.mappingNav === true && child.enabled)
                    out.push(child);
                collectNav(child, out);
            }
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
        function moveFocus(from, key) {
            ensureItemVisible(moveFocusIn(mappingColumn, from, key));
        }
        // après un changement la liste est recréée : on remet le curseur sur le même bouton (ou le premier)
        property int pendingAction: -1
        function refocusLater(action) {
            pendingAction = action;
            refocusTimer.restart();
        }
        Timer {
            id: refocusTimer
            interval: 0
            onTriggered: mappingPage.refocus(mappingPage.pendingAction)
        }
        function refocus(action) {
            let items = [];
            collectNav(mappingColumn, items);
            for (const it of items)
                if (it.mapAction === action) {
                    it.forceActiveFocus(Qt.TabFocusReason);
                    ensureItemVisible(it);
                    return;
                }
            if (items.length)
                items[0].forceActiveFocus(Qt.TabFocusReason);
        }

        // grand panneau de verre derrière la page, comme dans les Paramètres
        C.GlassBackground {
            anchors {
                fill: parent
                topMargin: 8
                leftMargin: 24
                rightMargin: 24
                bottomMargin: 20
            }
            tint: 0.6
        }

        Flickable {
            id: mappingFlick
            anchors {
                fill: parent
                topMargin: 26
                leftMargin: 24
                rightMargin: 24
                bottomMargin: 36
            }
            clip: true
            contentWidth: width
            contentHeight: mappingColumn.implicitHeight + 20
            flickableDirection: Flickable.AutoFlickIfNeeded
            ScrollBar.vertical: C.PsScrollBar {
                visible: mappingFlick.contentHeight > mappingFlick.height
            }

            ColumnLayout {
                id: mappingColumn
                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                }
                width: Math.min(mappingFlick.width - 80, 1180)
                spacing: 10

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("For each action, choose the button of your controller that does it. If that button already did something else, the two are swapped.")
                    font.pixelSize: 15
                    lineHeight: 1.2
                    opacity: 0.55
                }

                C.CheckBox {
                    property bool mappingNav: true
                    property int mapAction: -2
                    navHandler: mappingPage.moveFocus
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4
                    text: qsTr("Allow mapping analog sticks and L2/R2")
                    checked: Chiaki.controllerMapping.analogStickMapping
                    onToggled: Chiaki.controllerMapping.analogStickMapping = checked
                }

                Repeater {
                    model: mappingPage.groups

                    ColumnLayout {
                        id: mappingSection
                        required property var modelData
                        readonly property var entries: mappingPage.groupEntries(modelData)
                        visible: entries.length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        spacing: 10

                        Label {
                            text: mappingSection.modelData.title
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2
                            color: "#9cc2ff"
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 14
                            rowSpacing: 14

                            Repeater {
                                model: mappingSection.entries

                                // une ligne par action : l'action à gauche, le bouton de la manette qui la fait à droite
                                Rectangle {
                                    id: mapCard
                                    required property var modelData
                                    readonly property int action: modelData.buttonValue
                                    readonly property var info: mappingPage.psButtons.info(action, modelData.buttonName)
                                    readonly property string role: mappingPage.roleOf(action, info.label)
                                    readonly property string raw: modelData.physicalButton.length > 0 ? modelData.physicalButton[0] : ""
                                    readonly property string physIcon: mappingPage.psButtons.physicalIcon(raw, mappingPage.playStation)
                                    readonly property bool changed: mappingPage.playStation && mappingPage.psDefault[action] !== undefined
                                        && mappingPage.psDefault[action] !== mappingPage.bare(raw)
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 74
                                    radius: 18
                                    color: Qt.rgba(0.35, 0.55, 1, buttonChoice.visualFocus ? 0.13 : 0.05)
                                    border.width: buttonChoice.visualFocus ? 2 : 1
                                    border.color: buttonChoice.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.16)
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 18 }
                                        spacing: 14

                                        // le bouton de la manette : un clic (ou ✕) ouvre la liste des boutons
                                        C.Button {
                                            id: buttonChoice
                                            property bool mappingNav: true
                                            readonly property int mapAction: mapCard.action
                                            navHandler: mappingPage.moveFocus
                                            Layout.preferredWidth: 130
                                            Layout.preferredHeight: 48
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
                                                        visible: !!mapCard.physIcon
                                                        width: 28
                                                        height: 28
                                                        sourceSize: Qt.size(56, 56)
                                                        source: mapCard.physIcon
                                                    }
                                                    Text {
                                                        anchors.fill: parent
                                                        visible: !mapCard.physIcon
                                                        text: mappingPage.physicalLabel(mapCard.raw)
                                                        color: "#eef4ff"
                                                        opacity: mapCard.raw ? 1 : 0.5
                                                        font.pixelSize: 15
                                                        font.weight: Font.DemiBold
                                                        horizontalAlignment: Text.AlignHCenter
                                                        verticalAlignment: Text.AlignVCenter
                                                        elide: Text.ElideRight
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
                                                color: Qt.rgba(0.35, 0.55, 1, buttonChoice.down ? 0.22 : (buttonChoice.hovered ? 0.16 : 0.10))
                                                border.width: buttonChoice.visualFocus ? 2 : 1
                                                border.color: buttonChoice.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.28)
                                            }
                                            onActiveFocusChanged: if (activeFocus) mappingPage.ensureItemVisible(mapCard)
                                            onClicked: buttonPicker.show(mapCard.action, mapCard.role, mapCard.raw)
                                        }

                                        Text {
                                            text: "→"
                                            color: "#9cc2ff"
                                            opacity: 0.6
                                            font.pixelSize: 20
                                        }

                                        // l'action : ce qu'elle fait
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Label {
                                                Layout.fillWidth: true
                                                text: mapCard.role
                                                font.pixelSize: 17
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                            }
                                        }

                                        // pastille quand l'action n'est plus sur son bouton d'origine
                                        Rectangle {
                                            visible: mapCard.changed
                                            Layout.preferredWidth: changedLabel.implicitWidth + 16
                                            Layout.preferredHeight: 22
                                            radius: 11
                                            color: Qt.rgba(1, 0.77, 0.42, 0.14)
                                            border.width: 1
                                            border.color: "#ffc46b"
                                            Label {
                                                id: changedLabel
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
            }
        }

        // liste des boutons de la manette, pour choisir celui qui fait une action
        Dialog {
            id: buttonPicker
            property int action: 0
            property string actionLabel: ""
            property string current: ""
            parent: Overlay.overlay
            x: Math.round((root.width - width) / 2)
            y: Math.round((root.height - height) / 2)
            modal: true
            header: null
            footer: null
            padding: 30
            closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape
            readonly property var choices: mappingPage.choicesFor(action)

            function show(value, label, physical) {
                action = value;
                actionLabel = label;
                current = physical;
                open();
            }
            // le bouton choisi fait désormais l'action ; celui qui la faisait reprend l'ancienne action du bouton choisi
            function choose(physical) {
                const a = action;
                close();
                mappingPage.refocusLater(a);
                if (physical !== current)
                    Chiaki.controllerMapping.assignPhysicalButton(physical, a);
            }
            onOpened: {
                let items = [];
                mappingPage.collectNav(pickerGrid, items);
                for (const it of items)
                    if (it.physical === current) {
                        it.forceActiveFocus(Qt.TabFocusReason);
                        return;
                    }
                if (items.length)
                    items[0].forceActiveFocus(Qt.TabFocusReason);
            }
            onClosed: mappingPage.refocusLater(action)

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.94; to: 1; duration: 200; easing.type: Easing.OutBack }
            }
            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 120 }
            }
            background: Rectangle {
                radius: 26
                color: "#0a1430"
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowBlur: 1.0
                    shadowOpacity: 0.7
                    shadowVerticalOffset: 10
                }
            }

            contentItem: ColumnLayout {
                spacing: 18

                // « Quel bouton pour « Croix » ? »
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Which button for « %1 »?").arg(buttonPicker.actionLabel)
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                GridLayout {
                    id: pickerGrid
                    Layout.alignment: Qt.AlignHCenter
                    columns: 5
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: buttonPicker.choices

                        // un bouton de la manette, avec ce qu'il fait aujourd'hui ; celui en cours est entouré
                        C.Button {
                            id: choice
                            required property var modelData
                            readonly property string physical: modelData.physical
                            readonly property string pIcon: mappingPage.psButtons.physicalIcon(physical, mappingPage.playStation)
                            readonly property bool isCurrent: physical === buttonPicker.current
                            property bool mappingNav: true
                            navHandler: (from, key) => mappingPage.moveFocusIn(pickerGrid, from, key)
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 86
                            topInset: 0
                            bottomInset: 0
                            contentItem: ColumnLayout {
                                spacing: 6
                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 30
                                    Image {
                                        anchors.centerIn: parent
                                        visible: !!choice.pIcon
                                        width: 30
                                        height: 30
                                        sourceSize: Qt.size(60, 60)
                                        source: choice.pIcon
                                    }
                                    Text {
                                        anchors.fill: parent
                                        visible: !choice.pIcon
                                        text: mappingPage.physicalLabel(choice.physical)
                                        color: "#eef4ff"
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                    }
                                }
                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: 120
                                    text: choice.modelData.action ? mappingPage.psButtons.info(choice.modelData.action, "?").label : qsTr("No action")
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    opacity: 0.55
                                    color: choice.isCurrent ? "#9cc2ff" : "#eef4ff"
                                }
                            }
                            background: Rectangle {
                                radius: 14
                                color: Qt.rgba(0.35, 0.55, 1, choice.down ? 0.24 : (choice.isCurrent ? 0.18 : (choice.hovered ? 0.14 : 0.06)))
                                border.width: choice.visualFocus || choice.isCurrent ? 2 : 1
                                border.color: choice.visualFocus ? "#7fb0ff" : (choice.isCurrent ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.2))
                            }
                            onClicked: buttonPicker.choose(physical)
                        }
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Under each button: what it does now. If you pick a button that already does something, the two are swapped.")
                    font.pixelSize: 14
                    opacity: 0.55
                }
            }
        }

        Connections {
            target: Chiaki.controllerMapping

            function onInProgressChanged()
            {
                if(!Chiaki.controllerMapping.inProgress && !finalClosing)
                    dialog.close();
            }
        }
    }
}
