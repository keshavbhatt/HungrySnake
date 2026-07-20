import QtQuick

// A field of soft glowing particles drifting vertically — powers rising embers and
// floating dust motes. Each particle is a bright core wrapped in two faint halos, on
// its own hashed size / speed / sway / flicker (deterministic, no Math.random). A sine
// envelope fades each one in and out over its travel so nothing pops at the edges.
// Inert — draws no input, blocks nothing.
Item {
    id: root
    property int   count: 40
    property bool  running: false
    property real  minSize: 3
    property real  maxSize: 8
    property color core: "#ffd98a"
    property color glow: "#ff6a2a"
    property int   durMin: 6000
    property int   durMax: 12000
    property int   direction: -1        // -1 rises, +1 falls
    property real  swayMax: 40
    property bool  flicker: true
    property real  baseOpacity: 0.9

    function rnd(i, s) {
        var v = Math.sin((i + 1) * 127.1 + s * 311.7) * 43758.5453;
        return v - Math.floor(v);
    }

    Repeater {
        model: root.running ? root.count : 0
        delegate: Item {
            id: pt
            required property int index
            readonly property real rSize:  root.rnd(index, 1.7)
            readonly property real rPhase: root.rnd(index, 4.1)
            readonly property real rX:     root.rnd(index, 6.7)
            readonly property real rAmp:   root.rnd(index, 2.9)
            readonly property real rFreq:  root.rnd(index, 8.5)
            readonly property real rDur:   root.rnd(index, 5.2)
            readonly property real rFlk:   root.rnd(index, 3.3)

            readonly property real sz: root.minSize + rSize * (root.maxSize - root.minSize)
            width: sz; height: sz
            transformOrigin: Item.Center

            property real prog: 0
            readonly property real p: (prog + rPhase) % 1
            readonly property real env: Math.sin(p * Math.PI)   // 0 at both ends, 1 mid-travel
            readonly property real baseX: rX * root.width
            readonly property real swayAmp: root.swayMax * (0.4 + 0.6 * rAmp)
            readonly property real swayFreq: 0.6 + rFreq * 1.8
            x: baseX + Math.sin(p * 6.2832 * swayFreq + rPhase * 30) * swayAmp - sz / 2
            // Rise (direction<0) starts at the floor and climbs; fall does the reverse.
            y: root.direction < 0
               ? root.height + sz - p * (root.height + sz * 2)
               : -sz + p * (root.height + sz * 2)
            opacity: root.baseOpacity * env * (root.flicker ? flick : 1)

            property real flick: 1
            SequentialAnimation on flick {
                running: root.running && root.flicker; loops: Animation.Infinite
                NumberAnimation { from: 0.3; to: 1; duration: 380 + Math.round(pt.rFlk * 700); easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.3; duration: 300 + Math.round(pt.rFlk * 600); easing.type: Easing.InOutSine }
            }

            // Soft glow: two stacked translucent discs (no shader) + a bright core.
            Rectangle { anchors.centerIn: parent; width: pt.sz * 3.0; height: width; radius: width / 2; color: root.glow; opacity: 0.16 }
            Rectangle { anchors.centerIn: parent; width: pt.sz * 1.9; height: width; radius: width / 2; color: root.glow; opacity: 0.34 }
            Rectangle { anchors.centerIn: parent; width: pt.sz; height: pt.sz; radius: pt.sz / 2; color: root.core }

            NumberAnimation on prog {
                from: 0; to: 1
                duration: root.durMin + pt.rDur * (root.durMax - root.durMin)
                loops: Animation.Infinite
                running: root.running
            }
        }
    }
}
