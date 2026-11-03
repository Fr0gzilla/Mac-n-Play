// Cadre commun des pages plein écran (titre, bouton retour, bouton d'action).
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Effects
import "controls" as C

import org.streetpea.chiaking

Item {
    id: dialog
    property alias header: headerLabel.text
    property alias title: titleLabel.text
    property alias buttonText: okButton.text
    property alias buttonEnabled: okButton.enabled
    property alias buttonVisible: okButton.visible
    property Item restoreFocusItem
    default property Item mainItem: null

    signal accepted()
    signal rejected()

    function close() {
        root.closeDialog();
    }

    Keys.onEscapePressed: close()

    Keys.onMenuPressed: {
        if (okButton.enabled)
            okButton.clicked()
    }

    StackView.onDeactivating: {
        restoreFocusItem = Window.window.activeFocusItem;
    }

    StackView.onActivated: {
        if (!restoreFocusItem) {
            let item = mainItem.nextItemInFocusChain();
            if (item)
                item.forceActiveFocus(Qt.TabFocusReason);
        } else {
            restoreFocusItem.forceActiveFocus(Qt.TabFocusReason);
            restoreFocusItem = null;
        }
    }

    onMainItemChanged: {
        if (mainItem) {
            mainItem.parent = contentItem;
            mainItem.anchors.fill = contentItem;
        }
    }

    // même fond noir néon que l'accueil, en plus discret
    C.PsBackground {
        anchors.fill: parent
        count: 4
        topReserve: 70
        running: dialog.StackView.status === StackView.Active && Qt.application.state === Qt.ApplicationActive
    }

    ToolBar {
        id: toolBar
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: 64
        background: Item { }

        DragHandler {
            target: null
            onActiveChanged: if (active) Chiaki.window.startSystemMove()
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: 10 + root.titleBarInset
                rightMargin: 10
            }

            // retour : flèche dans un rond en verre
            C.GlassButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 6
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                leftPadding: 0
                rightPadding: 0
                topPadding: 0
                bottomPadding: 0
                text: "❮"
                font.pixelSize: 18
                focusPolicy: Qt.NoFocus
                onClicked: {
                    dialog.rejected();
                    dialog.close();
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                id: okButton
                Layout.fillHeight: true
                flat: true
                padding: 30
                font.pixelSize: 25
                focusPolicy: Qt.NoFocus
                Material.roundedScale: Material.SmallScale
                onClicked: dialog.accepted()
                icon.source: "qrc:/icons/options.svg";
                icon.width: 50
                icon.height: 50
            }
        }

        Label {
            id: titleLabel
            anchors.centerIn: parent
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            font.family: root.titleFontFamily
            font.weight: Font.Bold
            font.pixelSize: 22
            font.letterSpacing: 1.5
            color: "#eaf2ff"
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#0046c0"
                shadowBlur: 0.8
                shadowOpacity: 0.9
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Label {
            id: headerLabel
            anchors {
                top: parent.top
                left: titleLabel.right
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            font.pixelSize: 13
            opacity: 0.55
            // fenêtre étroite : la note passe à la ligne, puis disparaît plutôt que de chevaucher le titre
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
            visible: width > 180
        }
    }

    Item {
        id: contentItem
        anchors {
            top: toolBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }
}
