// Onglet Touches : boutons de la manette et du clavier pour naviguer et jouer.
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
    // Keys
    id: controllerMapping
    // sous-onglet : 0 = manette, 1 = clavier et souris
    property alias keyboardAsControllerItem: keyboardAsController
    property alias keysFlickItem: keysFlick
    property alias padFlickItem: padFlick
    property alias controllerMappingChangeItem: controllerMappingChange
    property alias controllerMappingResetItem: controllerMappingReset
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
