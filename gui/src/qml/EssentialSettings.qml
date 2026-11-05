// Page « L'essentiel » des Paramètres : les réglages utiles à tous, par console.
import QtCore
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material

import org.streetpea.chiaking

import "controls" as C

// Page « L'essentiel » des Paramètres : les quelques réglages utiles à tout le monde,
// regroupés par thème. Les réglages détaillés restent dans « Tous les réglages ».
Flickable {
    id: essentials
    // console réglée : d'abord une console associée et allumée, sinon une console associée, sinon une console vue sur le réseau
    // console choisie en haut des Paramètres (s'il y en a plusieurs) : ses réglages propres sont affichés ici
    property var selectedConsole: null
    readonly property string consoleTag: selectedConsole ? selectedConsole.name : ""
    readonly property var detectedHost: {
        if (selectedConsole)
            return selectedConsole;
        // règle MacnPlayRules::settingsConsoleIndex : une console associée d'abord
        const list = Chiaki.consoles.list;
        const i = Chiaki.consoles.settingsConsoleIndex(list);
        return i >= 0 ? list[i] : null;
    }
    // console dont on règle l'image (0 = PS4, 1 = PS5), partagée avec la page détaillée
    readonly property int consoleIndex: detectedHost && !detectedHost.ps5 ? 0 : 1
    signal openAdvanced(int tab)
    // 2 consoles : le △ à côté de la console passe à l'autre
    signal switchConsole()

    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight + 40
    flickableDirection: Flickable.AutoFlickIfNeeded
    ScrollBar.vertical: C.PsScrollBar {
        policy: ScrollBar.AsNeeded
    }

    readonly property bool ps4: consoleIndex === 0

    // PS4 Pro : la console ne le dit pas, l'utilisateur le coche ; retenu par console (Chiaki.settings)
    property int ps4ProRevision: 0
    Connections {
        target: Chiaki.settings
        function onPs4ProHostsChanged() { essentials.ps4ProRevision++; }
    }
    readonly property bool ps4Pro: ps4 && !!detectedHost && (ps4ProRevision, Chiaki.settings.isPs4Pro(detectedHost.mac))
    function setPs4Pro(pro) {
        if (detectedHost)
            Chiaki.settings.setPs4Pro(detectedHost.mac, pro);
    }


    component SectionTitle: Label {
        Layout.topMargin: 18
        font.pixelSize: 15
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
        color: "#9cc2ff"
    }

    component SettingRow: RowLayout {
        property alias title: rowTitle.text
        property alias hint: rowHint.text
        // nom de la console à qui ce réglage est propre (pastille à côté du titre)
        property string consoleTag: ""
        default property alias control: holder.data
        Layout.fillWidth: true
        spacing: 24
        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                spacing: 10
                Label {
                    id: rowTitle
                    font.weight: Font.Medium
                }
                Rectangle {
                    visible: consoleTag !== ""
                    implicitWidth: tagLabel.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Qt.rgba(0.24, 0.48, 1, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(0.36, 0.56, 0.88, 0.6)
                    Label {
                        id: tagLabel
                        anchors.centerIn: parent
                        text: qsTr("for %1").arg(consoleTag)
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        color: "#9cc2ff"
                    }
                }
            }
            Label {
                id: rowHint
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                font.pixelSize: 14
                opacity: 0.5
                visible: text !== ""
            }
        }
        Item {
            id: holder
            Layout.preferredWidth: Math.min(400, column.width * 0.5)
            Layout.preferredHeight: 46
        }
    }

    ColumnLayout {
        id: column
        anchors {
            top: parent.top
            topMargin: 20
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.min(820, essentials.width - 64)
        spacing: 14

        SectionTitle { text: qsTr("IMAGE") }

        SettingRow {
            title: qsTr("Console")
            hint: essentials.selectedConsole ? qsTr("Press △ to switch console. Settings marked with its name only apply to it.")
                : (essentials.detectedHost ? qsTr("Detected automatically. The settings below apply to it.") : qsTr("No console detected yet."))

            // la console réglée ; avec 2 consoles, un clic (ou △) passe à l'autre
            Rectangle {
                id: consolePill
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: detectedRow.implicitWidth + 32
                height: 46
                radius: height / 2
                color: essentials.detectedHost ? Qt.rgba(0.0, 0.27, 0.75, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.width: essentials.detectedHost ? 2 : 1
                border.color: essentials.detectedHost ? "#3d7bff" : Qt.rgba(1, 1, 1, 0.2)

                Row {
                    id: detectedRow
                    anchors.centerIn: parent
                    spacing: 12
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !!essentials.detectedHost
                        width: 54
                        height: 26
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(108, 52)
                        source: "image://svg/console-ps" + (essentials.ps4 ? "4" : "5") + "#light_on"
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: essentials.detectedHost
                            ? (essentials.ps4 ? (essentials.ps4Pro ? "PS4 Pro" : "PS4") : "PS5") + "  ·  " + essentials.detectedHost.name
                            : qsTr("Waiting for a console…")
                        font.weight: Font.DemiBold
                        color: essentials.detectedHost ? "#9cc2ff" : "#ffffff"
                        opacity: essentials.detectedHost ? 1.0 : 0.6
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !!essentials.selectedConsole
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: essentials.switchConsole()
                }
            }
            // △ : changer de console (seulement avec 2 consoles)
            Rectangle {
                visible: !!essentials.selectedConsole
                anchors { left: consolePill.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                width: 46
                height: 46
                radius: 23
                color: Qt.rgba(1, 1, 1, triMouse.containsMouse ? 0.14 : 0.07)
                border.width: 1
                border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
                Image {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    sourceSize: Qt.size(56, 56)
                    source: root.controllerButton("pyramid")
                }
                MouseArea {
                    id: triMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: essentials.switchConsole()
                }
            }
        }

        SettingRow {
            title: qsTr("PS4 Pro")
            consoleTag: essentials.consoleTag
            hint: qsTr("A PS4 Pro can stream in 1080p. The console does not tell, so tick it yourself.")
            visible: essentials.ps4 && !!essentials.detectedHost
            C.CheckBox {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                firstInFocusChain: true
                text: qsTr("My console is a PS4 Pro")
                checked: essentials.ps4Pro
                onToggled: essentials.setPs4Pro(checked)
            }
        }

        SettingRow {
            title: qsTr("Image quality")
            consoleTag: essentials.consoleTag
            hint: qsTr("Higher is sharper but needs a better connection.")
            C.ComboBox {
                id: qualityCombo
                // sur PS4, la case « PS4 Pro » au-dessus reste joignable avec ↑
                firstInFocusChain: !(essentials.ps4 && !!essentials.detectedHost)
                anchors.fill: parent
                model: essentials.ps4
                    ? [qsTr("360p"), qsTr("540p"), qsTr("720p (Default)"), qsTr("1080p (PS5 and PS4 Pro)")]
                    : [qsTr("360p"), qsTr("540p"), qsTr("720p"), qsTr("1080p (Default)")]
                // 1080p reste affiché sur PS4, mais grisé
                disabledIndexes: essentials.ps4 && !essentials.ps4Pro ? [3] : []
                currentIndex: essentials.ps4 && !essentials.ps4Pro ? Math.min(Chiaki.settings.resolutionLocalPS4, 3) - 1 : (essentials.ps4 ? Chiaki.settings.resolutionLocalPS4 : Chiaki.settings.resolutionLocalPS5) - 1
                onActivated: (index) => {
                    if (disabledIndexes.indexOf(index) >= 0)
                        return;
                    // même choix pour les parties à la maison et à distance (via le PSN)
                    if (essentials.ps4) {
                        Chiaki.settings.resolutionLocalPS4 = index + 1;
                        Chiaki.settings.resolutionRemotePS4 = index + 1;
                        Chiaki.settings.bitrateLocalPS4 = 0;
                        Chiaki.settings.bitrateRemotePS4 = 0;
                    } else {
                        Chiaki.settings.resolutionLocalPS5 = index + 1;
                        Chiaki.settings.resolutionRemotePS5 = index + 1;
                        Chiaki.settings.bitrateLocalPS5 = 0;
                        Chiaki.settings.bitrateRemotePS5 = 0;
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Smoothness")
            consoleTag: essentials.consoleTag
            hint: qsTr("60 fps is smoother, 30 fps is lighter on the network.")
            C.ComboBox {
                anchors.fill: parent
                model: [qsTr("30 fps"), qsTr("60 fps (Default)")]
                currentIndex: ((essentials.ps4 ? Chiaki.settings.fpsLocalPS4 : Chiaki.settings.fpsLocalPS5) / 30) - 1
                onActivated: (index) => {
                    if (essentials.ps4) {
                        Chiaki.settings.fpsLocalPS4 = (index + 1) * 30;
                        Chiaki.settings.fpsRemotePS4 = (index + 1) * 30;
                    } else {
                        Chiaki.settings.fpsLocalPS5 = (index + 1) * 30;
                        Chiaki.settings.fpsRemotePS5 = (index + 1) * 30;
                    }
                }
            }
        }

        SettingRow {
            title: qsTr("Rendering")
            hint: qsTr("How the Mac enlarges the picture. Sharper uses more graphics power.")
            C.ComboBox {
                anchors.fill: parent
                // noms courts : les noms complets restent dans « Tous les réglages › Vidéo »
                model: [qsTr("Fast"), qsTr("Default"), qsTr("High Quality"), qsTr("High Quality + sharper"), qsTr("Sharpest"), qsTr("Custom")]
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
        }

        SectionTitle { text: qsTr("PLAYING") }

        SettingRow {
            title: qsTr("Game window")
            hint: qsTr("Fullscreen keeps the picture intact, Zoom fills the screen by trimming the edges.")
            C.ComboBox {
                anchors.fill: parent
                // trois choix simples ; les autres restent dans « Tous les réglages › Vidéo »
                model: [qsTr("Window"), qsTr("Fullscreen"), qsTr("Zoom (no black bars)")]
                currentIndex: {
                    switch (Chiaki.settings.windowType) {
                    case 0: case 1: case 2: return 0; // fenêtre
                    case 3: return 1;                 // plein écran
                    case 4: return 2;                 // zoom
                    default: return -1;               // « Étirer », réglé dans la page détaillée
                    }
                }
                onActivated: (index) => Chiaki.settings.windowType = [2, 3, 4][index]
            }
        }

        SettingRow {
            title: qsTr("When you quit a game")
            consoleTag: essentials.consoleTag
            hint: qsTr("What the console does when the session ends.")
            C.ComboBox {
                anchors.fill: parent
                model: [qsTr("Do Nothing"), qsTr("Enter Sleep Mode"), qsTr("Ask")]
                currentIndex: Chiaki.settings.disconnectAction
                onActivated: (index) => Chiaki.settings.disconnectAction = index
            }
        }

        SectionTitle { text: qsTr("ACCOUNT AND CONTROLLERS") }

        SettingRow {
            title: qsTr("PlayStation Network")
            hint: Chiaki.psn.connected ? qsTr("Connected: automatic pairing and play away from home.") : qsTr("Not connected.")
            C.Button {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: Chiaki.psn.connected ? qsTr("Reconnect") : qsTr("Connect to PSN")
                onClicked: root.showPSNTokenDialog(false)
            }
        }

        SettingRow {
            title: qsTr("Controllers")
            hint: qsTr("Button layout, vibration and motion.")
            C.Button {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: qsTr("Controller settings") + "  ›"
                lastInFocusChain: true
                onClicked: essentials.openAdvanced(6)
            }
        }

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 24
            text: qsTr("Need more? Open « All settings » at the top.")
            font.pixelSize: 14
            opacity: 0.45
        }
    }

    function focusFirst() {
        contentY = 0;
        qualityCombo.forceActiveFocus(Qt.TabFocusReason);
    }
    Component.onCompleted: focusFirst()
}
