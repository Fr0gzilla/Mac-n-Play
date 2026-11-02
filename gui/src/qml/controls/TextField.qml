import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

TextField {
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    property bool sendOutput: false
    readOnly: true

    onActiveFocusChanged: {
        if (!activeFocus)
            readOnly = true;
    }

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
            if (!firstInFocusChain && readOnly) {
                let item = nextItemInFocusChain(false);
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                if(!sendOutput)
                    event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (!lastInFocusChain && readOnly) {
                let item = nextItemInFocusChain();
                if (item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                if(!sendOutput)
                    event.accepted = true;
            }
            break;
        case Qt.Key_Return:
            if (readOnly) {
                readOnly = false;
                Qt.inputMethod.show();
                event.accepted = true;
            } else {
                readOnly = true;
            }
            break;
        case Qt.Key_Escape:
            if (!readOnly) {
                readOnly = true;
                editingFinished();
                event.accepted = true;
            }
            break;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: parent.readOnly
        onClicked: {
            parent.forceActiveFocus(Qt.TabFocusReason);
            parent.readOnly = false;
            Qt.inputMethod.show();
        }
    }

    // champ en verre ; contour bleu quand on écrit dedans
    id: glassField
    leftPadding: 16
    rightPadding: 16
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 46
        radius: 14
        color: Qt.rgba(0.35, 0.55, 1, glassField.activeFocus ? 0.12 : 0.07)
        border.width: glassField.activeFocus ? 2 : 1
        border.color: glassField.activeFocus ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.25)
    }
}
