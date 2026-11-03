// Boîte de confirmation (Oui / Non) utilisée par toute l'appli.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "controls" as C

Dialog {
    id: dialog
    property alias text: label.text
    property var callback
    property var rejectCallback
    property bool newDialogOpen: false
    property Item restoreFocusItem
    parent: Overlay.overlay
    x: Math.round((root.width - width) / 2)
    y: Math.round((root.height - height) / 2)
    modal: true
    Material.roundedScale: Material.MediumScale
    background: C.GlassBackground { }
    Overlay.modal: C.GlassScrim { source: root.blurSource }
    padding: 32
    onOpened: label.forceActiveFocus(Qt.TabFocusReason)
    onAccepted: {
        newDialogOpen = true;
        restoreFocus();
        callback();
    }
    onClosed: if(!newDialogOpen) { restoreFocus() }

    onRejected: {
        if(rejectCallback)
        {
            newDialogOpen = true;
            restoreFocus();
            rejectCallback();
        }
    }

    function restoreFocus() {
        if (restoreFocusItem)
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
        label.focus = false;
    }

    Component.onCompleted: {
        header.horizontalAlignment = Text.AlignHCenter;
        // Qt 6.6: Workaround dialog background becoming immediately transparent during close animation
        header.background = null;
        header.font.pixelSize = 26;
        header.font.weight = Font.DemiBold;
        header.topPadding = 28;
    }

    ColumnLayout {
        spacing: 20

        Label {
            id: label
            Layout.maximumWidth: Math.min(root.width * 0.7, 1100)
            wrapMode: Text.Wrap
            lineHeight: 1.2
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            opacity: 0.9
            Keys.onEscapePressed: dialog.reject()
            Keys.onReturnPressed: dialog.accept()
        }

        RowLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.topMargin: 8
            spacing: 16

            C.GlassButton {
                text: qsTr("Yes")
                primary: true
                badge: root.controllerButton("cross")
                onClicked: dialog.accept()
            }

            C.GlassButton {
                text: qsTr("No")
                primary: false
                badge: root.controllerButton("moon")
                onClicked: dialog.reject()
            }
        }
    }
}
