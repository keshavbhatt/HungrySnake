import QtQuick

// A drifting snowfall for the "Snowfall" background scene. A field of little white
// crystals, each with its own size, fall speed, sway and spin so no two move alike.
// The per-flake values come from a hash of the flake index (a deterministic
// stand-in for Math.random) so the field looks random but renders identically
// every run. Inert — draws no input, blocks nothing.
Item {
    id: root
    property int  count: 64
    property bool running: false

    // Size + timing ranges every flake is spread across (min..max).
    property real minSize: 4
    property real maxSize: 15
    property int  fallMin: 6000
    property int  fallMax: 16000
    property int  spinMin: 4000
    property int  spinMax: 15000

    // Hash → a well-spread pseudo-random real in [0,1) from (index, salt). The
    // classic sin-scatter trick: deterministic, but uncorrelated across salts.
    function rnd(i, salt) {
        var v = Math.sin((i + 1) * 127.1 + salt * 311.7) * 43758.5453;
        return v - Math.floor(v);
    }

    // Only build the flakes when it's actually snowing (0 flakes ⇒ no cost otherwise).
    Repeater {
        model: root.running ? root.count : 0
        delegate: Item {
            id: flake
            required property int index

            // Seven independent draws — one per varied trait.
            readonly property real rSize:  root.rnd(index, 1.7)
            readonly property real rOpac:  root.rnd(index, 9.3)
            readonly property real rPhase: root.rnd(index, 4.1)
            readonly property real rX:     root.rnd(index, 6.7)
            readonly property real rAmp:   root.rnd(index, 2.9)
            readonly property real rFreq:  root.rnd(index, 8.5)
            readonly property real rFall:  root.rnd(index, 5.2)
            readonly property real rSpin:  root.rnd(index, 3.3)
            readonly property real rDir:   root.rnd(index, 7.9)

            readonly property real sz: root.minSize + rSize * (root.maxSize - root.minSize)
            width: sz; height: sz
            transformOrigin: Item.Center
            // Bigger flakes read as "closer", so let them sit a touch more opaque.
            opacity: (0.4 + rOpac * 0.5) * (0.7 + 0.3 * rSize)
            rotation: spin

            property real fall: 0
            property real spin: 0

            // fall 0→1 loops seamlessly; the per-flake phase offsets it so they
            // don't fall as a synchronized sheet, and (fall+phase)%1 wraps cleanly.
            readonly property real p: (fall + rPhase) % 1
            readonly property real baseX: rX * root.width
            readonly property real swayAmp: 12 + rAmp * 46
            readonly property real swayFreq: 0.7 + rFreq * 1.8
            x: baseX + Math.sin(p * 6.2832 * swayFreq + rPhase * 30) * swayAmp - sz / 2
            y: -root.maxSize + p * (root.height + root.maxSize * 2)

            // A 6-arm crystal: three thin rounded bars crossed at 0/60/120°. Spins
            // as a whole, so the rotation actually reads (a circle's wouldn't).
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: flake.sz
                    height: Math.max(1, flake.sz * 0.16)
                    radius: height / 2
                    color: "#ffffff"
                    rotation: index * 60
                    antialiasing: true
                }
            }

            NumberAnimation on fall {
                from: 0; to: 1
                duration: root.fallMin + flake.rFall * (root.fallMax - root.fallMin)
                loops: Animation.Infinite
                running: root.running
            }
            // Each flake tumbles at its own rate, half of them the other way.
            NumberAnimation on spin {
                from: 0; to: flake.rDir < 0.5 ? 360 : -360
                duration: root.spinMin + flake.rSpin * (root.spinMax - root.spinMin)
                loops: Animation.Infinite
                running: root.running
            }
        }
    }
}
