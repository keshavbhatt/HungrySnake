import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Snecko

// The play-field: a rounded wooden frame (with a soft drop shadow and a top
// bevel) around a tan checkerboard. The snake body is a smooth rounded tube —
// a run of round-capped Shape strokes stepping a green→teal gradient along the
// head→tail polyline — and an elongated dual-tone snout head: blinking eyes near
// the rear, nostrils + a flicking tongue at the front, and a red mouth that
// opens only while eating.
Item {
    id: root
    property SnakeGame game

    // Size the cell so the whole *frame* (board + padding) fits — otherwise the
    // padded frame overflows its bounds and can slide up under the HUD buttons.
    readonly property real padFrac: 0.44   // wooden frame thickness
    readonly property real gutFrac: 0.20   // inner margin so edge-cell heads fully fit
    readonly property real cell: Math.min(width  / (game.cols + 2 * (padFrac + gutFrac)),
                                          height / (game.rows + 2 * (padFrac + gutFrac)))
    readonly property real boardW: cell * game.cols
    readonly property real boardH: cell * game.rows
    readonly property real gutter: cell * gutFrac
    readonly property real pad: cell * padFrac
    readonly property real frameW: boardW + (pad + gutter) * 2
    readonly property real frameH: boardH + (pad + gutter) * 2
    readonly property int  bodySegs: 48   // gradient steps along the body tube

    // ── Death effects: a decaying board shake + a particle burst at the head ──
    property real shakeT: 1   // 1 = at rest; animates 0→1 (decays)
    property real burstT: 1   // 1 = done;   animates 0→1 (particles fly out + fade)
    Connections {
        target: game
        function onDied() { shakeAnim.restart(); burstAnim.restart(); }
    }
    NumberAnimation { id: shakeAnim; target: root; property: "shakeT"
                      from: 0; to: 1; duration: 480; easing.type: Easing.OutQuad }
    NumberAnimation { id: burstAnim; target: root; property: "burstT"
                      from: 0; to: 1; duration: 560; easing.type: Easing.OutCubic }

    function mix(a, b, f) {
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1);
    }

    // The body polyline in pixel space (world points × cell).
    function bodyPx() {
        var b = game.body, out = [];
        for (var k = 0; k < b.length; k++)
            out.push(Qt.point(b[k].x * cell, b[k].y * cell));
        return out;
    }

    // Slice the body into segment `i` of `n` (pixel points), with a one-point
    // overlap so the round-capped strokes join seamlessly, and never fewer than
    // two points so every segment renders even on a tiny snake.
    function segPoints(i, n) {
        var b = game.body;
        var len = b.length;
        if (len < 2)
            return bodyPx();
        var s = Math.round(i * (len - 1) / n);
        var e = Math.round((i + 1) * (len - 1) / n);
        if (e <= s) e = Math.min(s + 1, len - 1);
        if (s >= len - 1) s = len - 2;
        var out = [];
        for (var k = s; k <= e; k++)
            out.push(Qt.point(b[k].x * cell, b[k].y * cell));
        return out;
    }

    // The right (shadow) half of the body as one closed polygon: the centreline
    // forward, then the right edge back — filled to paint the lengthwise seam shade
    // in a single pass (a per-segment stroke degenerates into dots on the thin tail).
    function bodyShadowPoly() {
        var b = game.body, len = b.length;
        if (len < 2) return [];
        var center = [], edge = [];
        for (var k = 0; k < len; k++) {
            var p = b[k];
            var a = b[Math.max(0, k - 1)], c = b[Math.min(len - 1, k + 1)];
            var dx = c.x - a.x, dy = c.y - a.y, L = Math.hypot(dx, dy) || 1;
            dx /= L; dy /= L;
            var t = k / (len - 1);
            var w = game.bodyWidth * Math.max(0.2, 1.0 - 0.75 * t) * 0.5;   // half width
            center.push(Qt.point(p.x * cell, p.y * cell));
            edge.push(Qt.point((p.x - dy * w) * cell, (p.y + dx * w) * cell)); // right edge
        }
        return center.concat(edge.reverse());
    }

    // Soft drop shadow cast by the board (static caster, blurred once).
    Rectangle {
        anchors.centerIn: parent
        width: frameW; height: frameH
        radius: Theme.rlg
        color: Theme.frame
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: 1.0
            blurMax: 48
            shadowOpacity: 0.42
            shadowVerticalOffset: 12
            autoPaddingEnabled: true
        }
    }

    // Wooden frame — lit from above: bright top fading to a dark bottom edge.
    Rectangle {
        id: frame
        anchors.centerIn: parent
        width: frameW; height: frameH
        radius: Theme.rlg
        // Death shake: a decaying jitter driven by shakeT (0→1); at rest (1) → still.
        transform: Translate {
            x: (1 - root.shakeT) * 13 * Math.sin(root.shakeT * 52)
            y: (1 - root.shakeT) * 10 * Math.sin(root.shakeT * 45 + 1.3)
        }
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.lighter(Theme.frameHi, 1.12) }
            GradientStop { position: 0.30; color: Theme.frame }
            GradientStop { position: 1.0;  color: Qt.darker(Theme.frame, 1.42) }
        }

        // Wood grain — wavy streaks + a few knots, clipped to the frame; the field
        // covers the centre so grain only reads on the wooden border.
        Canvas {
            id: woodGrain
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width, h = height, rad = frame.radius;
                // clip to the rounded frame so grain never spills past the corners
                ctx.beginPath();
                ctx.moveTo(rad, 0);
                ctx.arcTo(w, 0, w, h, rad);
                ctx.arcTo(w, h, 0, h, rad);
                ctx.arcTo(0, h, 0, 0, rad);
                ctx.arcTo(0, 0, w, 0, rad);
                ctx.closePath();
                ctx.clip();
                // horizontal wavy grain lines (alternating dark streaks + faint highlights)
                var n = 26;
                for (var i = 0; i < n; i++) {
                    var y = (i + 0.5) / n * h;
                    var dark = (i % 3 !== 1);
                    ctx.strokeStyle = dark ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.06);
                    ctx.lineWidth = dark ? 2.0 : 1.0;
                    ctx.beginPath();
                    ctx.moveTo(-6, y);
                    var amp = 3 + (i % 4) * 2.5;
                    for (var x = 0; x <= w + 6; x += 14)
                        ctx.lineTo(x, y + Math.sin(x * 0.018 + i * 1.7) * amp);
                    ctx.stroke();
                }
                // a few knots on the border
                var knots = [[w * 0.09, h * 0.62], [w * 0.93, h * 0.30], [w * 0.62, h * 0.95], [w * 0.40, h * 0.05]];
                for (var k = 0; k < knots.length; k++) {
                    ctx.lineWidth = 1.4;
                    for (var r = 3; r <= 13; r += 3.4) {
                        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.11 * (1 - r / 18));
                        ctx.beginPath();
                        ctx.arc(knots[k][0], knots[k][1], r, 0, 2 * Math.PI);
                        ctx.stroke();
                    }
                }
            }
        }

        Rectangle {
            id: field
            anchors.centerIn: parent
            width: boardW + gutter * 2
            height: boardH + gutter * 2
            radius: Theme.rsm + 2
            clip: true
            color: Theme.tileGap        // dark seam colour shows between the tiles

            // Inset content layer: leaves a small margin so the snake head fits
            // fully at the edge cells instead of being clipped by the board edge.
            Item {
                id: content
                anchors.centerIn: parent
                width: boardW
                height: boardH

            // ── Checkerboard: rounded tiles inset over the dark seam background ──
            Repeater {
                model: game.cols * game.rows
                delegate: Rectangle {
                    required property int index
                    readonly property int col: index % game.cols
                    readonly property int rw: Math.floor(index / game.cols)
                    readonly property real g: cell * 0.03    // thin seam gap on each side
                    x: col * cell + g
                    y: rw * cell + g
                    width: cell - g * 2
                    height: cell - g * 2
                    radius: cell * 0.2
                    color: (col + rw) % 2 === 0 ? Theme.tileA : Theme.tileB
                }
            }

            // ── Apple (pixel space) ──
            Item {
                readonly property real r: game.appleRadius * cell
                x: game.appleX * cell
                y: game.appleY * cell
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.r * 2
                    height: parent.r * 2
                    radius: width / 2
                    color: Theme.apple
                    Rectangle {   // highlight
                        x: parent.width * 0.22; y: parent.height * 0.18
                        width: parent.width * 0.26; height: width; radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.5)
                    }
                }
                Rectangle {   // stem
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -parent.r * 1.2
                    width: Math.max(2, parent.r * 0.16)
                    height: parent.r * 0.55
                    radius: width / 2
                    rotation: 10
                    color: Theme.appleStem
                }
                Rectangle {   // leaf
                    x: parent.r * 0.1
                    y: -parent.r * 1.1
                    width: parent.r * 0.6
                    height: parent.r * 0.34
                    radius: height / 2
                    rotation: -28
                    color: Theme.appleLeaf
                }
            }

            // ── Snake body: a wedge that fades neck-green → tail-teal ──
            // A run of round-capped Shape strokes (pixel space) stepping one linear
            // head→tail gradient; the width is full at the neck and tapers
            // continuously to a soft point at the tail (per the design spec).
            Repeater {
                model: root.bodySegs
                delegate: Shape {
                    required property int index
                    anchors.fill: parent
                    antialiasing: true
                    readonly property real t: (index + 0.5) / root.bodySegs
                    ShapePath {
                        strokeColor: root.mix(Theme.snakeLight, Theme.snakeDark, Math.pow(t, 0.85))
                        strokeWidth: game.bodyWidth * cell * Math.max(0.2, 1.0 - 0.75 * t)
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathPolyline { path: root.segPoints(index, root.bodySegs) }
                    }
                }
            }

            // Lengthwise seam: a ~13% dark fill over the right (shadow) half.
            Shape {
                anchors.fill: parent
                antialiasing: true
                ShapePath {
                    fillColor: Qt.rgba(0, 0, 0, 0.13)
                    strokeColor: "transparent"
                    PathPolyline { path: root.bodyShadowPoly() }
                }
            }

            // ── Head: two-tone capsule (per the design spec) ──
            // Flat, no outlines. A head-green capsule, one grid-cell wide and
            // slightly proud of the body, with a darker snout cap over the front
            // third; a lengthwise seam darkens the shadow (right) flank ~13%;
            // oversized yellow eyes sit proud of the silhouette with orange pupils
            // biased toward travel; tiny nostrils at the leading edge; the mouth is
            // invisible at rest and flashes a red band + white fangs while eating.
            // Local coords: x 0..hlen rear→front, y 0..hwid across.
            Item {
                id: head
                readonly property real hlen: cell * 0.98    // length along travel
                readonly property real hwid: cell * 1.0     // one grid-cell wide
                readonly property real hr:   Math.min(hlen, hwid) * 0.30   // rounded-rect, not a capsule
                width: hlen
                height: hwid
                // Centre the head on the body tip so it covers the tube's leading
                // round cap (otherwise the bright cap pokes out past the snout).
                x: game.headX * cell - hlen / 2
                y: game.headY * cell - hwid / 2
                rotation: game.heading * 180 / Math.PI
                Behavior on rotation {
                    RotationAnimation { duration: 80; direction: RotationAnimation.Shortest
                                        easing.type: Easing.OutQuad }
                }
                transformOrigin: Item.Center

                property real blink: 1                        // 1 open, ~0 shut
                property real tongueOut: 0                    // 0..1, flick after a meal

                // The mouth opens as the head nears the apple (within ~1 cell) and
                // closes again once it moves away.
                readonly property bool nearApple: game.status === SnakeGame.Playing
                    && Math.hypot(game.headX - game.appleX, game.headY - game.appleY) < 1.6
                property real mouthOpen: nearApple ? 1 : 0
                Behavior on mouthOpen { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                // Blink: eyes squash shut briefly every few seconds.
                SequentialAnimation on blink {
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2600 }
                    NumberAnimation { to: 0.08; duration: 70; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1.0;  duration: 95; easing.type: Easing.OutQuad }
                }

                // Flick the tongue a couple of times just after each meal.
                Connections { target: game; function onAte() { tongueAnim.restart() } }
                SequentialAnimation {
                    id: tongueAnim
                    PauseAnimation  { duration: 300 }   // let the mouth flash finish first
                    NumberAnimation { target: head; property: "tongueOut"; to: 1.0; duration: 85;  easing.type: Easing.OutQuad }
                    NumberAnimation { target: head; property: "tongueOut"; to: 0.35; duration: 85 }
                    NumberAnimation { target: head; property: "tongueOut"; to: 1.0; duration: 85 }
                    NumberAnimation { target: head; property: "tongueOut"; to: 0.0; duration: 110; easing.type: Easing.InQuad }
                }

                // Head capsule (flat head green) + a soft drop shadow on the board.
                Rectangle {
                    anchors.fill: parent
                    radius: head.hr
                    color: Theme.headGreen
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: Theme.shadow
                        shadowBlur: 0.6; shadowOpacity: 0.28; shadowVerticalOffset: 3
                        autoPaddingEnabled: true
                    }
                }

                // Snout cap — a darker copy of the head clipped to the front third
                // (a clean vertical value break, the only one on the character).
                Item {
                    x: head.hlen * 0.6; width: head.hlen * 0.4; height: head.hwid; clip: true
                    Rectangle {
                        x: -head.hlen * 0.6; width: head.hlen; height: head.hwid
                        radius: head.hr; color: Theme.snoutCap
                    }
                }

                // Lengthwise seam: darken the bottom (shadow) flank ~13%.
                Item {
                    y: head.hwid * 0.5; width: head.hlen; height: head.hwid * 0.5; clip: true
                    Rectangle {
                        y: -head.hwid * 0.5; width: head.hlen; height: head.hwid
                        radius: head.hr; color: Qt.rgba(0, 0, 0, 0.13)
                    }
                }

                // Eating mouth — a red band wrapping the leading edge with two white
                // fang points on its inner edge; only visible while eating.
                Item {
                    id: mouth
                    visible: head.mouthOpen > 0.02
                    opacity: Math.min(1, head.mouthOpen * 1.8)
                    x: head.hlen * 0.82; width: head.hlen * 0.20; height: head.hwid; clip: true
                    Rectangle {
                        x: -head.hlen * 0.82; width: head.hlen; height: head.hwid
                        radius: head.hr; color: Theme.snakeCrest
                    }
                    Repeater {   // two white fang points on the inner edge
                        model: [0.30, 0.70]
                        delegate: Shape {
                            required property real modelData
                            anchors.fill: parent; antialiasing: true
                            ShapePath {
                                fillColor: "#ffffff"; strokeColor: "transparent"
                                startX: mouth.width; startY: mouth.height * (modelData - 0.13)
                                PathLine { x: 0; y: mouth.height * modelData }
                                PathLine { x: mouth.width; y: mouth.height * (modelData + 0.13) }
                            }
                        }
                    }
                }

                // Two tiny nostrils near the leading edge, spread across the snout.
                Repeater {
                    model: [0.30, 0.70]
                    delegate: Rectangle {
                        required property real modelData
                        readonly property real nr: head.hwid * 0.04
                        width: nr * 2; height: nr * 2; radius: nr
                        x: head.hlen * 0.72 - nr
                        y: head.hwid * modelData - nr
                        color: Theme.snakeNose
                    }
                }

                // Oversized yellow eyes (~45% head width) proud of the silhouette;
                // orange pupils biased toward travel. Flat (no outline); they blink.
                Repeater {
                    model: [0.14, 0.86]
                    delegate: Item {
                        required property real modelData
                        readonly property real er: head.hwid * 0.235
                        x: head.hlen * 0.44 - er
                        y: head.hwid * modelData - er
                        width: er * 2
                        height: er * 2
                        transform: Scale { origin.x: er; origin.y: er; yScale: head.blink }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.snakeEye }
                        Rectangle {   // orange pupil biased toward travel (+x)
                            width: parent.width * 0.5; height: width; radius: width / 2
                            color: Theme.snakePupil
                            x: parent.width * 0.42; y: parent.height * 0.25
                        }
                    }
                }

                // Forked red tongue — hidden at rest; flicks out the snout just
                // after a meal (driven by head.tongueOut). Extends from the base.
                Item {
                    id: tongue
                    visible: head.tongueOut > 0.02
                    width: head.hwid * 0.72
                    height: head.hwid * 0.32
                    x: head.hlen * 0.9
                    y: head.hwid / 2 - height / 2
                    transform: Scale { origin.x: 0; origin.y: tongue.height / 2; xScale: head.tongueOut }
                    Rectangle {   // stalk
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.6; height: head.hwid * 0.1; radius: height / 2
                        color: Theme.snakeCrest
                    }
                    Rectangle {   // upper fork
                        x: parent.width * 0.5; y: parent.height * 0.5 - height
                        width: parent.width * 0.5; height: head.hwid * 0.08; radius: height / 2
                        rotation: -24; transformOrigin: Item.Left; color: Theme.snakeCrest
                    }
                    Rectangle {   // lower fork
                        x: parent.width * 0.5; y: parent.height * 0.5
                        width: parent.width * 0.5; height: head.hwid * 0.08; radius: height / 2
                        rotation: 24; transformOrigin: Item.Left; color: Theme.snakeCrest
                    }
                }
            }

            // ── Death burst: particles fly out from the head when the run ends ──
            Repeater {
                model: 22
                delegate: Rectangle {
                    required property int index
                    visible: root.burstT < 1
                    readonly property real ang: index / 22 * 2 * Math.PI + (index % 5) * 0.29
                    readonly property real reach: cell * (1.5 + (index % 5) * 0.6)
                    readonly property real sz: cell * (0.14 + (index % 3) * 0.06)
                    readonly property real e: root.burstT       // 0 → 1 over the burst
                    width: sz; height: sz; radius: sz / 2
                    antialiasing: true
                    color: index % 4 === 0 ? Theme.snakeEye
                         : index % 4 === 1 ? Theme.snakeLight
                         : index % 4 === 2 ? Theme.snakeDark : Theme.headGreen
                    x: game.headX * cell + Math.cos(ang) * reach * e - sz / 2
                    y: game.headY * cell + Math.sin(ang) * reach * e - sz / 2
                    opacity: (1 - e) * (1 - e)                  // fade out, easing
                }
            }
            }   // content
        }
    }
}
