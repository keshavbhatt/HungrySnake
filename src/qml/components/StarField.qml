import QtQuick

// A twinkling starfield (+ an optional moon) for night scenes. Stars sit at fixed
// hashed positions, clustered toward the top (sky) and thinning downward, each pulsing
// opacity on its own period. Index-hashed, deterministic. Inert; blocks no input.
Item {
    id: root
    property int  count: 90
    property bool running: false
    property bool showMoon: true

    function rnd(i, s) {
        var v = Math.sin((i + 1) * 127.1 + s * 311.7) * 43758.5453;
        return v - Math.floor(v);
    }

    // Moon — top-right, a pale disc behind two faint halos, with a few soft craters.
    Item {
        id: moon
        visible: root.showMoon && root.running
        readonly property real d: Math.min(root.width, root.height) * 0.13
        width: d; height: d
        x: root.width * 0.79; y: root.height * 0.13
        Rectangle { anchors.centerIn: parent; width: moon.d * 2.0; height: width; radius: width / 2; color: "#e8f0ff"; opacity: 0.08 }
        Rectangle { anchors.centerIn: parent; width: moon.d * 1.45; height: width; radius: width / 2; color: "#e8f0ff"; opacity: 0.12 }
        Rectangle {
            anchors.fill: parent; radius: width / 2; color: "#eef2ff"
            Rectangle { x: parent.width * 0.26; y: parent.height * 0.28; width: parent.width * 0.17; height: width; radius: width / 2; color: "#d3d9ee" }
            Rectangle { x: parent.width * 0.56; y: parent.height * 0.54; width: parent.width * 0.12; height: width; radius: width / 2; color: "#d3d9ee" }
            Rectangle { x: parent.width * 0.40; y: parent.height * 0.70; width: parent.width * 0.09; height: width; radius: width / 2; color: "#d3d9ee" }
        }
    }

    Repeater {
        model: root.running ? root.count : 0
        delegate: Item {
            id: star
            required property int index
            readonly property real rX: root.rnd(index, 1.9)
            readonly property real rY: root.rnd(index, 6.3)
            readonly property real rS: root.rnd(index, 3.7)
            readonly property real rT: root.rnd(index, 8.1)
            readonly property real sz: 1.5 + rS * rS * 3.5     // mostly tiny, a few larger
            x: rX * root.width
            y: (rY * rY) * root.height * 0.85                  // dense up top, sparse below
            width: sz; height: sz

            property real tw: 1
            opacity: tw
            SequentialAnimation on tw {
                running: root.running; loops: Animation.Infinite
                NumberAnimation { from: 0.25; to: 1; duration: 900 + Math.round(star.rT * 2200); easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.25; duration: 900 + Math.round(star.rT * 2200); easing.type: Easing.InOutSine }
                PauseAnimation { duration: Math.round(star.rT * 1600) }
            }
            Rectangle { visible: star.sz > 3; anchors.centerIn: parent; width: star.sz * 2.6; height: width; radius: width / 2; color: "#cfe0ff"; opacity: 0.3 }
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#ffffff" }
        }
    }
}
