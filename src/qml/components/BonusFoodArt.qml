import QtQuick
import QtQuick.Shapes
import HungrySnake

// Timed bonus food. Deliberately drawn as distinct SHAPES (a star / a leaf) rather
// than recoloured spheres: the staple apple is skinnable — a player can equip a
// *golden* apple skin — so colour alone could never tell these apart.
//
// Like AppleArt, this Item's (0,0) is the food's CENTRE. `life` (1 → 0) drives the
// ring that drains as it expires, and the pulse quickens as time runs out.
Item {
    id: root
    property int  kind: 0            // SnakeGame.Golden = 0, SnakeGame.Mint = 1
    property real life: 1            // remaining fraction
    property real d: 30              // nominal diameter
    property bool showRing: true     // the expiry ring is gameplay — off for Store previews

    // Skinnable tints (see Cosmetics.bonusSkins). Only the COLOURS are skinnable —
    // the star/leaf shapes are fixed so a skin can never disguise which food is which.
    property color goldTint: "#f0c23a"
    property color goldDeep: "#a9781a"
    property color mintTint: "#5fe0a8"
    property color mintDeep: "#1f8f66"

    readonly property bool golden: kind === 0
    readonly property color tint:     golden ? goldTint : mintTint
    readonly property color tintDeep: golden ? goldDeep : mintDeep
    readonly property real  r: d / 2

    // 5-point star (golden) — computed so we can use a single polyline.
    function starPoints() {
        var pts = [], n = 5;
        for (var i = 0; i < n * 2; i++) {
            var rad = (i % 2 === 0) ? root.r : root.r * 0.46;
            var a = -Math.PI / 2 + i * Math.PI / n;
            pts.push(Qt.point(Math.cos(a) * rad, Math.sin(a) * rad));
        }
        pts.push(pts[0]);
        return pts;
    }

    // Urgency pulse — speeds up as the food is about to vanish.
    property real pulse: 1
    SequentialAnimation on pulse {
        running: root.showRing; loops: Animation.Infinite
        NumberAnimation { to: 1.12; duration: 420; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 420; easing.type: Easing.InOutSine }
    }
    scale: pulse * (root.life < 0.3 ? 0.92 : 1.0)   // shrink a touch when nearly gone
    opacity: root.life < 0.18 ? 0.55 + 0.45 * Math.abs(Math.sin(root.life * 60)) : 1

    // ── Expiry ring ──
    Shape {
        visible: root.showRing
        anchors.centerIn: parent
        width: root.d * 1.7; height: root.d * 1.7
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.tint
            strokeWidth: Math.max(2, root.d * 0.09)
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.d * 0.85; centerY: root.d * 0.85
                radiusX: root.d * 0.72; radiusY: root.d * 0.72
                startAngle: -90
                sweepAngle: -360 * root.life
            }
        }
    }

    // ── Golden star ──
    Shape {
        anchors.centerIn: parent
        width: root.d; height: root.d
        visible: root.golden
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.tint
            strokeColor: root.tintDeep
            strokeWidth: Math.max(1.5, root.d * 0.06)
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.starPoints() }
        }
    }
    Rectangle {                       // star shine
        visible: root.golden
        x: -root.r * 0.34; y: -root.r * 0.52
        width: root.r * 0.3; height: root.r * 0.42
        radius: width / 2; rotation: -20
        color: Qt.rgba(1, 1, 1, 0.75)
        antialiasing: true
    }

    // ── Mint leaf (pointed both ends, with a midrib) ──
    Shape {
        anchors.centerIn: parent
        width: root.d; height: root.d
        visible: !root.golden
        rotation: -30
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.tint
            strokeColor: root.tintDeep
            strokeWidth: Math.max(1.5, root.d * 0.06)
            startX: 0; startY: -root.r
            PathQuad { controlX: root.r * 0.95; controlY: 0; x: 0; y: root.r }
            PathQuad { controlX: -root.r * 0.95; controlY: 0; x: 0; y: -root.r }
        }
        ShapePath {                   // midrib
            fillColor: "transparent"
            strokeColor: root.tintDeep
            strokeWidth: Math.max(1, root.d * 0.045)
            startX: 0; startY: -root.r * 0.75
            PathLine { x: 0; y: root.r * 0.75 }
        }
    }
}
