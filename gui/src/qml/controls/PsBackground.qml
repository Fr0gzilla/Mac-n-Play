// Fond animé de l'accueil : symboles ✕ ○ △ □ néon.
import QtQuick
import QtQuick.Effects

// Fond noir façon PlayStation : des ✕ ○ △ □ bleu néon apparaissent au hasard,
// brillent un instant puis s'effacent. Tout s'arrête quand « running » est faux.
Rectangle {
    id: bg
    property bool running: true
    property int count: 6
    // hauteur laissée libre en haut (barre de titre)
    property real topReserve: 0
    color: "#000000"
    clip: true

    // très léger voile bleu en haut pour que le noir ne soit pas plat
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.0, 0.12, 0.38, 0.22) }
            GradientStop { position: 0.5; color: "transparent" }
        }
    }

    Repeater {
        id: symbols
        model: bg.count
        delegate: Item {
            id: symbol
            required property int index
            readonly property var names: ["croix", "rond", "triangle", "carre"]
            property string shape: names[index % 4]
            width: 60
            height: width
            opacity: 0
            scale: 0.85

            function relocate() {
                shape = names[Math.floor(Math.random() * 4)];
                width = 34 + Math.random() * 70;
                // cherche une place libre, bien à l'écart des symboles déjà visibles
                let bestX = 0, bestY = 0, bestGap = -1;
                for (let attempt = 0; attempt < 30; attempt++) {
                    let cx = Math.random() * Math.max(0, bg.width - width);
                    let cy = bg.topReserve + Math.random() * Math.max(0, bg.height - bg.topReserve - width);
                    let gap = 1e9;
                    for (let i = 0; i < symbols.count; i++) {
                        let other = symbols.itemAt(i);
                        if (!other || other === symbol || other.opacity <= 0.01)
                            continue;
                        let dx = (cx + width / 2) - (other.x + other.width / 2);
                        let dy = (cy + width / 2) - (other.y + other.width / 2);
                        gap = Math.min(gap, Math.sqrt(dx * dx + dy * dy) - (width + other.width) / 2);
                    }
                    if (gap > bestGap) {
                        bestGap = gap; bestX = cx; bestY = cy;
                    }
                    if (gap > 220)
                        break;
                }
                x = bestX;
                y = bestY;
                rotation = (Math.random() - 0.5) * 50;
                peak = 0.35 + Math.random() * 0.5;
                hold.duration = 1500 + Math.random() * 3000;
            }
            property real peak: 0.6

            Image {
                id: glyph
                anchors.fill: parent
                source: "qrc:/icons/ps/" + symbol.shape + ".svg"
                sourceSize: Qt.size(160, 160)
                visible: false
            }

            // halo néon autour du tracé
            MultiEffect {
                anchors.fill: glyph
                source: glyph
                shadowEnabled: true
                shadowColor: "#0033a0"
                shadowBlur: 1.0
                shadowScale: 1.15
                shadowOpacity: 1.0
                blurMax: 32
            }

            Timer {
                id: wait
                running: bg.running
                interval: 500 + Math.random() * 9000
                onTriggered: {
                    symbol.relocate();
                    cycle.start();
                }
            }

            SequentialAnimation {
                id: cycle
                ParallelAnimation {
                    NumberAnimation { target: symbol; property: "opacity"; from: 0; to: symbol.peak; duration: 3200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: symbol; property: "scale"; from: 0.9; to: 1.0; duration: 3200; easing.type: Easing.InOutSine }
                }
                PauseAnimation { id: hold; duration: 2500 }
                ParallelAnimation {
                    NumberAnimation { target: symbol; property: "opacity"; to: 0; duration: 3800; easing.type: Easing.InOutSine }
                    NumberAnimation { target: symbol; property: "scale"; to: 1.05; duration: 3800; easing.type: Easing.InOutSine }
                }
                onFinished: {
                    wait.interval = 2500 + Math.random() * 7000;
                    if (bg.running)
                        wait.restart();
                }
            }
        }
    }
}
