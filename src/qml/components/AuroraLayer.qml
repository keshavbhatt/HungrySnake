import QtQuick

// Aurora borealis for the exclusive Aurora scene — soft luminous ribbons that drift
// and breathe across the upper sky over a faint starfield. No shaders: each ribbon is
// a wide, vertically-faded gradient band, slightly tilted, animated on its own slow
// horizontal drift + opacity pulse. Index-hashed. Inert; blocks no input.
Item {
    id: root
    property bool running: false
    property real density: 1.0      // scales the background star count (previews thin it)
    // The ribbons below are permanent children (only their animations key off
    // `running`), so without this they'd render at their static opacity over EVERY
    // scene. Gate the whole layer's rendering on the Aurora scene being equipped.
    visible: running

    function rnd(i, s) {
        var v = Math.sin((i + 1) * 127.1 + s * 311.7) * 43758.5453;
        return v - Math.floor(v);
    }

    // Faint stars behind the ribbons.
    Repeater {
        model: root.running ? Math.max(10, Math.round(60 * root.density)) : 0
        delegate: Rectangle {
            required property int index
            readonly property real rS: root.rnd(index, 3.7)
            width: 1.2 + rS * 2.2; height: width; radius: width / 2; color: "#dfe8ff"
            x: root.rnd(index, 1.9) * root.width
            y: root.rnd(index, 6.3) * root.rnd(index, 6.3) * root.height * 0.7
            property real tw: 0.4
            opacity: tw
            SequentialAnimation on tw {
                running: root.running; loops: Animation.Infinite
                NumberAnimation { from: 0.2; to: 0.9; duration: 1400 + Math.round(rS * 2200); easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.9; to: 0.2; duration: 1400 + Math.round(rS * 2200); easing.type: Easing.InOutSine }
            }
        }
    }

    component Ribbon: Rectangle {
        id: rr
        property color hue: "#3fe0a0"
        property real  yFrac: 0.15
        property real  tilt: -8
        property int   driftMs: 14000
        property real  drift: 0
        width: root.width * 1.7
        height: root.height * 0.42
        x: root.width * 0.5 - width / 2 + drift
        y: root.height * yFrac
        rotation: tilt
        transformOrigin: Item.Center
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0;  color: "transparent" }
            GradientStop { position: 0.42; color: rr.hue }
            GradientStop { position: 0.58; color: rr.hue }
            GradientStop { position: 1.0;  color: "transparent" }
        }
        opacity: 0.2
        NumberAnimation on drift {
            from: -root.width * 0.12; to: root.width * 0.12
            duration: driftMs; loops: Animation.Infinite; easing.type: Easing.InOutSine; running: root.running
        }
        SequentialAnimation on opacity {
            running: root.running; loops: Animation.Infinite
            NumberAnimation { from: 0.1; to: 0.32; duration: 3800; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.32; to: 0.1; duration: 4600; easing.type: Easing.InOutSine }
        }
    }

    Ribbon { hue: "#46e0a0"; yFrac: 0.02; tilt: -9; driftMs: 15000 }
    Ribbon { hue: "#3fb6e0"; yFrac: 0.14; tilt: 6;  driftMs: 19000 }
    Ribbon { hue: "#9a6ae0"; yFrac: 0.26; tilt: -4; driftMs: 12000 }
}
