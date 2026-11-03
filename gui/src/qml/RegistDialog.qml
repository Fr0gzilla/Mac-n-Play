// Assistant d'ajout de console en 3 étapes : choix, compte PSN, code PIN.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

import "controls" as C

// Ajouter une console : un assistant en 3 étapes (quelle console, compte PSN, code affiché par la console),
// avec à chaque fois ce qu'il faut faire. L'enregistrement lui-même ne change pas (Chiaki.consoles.registerConsole).
DialogView {
    id: regist
    property bool ps5: true
    property string host: ""
    property int step: 0
    // ancienne PS4 (système < 7.0 ou < 8.0) : réglage avancé, caché par défaut
    property int target: ps5 ? 1000100 : 1000
    readonly property bool oldPs4: target === 800
    readonly property bool hostOk: host.trim() !== ""
    readonly property bool accountOk: oldPs4 ? onlineId.text.trim() !== "" : accountId.text.trim() !== ""
    readonly property bool pinOk: pin.acceptableInput && cpin.acceptableInput

    title: qsTr("Add a console")
    buttonVisible: step === 2
    buttonText: qsTr("Pair")
    buttonEnabled: hostOk && accountOk && pinOk

    // consoles vues sur le réseau et pas encore associées
    readonly property var foundConsoles: Array.from(Chiaki.consoles.list).filter(h => h.discovered && !h.registered && !h.demo && !!h.address)

    StackView.onActivated: {
        if (Chiaki.settings.psnAccountId)
            accountId.text = Chiaki.settings.psnAccountId;
        // déjà une console choisie (bouton « Associer » d'une carte) : on passe directement au compte
        step = host && host !== "255.255.255.255" ? 1 : 0;
        Qt.callLater(focusStep);
    }
    onStepChanged: Qt.callLater(focusStep)
    function focusStep() {
        const first = [step0First, step1First, pin][step];
        if (first && first.visible)
            first.forceActiveFocus(Qt.TabFocusReason);
    }
    function chooseConsole(address, isPs5) {
        host = address;
        ps5 = isPs5;
        target = isPs5 ? 1000100 : 1000;
        step = 1;
    }

    onAccepted: {
        const psnId = oldPs4 ? onlineId.text.trim() : accountId.text.trim();
        const ok = Chiaki.consoles.registerConsole(host.trim(), psnId, pin.text.trim(), cpin.text.trim(), host.trim() === "255.255.255.255", target, function(msg, ok, done) {
            if (!done)
                logArea.text += msg + "\n";
            else {
                resultOk = ok;
                logDialog.standardButtons = Dialog.Close;
            }
        });
        if (ok) {
            logArea.text = "";
            resultOk = false;
            logDialog.open();
        }
    }
    property bool resultOk: false

    // ——— briques ———
    component StepTitle: Label {
        Layout.fillWidth: true
        font.pixelSize: 26
        font.weight: Font.DemiBold
        wrapMode: Text.WordWrap
    }
    component Explain: Label {
        Layout.fillWidth: true
        font.pixelSize: 16
        opacity: 0.7
        wrapMode: Text.WordWrap
        lineHeight: 1.15
    }
    // étape numérotée d'un mode d'emploi
    component HowTo: RowLayout {
        property int number: 1
        property alias text: howText.text
        Layout.fillWidth: true
        spacing: 14
        Rectangle {
            Layout.alignment: Qt.AlignTop
            width: 30
            height: 30
            radius: 15
            color: Qt.rgba(0.24, 0.48, 1, 0.18)
            border.width: 1
            border.color: "#3d7bff"
            Label {
                anchors.centerIn: parent
                text: number
                font.weight: Font.Bold
                color: "#9cc2ff"
            }
        }
        Label {
            id: howText
            Layout.fillWidth: true
            Layout.topMargin: 3
            font.pixelSize: 16
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
        }
    }
    // carte cliquable (console trouvée, recherche automatique…)
    component ChoiceCard: C.Button {
        id: card
        property string heading: ""
        property string detail: ""
        property string image: ""
        Layout.fillWidth: true
        implicitHeight: 84
        topInset: 0
        bottomInset: 0
        background: Rectangle {
            radius: 18
            color: card.visualFocus || card.hovered ? Qt.rgba(0.24, 0.48, 1, 0.16) : Qt.rgba(0.35, 0.55, 1, 0.05)
            border.width: card.visualFocus ? 2 : 1
            border.color: card.visualFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.18)
        }
        contentItem: RowLayout {
            spacing: 18
            Image {
                visible: card.image !== ""
                Layout.preferredWidth: 70
                Layout.preferredHeight: 40
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(140, 80)
                source: card.image
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label {
                    text: card.heading
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.detail
                    font.pixelSize: 14
                    opacity: 0.6
                    wrapMode: Text.WordWrap
                }
            }
            Label {
                text: "›"
                font.pixelSize: 28
                opacity: 0.5
            }
        }
    }

    Item {
        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: page.implicitHeight + 60
            flickableDirection: Flickable.AutoFlickIfNeeded
            ScrollBar.vertical: C.PsScrollBar { visible: flick.contentHeight > flick.height }

            ColumnLayout {
                id: page
                anchors { top: parent.top; topMargin: 10; horizontalCenter: parent.horizontalCenter }
                width: Math.min(flick.width - 64, 760)
                spacing: 18

                // progression : 1 Console · 2 Compte · 3 Code
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 6
                    spacing: 10
                    Repeater {
                        model: [qsTr("Console"), qsTr("PSN account"), qsTr("Code")]
                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: index <= regist.step ? "#2f7dff" : Qt.rgba(1, 1, 1, 0.08)
                                border.width: index === regist.step ? 2 : 0
                                border.color: "#9cc2ff"
                                Label {
                                    anchors.centerIn: parent
                                    text: index < regist.step ? "✓" : index + 1
                                    font.weight: Font.Bold
                                }
                            }
                            Label {
                                text: modelData
                                font.pixelSize: 15
                                opacity: index === regist.step ? 1.0 : 0.5
                                font.weight: index === regist.step ? Font.DemiBold : Font.Normal
                            }
                            Rectangle {
                                visible: index < 2
                                width: 40
                                height: 2
                                radius: 1
                                color: index < regist.step ? "#2f7dff" : Qt.rgba(1, 1, 1, 0.15)
                            }
                        }
                    }
                }

                // ——— étape 1 : quelle console ———
                ColumnLayout {
                    visible: regist.step === 0
                    Layout.fillWidth: true
                    spacing: 14

                    StepTitle { text: qsTr("Which console do you want to add?") }
                    Explain { text: qsTr("Turn on your PS4 or PS5 and connect it to the same Wi-Fi network as this Mac. It then appears below on its own.") }

                    Repeater {
                        model: regist.foundConsoles
                        ChoiceCard {
                            heading: modelData.name
                            detail: (modelData.ps5 ? "PS5" : "PS4") + (Chiaki.settings.streamerMode ? "" : "  ·  " + modelData.address)
                            image: "image://svg/console-ps" + (modelData.ps5 ? "5" : "4") + "#light_on"
                            onClicked: regist.chooseConsole(modelData.address, modelData.ps5)
                        }
                    }

                    // aucune console trouvée : on cherche, avec le petit point qui pulse
                    RowLayout {
                        visible: regist.foundConsoles.length === 0
                        Layout.fillWidth: true
                        spacing: 12
                        BusyIndicator {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            running: visible
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Looking for consoles on your network…")
                            font.pixelSize: 16
                            opacity: 0.7
                            wrapMode: Text.WordWrap
                        }
                    }

                    Label {
                        Layout.topMargin: 8
                        text: qsTr("NOT IN THE LIST?")
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        color: "#9cc2ff"
                    }
                    ChoiceCard {
                        id: step0First
                        heading: qsTr("Search the whole network for a PS4")
                        detail: qsTr("If your console does not show up, the Mac asks every device on the network.")
                        onClicked: regist.chooseConsole("255.255.255.255", false)
                    }
                    ChoiceCard {
                        heading: qsTr("Search the whole network for a PS5")
                        onClicked: regist.chooseConsole("255.255.255.255", true)
                    }

                    // adresse à la main (réseau particulier)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        C.TextField {
                            id: manualAddress
                            Layout.fillWidth: true
                            placeholderText: qsTr("Or type its IP address, e.g. 192.168.1.60")
                            echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                        }
                        C.Button {
                            text: "PS4"
                            enabled: manualAddress.text.trim() !== ""
                            onClicked: regist.chooseConsole(manualAddress.text.trim(), false)
                        }
                        C.Button {
                            text: "PS5"
                            enabled: manualAddress.text.trim() !== ""
                            onClicked: regist.chooseConsole(manualAddress.text.trim(), true)
                        }
                    }
                    Explain {
                        font.pixelSize: 14
                        text: qsTr("The IP address is shown on the console in Settings › Network › View Connection Status.")
                    }
                }

                // ——— étape 2 : compte PSN ———
                ColumnLayout {
                    visible: regist.step === 1
                    Layout.fillWidth: true
                    spacing: 14

                    StepTitle { text: qsTr("Your PlayStation Network account") }
                    Explain { text: qsTr("The console only accepts the account signed in on it. Mac'n'Play needs its identifier, which it gets by connecting to PSN.") }

                    // déjà connecté : rien à faire
                    Rectangle {
                        visible: !regist.oldPs4 && accountId.text.trim() !== ""
                        Layout.fillWidth: true
                        implicitHeight: 70
                        radius: 18
                        color: Qt.rgba(0.29, 0.87, 0.5, 0.10)
                        border.width: 1
                        border.color: Qt.rgba(0.29, 0.87, 0.5, 0.5)
                        RowLayout {
                            anchors { fill: parent; leftMargin: 20; rightMargin: 20 }
                            spacing: 14
                            Label { text: "✓"; font.pixelSize: 24; color: "#4ade80" }
                            Label {
                                Layout.fillWidth: true
                                text: Chiaki.psn.profile.onlineId ? qsTr("Ready: connected as %1").arg(Chiaki.psn.profile.onlineId) : qsTr("Ready: your PSN account is connected")
                                font.pixelSize: 17
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    C.Button {
                        id: step1First
                        visible: !regist.oldPs4
                        Layout.alignment: Qt.AlignLeft
                        text: accountId.text.trim() !== "" ? qsTr("Use another account") : qsTr("Connect to PSN")
                        onClicked: stack.push(psnLoginDialogComponent, {login: true, callback: (id) => accountId.text = id})
                    }
                    Explain {
                        visible: !regist.oldPs4 && accountId.text.trim() === ""
                        font.pixelSize: 14
                        text: qsTr("A Sony page opens: sign in, then copy the address of the page that says « redirect » and paste it in Mac'n'Play.")
                    }

                    // identifiant gardé, modifiable à la main au besoin
                    C.TextField {
                        id: accountId
                        visible: false
                    }

                    // ancienne PS4 : réglages avancés
                    C.CheckBox {
                        visible: !regist.ps5
                        Layout.topMargin: 10
                        text: qsTr("My PS4 system software is older than 8.0")
                        checked: regist.target !== 1000 && !regist.ps5
                        onToggled: regist.target = checked ? 900 : 1000
                    }
                    ColumnLayout {
                        visible: !regist.ps5 && regist.target !== 1000
                        Layout.fillWidth: true
                        spacing: 8
                        C.RadioButton {
                            text: qsTr("Version 7.0 to 7.99")
                            checked: regist.target === 900
                            onToggled: if (checked) regist.target = 900
                        }
                        C.RadioButton {
                            text: qsTr("Older than 7.0")
                            checked: regist.target === 800
                            onToggled: if (checked) regist.target = 800
                        }
                        C.TextField {
                            id: onlineId
                            visible: regist.oldPs4
                            Layout.fillWidth: true
                            placeholderText: qsTr("Your PSN online ID (case-sensitive)")
                            echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                        }
                    }

                    RowLayout {
                        Layout.topMargin: 10
                        spacing: 12
                        C.Button {
                            text: "‹  " + qsTr("Back")
                            onClicked: regist.step = 0
                        }
                        C.Button {
                            text: qsTr("Next") + "  ›"
                            enabled: regist.accountOk
                            onClicked: regist.step = 2
                        }
                    }
                }

                // ——— étape 3 : code affiché par la console ———
                ColumnLayout {
                    visible: regist.step === 2
                    Layout.fillWidth: true
                    spacing: 14

                    StepTitle { text: qsTr("Enter the code shown by your console") }
                    HowTo {
                        number: 1
                        text: regist.ps5
                            ? qsTr("On the PS5, go to <b>Settings › System › Remote Play</b>.")
                            : qsTr("On the PS4, go to <b>Settings › Remote Play Connection Settings</b>.")
                    }
                    HowTo {
                        number: 2
                        text: regist.ps5 ? qsTr("Choose <b>Link Device</b>.") : qsTr("Choose <b>Add Device</b>.")
                    }
                    HowTo {
                        number: 3
                        text: qsTr("An <b>8-digit code</b> appears. Type it below within a few minutes, then press <b>Pair</b>.")
                    }

                    C.TextField {
                        id: pin
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        font.pixelSize: 28
                        font.letterSpacing: 6
                        horizontalAlignment: Text.AlignHCenter
                        placeholderText: "_ _ _ _ _ _ _ _"
                        inputMethodHints: Qt.ImhDigitsOnly
                        maximumLength: 8
                        validator: RegularExpressionValidator { regularExpression: /[0-9]{8}/ }
                        echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                        Keys.onReturnPressed: if (regist.buttonEnabled) regist.accepted()
                    }

                    // code à 4 chiffres de la console : facultatif
                    C.CheckBox {
                        id: hasConsolePin
                        text: qsTr("My console asks for a 4-digit login code")
                    }
                    C.TextField {
                        id: cpin
                        visible: hasConsolePin.checked
                        Layout.fillWidth: true
                        placeholderText: qsTr("4-digit console code")
                        maximumLength: 4
                        validator: RegularExpressionValidator { regularExpression: /^$|[0-9]{4}/ }
                        echoMode: Chiaki.settings.streamerMode ? TextInput.Password : TextInput.Normal
                    }

                    RowLayout {
                        Layout.topMargin: 10
                        spacing: 12
                        C.Button {
                            text: "‹  " + qsTr("Back")
                            onClicked: regist.step = 1
                        }
                        C.Button {
                            text: qsTr("Pair")
                            enabled: regist.buttonEnabled
                            onClicked: regist.accepted()
                        }
                    }
                }
            }
        }

        // déroulement de l'association, puis le résultat en clair
        Item {
            Dialog {
                id: logDialog
                parent: Overlay.overlay
                x: Math.round((root.width - width) / 2)
                y: Math.round((root.height - height) / 2)
                title: logDialog.standardButtons === Dialog.Close
                    ? (regist.resultOk ? qsTr("Console added!") : qsTr("Pairing failed"))
                    : qsTr("Pairing…")
                modal: true
                closePolicy: Popup.NoAutoClose
                standardButtons: Dialog.Cancel
                Material.roundedScale: Material.MediumScale
                onOpened: logArea.forceActiveFocus(Qt.TabFocusReason)
                onClosed: stack.pop();

                ColumnLayout {
                    implicitWidth: 600
                    spacing: 12
                    Label {
                        Layout.fillWidth: true
                        visible: logDialog.standardButtons === Dialog.Close
                        wrapMode: Text.WordWrap
                        font.pixelSize: 16
                        text: regist.resultOk
                            ? qsTr("Your console now appears on the home screen. Press ✕ on it to play.")
                            : qsTr("Check that the console is on, on the same network, and that the 8-digit code is still shown, then try again.")
                    }
                    Flickable {
                        id: logFlick
                        Layout.fillWidth: true
                        implicitHeight: 260
                        clip: true
                        contentWidth: logArea.contentWidth
                        contentHeight: logArea.contentHeight
                        flickableDirection: Flickable.AutoFlickIfNeeded
                        ScrollBar.vertical: C.PsScrollBar {
                            id: logScrollbar
                            policy: ScrollBar.AsNeeded
                            visible: logFlick.contentHeight > logFlick.height
                        }
                        Label {
                            id: logArea
                            width: logFlick.width
                            wrapMode: TextEdit.Wrap
                            font.pixelSize: 13
                            opacity: 0.6
                            Keys.onReturnPressed: if (logDialog.standardButtons == Dialog.Close) logDialog.close()
                            Keys.onEscapePressed: logDialog.close()
                            Keys.onPressed: (event) => {
                                switch (event.key) {
                                case Qt.Key_Up:
                                    if (logScrollbar.position > 0.001)
                                        logFlick.flick(0, 500);
                                    event.accepted = true;
                                    break;
                                case Qt.Key_Down:
                                    if (logScrollbar.position < 1.0 - logScrollbar.size - 0.001)
                                        logFlick.flick(0, -500);
                                    event.accepted = true;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: psnLoginDialogComponent
            PSNLoginDialog { }
        }
    }
}
