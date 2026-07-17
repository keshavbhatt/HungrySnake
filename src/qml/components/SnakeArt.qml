import QtQuick
import HungrySnake

// A static "portrait" of the snake for Store previews: a tapered body tube plus the
// head, built to the same recipe as the board's head (top-lit capsule gradient, a
// darker snout cap over the front third, a 13% seam on the shadow flank, glossy eyes
// with catchlights, nostrils). It faces right.
//
// This is deliberately a separate, static piece rather than the live board head —
// that one is welded to game state (heading, mouthOpen, blink, look-at-apple). Keep
// the palette maths here in step with Board.qml if the head's look ever changes.
Item {
    id: root
    property color head:  Theme.headGreen
    property color snout: Theme.snoutCap
    property color light: Theme.snakeLight
    property color dark:  Theme.snakeDark
    property color nose:  Theme.snakeNose

    implicitWidth: 120
    implicitHeight: 44

    readonly property real hwid: height * 0.92                 // head width (cross-axis)
    readonly property real hlen: hwid * 1.15                   // head length (along travel)
    readonly property real hr:   Math.min(hlen, hwid) * 0.30

    // ── Body tube: neck-light → tail-dark, round-capped, sitting behind the head ──
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: parent.width - root.hlen * 0.55
        height: root.hwid * 0.75
        radius: height / 2
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.dark }
            GradientStop { position: 1.0; color: root.light }
        }
    }

    // ── Head ──
    Item {
        id: hd
        width: root.hlen; height: root.hwid
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width - root.hlen

        Rectangle {                                   // top-lit capsule
            anchors.fill: parent
            radius: root.hr
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0;  color: Qt.lighter(root.head, 1.24) }
                GradientStop { position: 0.42; color: root.head }
                GradientStop { position: 1.0;  color: Qt.darker(root.head, 1.28) }
            }
        }
        Item {                                        // snout cap over the front third
            x: root.hlen * 0.6; width: root.hlen * 0.4; height: root.hwid; clip: true
            Rectangle {
                x: -root.hlen * 0.6; width: root.hlen; height: root.hwid
                radius: root.hr; color: root.snout
            }
        }
        Item {                                        // 13% seam on the shadow flank
            y: root.hwid * 0.5; width: root.hlen; height: root.hwid * 0.5; clip: true
            Rectangle {
                y: -root.hwid * 0.5; width: root.hlen; height: root.hwid
                radius: root.hr; color: Qt.rgba(0, 0, 0, 0.13)
            }
        }
        Repeater {                                    // nostrils
            model: [0.28, 0.72]
            delegate: Rectangle {
                required property real modelData
                readonly property real nr: root.hwid * 0.055
                width: nr * 2; height: nr * 2; radius: nr
                x: root.hlen * 0.80 - nr
                y: root.hwid * modelData - nr
                color: root.nose
                antialiasing: true
            }
        }
        Repeater {                                    // eyes (looking forward)
            model: [0.14, 0.86]
            delegate: Item {
                required property real modelData
                readonly property real er: root.hwid * 0.20
                x: root.hlen * 0.44 - er
                y: root.hwid * modelData - er
                width: er * 2; height: er * 2
                transform: Scale { origin.x: er; origin.y: er; yScale: 1.16 }
                Rectangle {                           // glossy eyeball
                    anchors.fill: parent; radius: width / 2; antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#eef6e3" }
                        GradientStop { position: 1.0; color: "#c7deb0" }
                    }
                }
                Rectangle {                           // pupil, biased forward
                    width: parent.width * 0.56; height: width; radius: width / 2
                    x: parent.width * 0.39; y: parent.height * 0.22
                    color: "#161616"; antialiasing: true
                    Rectangle {
                        width: parent.width * 0.42; height: width; radius: width / 2
                        x: parent.width * 0.1; y: parent.height * 0.08
                        color: "#ffffff"; antialiasing: true
                    }
                }
            }
        }
    }
}
