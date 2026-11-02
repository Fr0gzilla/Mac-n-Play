import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects

ComboBox {
    property bool firstInFocusChain: false
    property bool lastInFocusChain: false
    implicitContentWidthPolicy: ComboBox.WidestText

    Keys.onPressed: (event) => {
        switch (event.key) {
        case Qt.Key_Up:
            if (!popup.visible) {
                let item = nextItemInFocusChain(false);
                if (!firstInFocusChain && item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
            break;
        case Qt.Key_Down:
            if (!popup.visible) {
                let item = nextItemInFocusChain();
                if (!lastInFocusChain && item)
                    item.forceActiveFocus(Qt.TabFocusReason);
                event.accepted = true;
            }
            break;
        // ← / → ne changent pas la valeur : on ouvre la liste avec ✕ puis on choisit dedans
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (!popup.visible && !KeyNavigation.left && !KeyNavigation.right)
                event.accepted = true;
            break;
        case Qt.Key_Return:
            if (popup.visible) {
                // un choix grisé ne se sélectionne pas : la liste reste ouverte
                if (disabledIndexes.indexOf(highlightedIndex) < 0) {
                    activated(highlightedIndex);
                    popup.close();
                }
            } else {
                popup.open();
            }
            event.accepted = true;
            break;
        }
    }

    Keys.onReleased: (event) => {
        if (event.key == Qt.Key_Return)
            event.accepted = true;
    }

    // pilule en verre au contour bleu, liste déroulante en verre sombre
    id: combo
    // choix affichés mais grisés, impossibles à sélectionner
    property var disabledIndexes: []
    Material.foreground: "#eef4ff"
    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 46
        radius: 14
        color: Qt.rgba(0.35, 0.55, 1, combo.hovered || combo.popup.visible ? 0.12 : 0.07)
        border.width: combo.visualFocus || combo.popup.visible ? 2 : 1
        border.color: combo.visualFocus || combo.popup.visible ? "#3d7bff" : Qt.rgba(0.6, 0.75, 1, 0.25)
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    // liste déroulante : fond opaque, s'ouvre sous le menu avec un petit fondu
    popup.y: combo.height + 6
    popup.padding: 6
    popup.background: Rectangle {
        radius: 16
        color: "#0a1430"
        border.width: 1
        border.color: Qt.rgba(0.6, 0.75, 1, 0.3)
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.8
            shadowOpacity: 0.7
            shadowVerticalOffset: 6
            shadowHorizontalOffset: 0
        }
    }
    popup.enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
    popup.exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: 100 }
    }

    // une ligne : pastille arrondie, contour néon sous la souris ou la manette, ✓ sur le choix actuel
    delegate: ItemDelegate {
        id: row
        required property int index
        readonly property bool current: combo.currentIndex === index
        width: ListView.view ? ListView.view.width : implicitWidth
        height: 44
        enabled: combo.disabledIndexes.indexOf(index) < 0
        highlighted: enabled && combo.highlightedIndex === index
        leftPadding: 16
        rightPadding: 14
        contentItem: Item {
            Label {
                anchors { left: parent.left; right: check.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                text: combo.textAt(row.index)
                elide: Text.ElideRight
                font.pixelSize: combo.font.pixelSize
                font.weight: row.current ? Font.DemiBold : Font.Normal
                color: row.current ? "#9cc2ff" : "#eef4ff"
                opacity: row.enabled ? 1.0 : 0.35
            }
            Label {
                id: check
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "✓"
                visible: row.current
                color: "#9cc2ff"
                font.pixelSize: combo.font.pixelSize
            }
        }
        background: Rectangle {
            radius: 10
            color: row.enabled && (row.highlighted || row.hovered) ? Qt.rgba(0.0, 0.27, 0.75, 0.18) : "transparent"
            border.width: row.highlighted ? 2 : 0
            border.color: "#3d7bff"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
    }
}
