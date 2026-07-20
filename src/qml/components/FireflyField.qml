import QtQuick

// Fireflies for the Jungle scene — a handful of soft yellow-green glows that wander
// slowly and blink out of phase. Each drifts around its own home point on two summed
// sines (incommensurate, so the path never repeats) while a separate blink animation
// pulses its opacity. Index-hashed (deterministic). Inert; blocks no input.
Item {
    id: root
    property int  count: 16
    property bool running: false

    // Shared slow clock the wander paths sample (one long loop, ~90 s).
    property real t: 0
    NumberAnimation on t {
        from: 0; to: 6.2832; duration: 90000; loops: Animation.Infinite; running: root.running
    }

    function rnd(i, s) {
        var v = Math.sin((i + 1) * 127.1 + s * 311.7) * 43758.5453;
        return v - Math.floor(v);
    }

    Repeater {
        model: root.running ? root.count : 0
        delegate: Item {
            id: fly
            required property int index
            readonly property real rHX: root.rnd(index, 1.3)
            readonly property real rHY: root.rnd(index, 7.1)
            readonly property real rSp: root.rnd(index, 4.7)
            readonly property real rPh: root.rnd(index, 9.2)
            readonly property real rSz: root.rnd(index, 2.6)
            readonly property real rBl: root.rnd(index, 5.9)

            readonly property real sz: 4 + rSz * 4
            readonly property real homeX: (0.06 + rHX * 0.88) * root.width
            readonly property real homeY: (0.10 + rHY * 0.74) * root.height
            readonly property real rangeX: 40 + rHX * 70
            readonly property real rangeY: 28 + rHY * 55
            readonly property real sp: 0.6 + rSp * 1.3

            width: sz; height: sz
            x: homeX + Math.sin(root.t * sp + rPh * 6.28) * rangeX
                     + Math.sin(root.t * sp * 2.3 + rPh * 3.1) * rangeX * 0.35 - sz / 2
            y: homeY + Math.cos(root.t * sp * 0.8 + rPh * 6.28) * rangeY
                     + Math.cos(root.t * sp * 1.7 + rPh * 2.2) * rangeY * 0.4 - sz / 2

            property real glow: 0.5
            opacity: glow
            SequentialAnimation on glow {
                running: root.running; loops: Animation.Infinite
                NumberAnimation { from: 0.1; to: 1; duration: 700 + Math.round(fly.rBl * 1500); easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.12; duration: 600 + Math.round(fly.rBl * 1400); easing.type: Easing.InOutSine }
                PauseAnimation { duration: Math.round(fly.rPh * 1400) }
            }

            Rectangle { anchors.centerIn: parent; width: fly.sz * 3.4; height: width; radius: width / 2; color: "#bff05a"; opacity: 0.14 }
            Rectangle { anchors.centerIn: parent; width: fly.sz * 1.9; height: width; radius: width / 2; color: "#e6ff8c"; opacity: 0.4 }
            Rectangle { anchors.centerIn: parent; width: fly.sz; height: fly.sz; radius: fly.sz / 2; color: "#fbffd0" }
        }
    }
}
