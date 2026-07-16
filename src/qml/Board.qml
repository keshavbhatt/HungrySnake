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
    readonly property int  bodySegs: 64   // gradient steps along the body tube (finer = smoother)

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

    // Slice the body into segment `i` of `n` (pixel points). Each slice is widened
    // by a few points of overlap on both ends so every gradient segment is a proper
    // multi-point stroke: its round joins smooth the corner and its round-capped
    // ends are buried well inside its neighbours (instead of showing as flat facets
    // at turns, which is what happened with a bare one-point overlap on a big/short
    // snake). The overlap-drawn colours also blend the gradient rather than banding.
    function segPoints(i, n) {
        var b = game.body;
        var len = b.length;
        if (len < 2)
            return bodyPx();
        var s = Math.floor(i * (len - 1) / n);
        var e = Math.ceil((i + 1) * (len - 1) / n);
        var over = 3;                                  // points of overlap each side
        s = Math.max(0, s - over);
        e = Math.min(len - 1, e + over);
        if (e - s < 4) {                               // keep a minimum stroke length
            e = Math.min(len - 1, s + 4);
            s = Math.max(0, e - 4);
        }
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

            // ── Checkerboard: raised, embossed 3D tiles over the dark seam ──
            Repeater {
                model: game.cols * game.rows
                delegate: Shape {
                    id: tile
                    required property int index
                    readonly property int col: index % game.cols
                    readonly property int rw: Math.floor(index / game.cols)
                    readonly property real g: cell * 0.04    // seam gap on each side
                    readonly property color base: (col + rw) % 2 === 0 ? Theme.tileA : Theme.tileB
                    readonly property real r: cell * 0.22
                    x: col * cell + g
                    y: rw * cell + g
                    width: cell - g * 2
                    height: cell - g * 2
                    antialiasing: true
                    preferredRendererType: Shape.CurveRenderer
                    // Directional top-lit bevel: a bright top edge fades down through
                    // the base to a soft shadow at the bottom (light from above),
                    // matching the reference's raised, top-lit tiles.
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 0
                            x2: 0; y2: tile.height
                            GradientStop { position: 0.0;  color: Qt.lighter(tile.base, 1.18) }
                            GradientStop { position: 0.16; color: Qt.lighter(tile.base, 1.04) }
                            GradientStop { position: 0.6;  color: tile.base }
                            GradientStop { position: 1.0;  color: Qt.darker(tile.base, 1.13) }
                        }
                        startX: tile.r; startY: 0
                        PathLine { x: tile.width - tile.r; y: 0 }
                        PathArc  { x: tile.width; y: tile.r; radiusX: tile.r; radiusY: tile.r }
                        PathLine { x: tile.width; y: tile.height - tile.r }
                        PathArc  { x: tile.width - tile.r; y: tile.height; radiusX: tile.r; radiusY: tile.r }
                        PathLine { x: tile.r; y: tile.height }
                        PathArc  { x: 0; y: tile.height - tile.r; radiusX: tile.r; radiusY: tile.r }
                        PathLine { x: 0; y: tile.r }
                        PathArc  { x: tile.r; y: 0; radiusX: tile.r; radiusY: tile.r }
                    }
                }
            }

            // ── Apple (pixel space) — pops in with a bounce, then wobbles gently ──
            Item {
                id: apple
                readonly property real r: game.appleRadius * cell
                x: game.appleX * cell
                y: game.appleY * cell
                transformOrigin: Item.Center

                property real pop: 1     // 0→1 spawn bounce
                property real idle: 0    // -1..1 continuous wobble
                scale: pop * (1 + 0.05 * idle)
                rotation: 6 * idle

                // Pop-in each time a fresh apple appears.
                Connections { target: game; function onAppleChanged() { popAnim.restart() } }
                NumberAnimation { id: popAnim; target: apple; property: "pop"
                                  from: 0; to: 1; duration: 320; easing.type: Easing.OutBack }
                // Idle: a little breathing wobble while it sits on the board.
                SequentialAnimation on idle {
                    loops: Animation.Infinite; running: true
                    NumberAnimation { from: -1; to: 1; duration: 680; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: -1; duration: 680; easing.type: Easing.InOutSine }
                }

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

            // ── Fruit crush: a juice splat where an apple was just eaten ──
            // ate() fires *before* the new apple spawns, so game.appleX/Y still
            // holds the eaten apple's cell when we capture it here.
            Item {
                id: crush
                property real cx: 0
                property real cy: 0
                property real t: 1               // 1 = done
                x: cx * cell; y: cy * cell
                z: 6                             // splatter over the snake's head, not under it
                visible: t < 1
                Connections {
                    target: game
                    function onAte() {
                        crush.cx = game.appleX;
                        crush.cy = game.appleY;
                        crushAnim.restart();
                    }
                }
                NumberAnimation { id: crushAnim; target: crush; property: "t"
                                  from: 0; to: 1; duration: 360; easing.type: Easing.OutCubic }

                // A small juice puff as the apple is bitten — deliberately gentle so
                // eating reads as a gulp, not a splatter. Asymmetric (index hash).
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        readonly property real r1: Math.abs((Math.sin((index + 3) * 12.9898) * 43758.5453) % 1)
                        readonly property real r2: Math.abs((Math.sin((index + 3) * 78.233)  * 43758.5453) % 1)
                        readonly property real r3: Math.abs((Math.sin((index + 3) * 37.719)  * 43758.5453) % 1)
                        readonly property real ang: r1 * 2 * Math.PI
                        readonly property real reach: cell * (0.3 + r2 * 0.7)
                        readonly property real sz: cell * (0.10 + r3 * 0.12)
                        readonly property real de: Math.pow(crush.t, 0.6 + r1 * 0.5)
                        width: sz; height: sz; radius: sz / 2
                        antialiasing: true
                        color: r3 > 0.7 ? Theme.appleLeaf : Theme.apple
                        x: Math.cos(ang) * reach * de - sz / 2
                        y: Math.sin(ang) * reach * de - sz / 2 + crush.t * crush.t * cell * 0.3
                        opacity: Math.min(1, (1 - crush.t) * 1.6)
                    }
                }
            }

            // ── Swallow: the eaten apple is drawn into the mouth and gulped down,
            // so eating reads as the snake taking the apple in rather than the fruit
            // just vanishing. Captured on ate() (before the new apple spawns).
            Item {
                id: swallow
                property real sx: 0
                property real sy: 0
                property real t: 1                 // 1 = done
                z: 5                               // over the head, so it's seen going in
                visible: t < 1
                Connections {
                    target: game
                    function onAte() {
                        swallow.sx = game.appleX;
                        swallow.sy = game.appleY;
                        swallowAnim.restart();
                    }
                }
                NumberAnimation { id: swallowAnim; target: swallow; property: "t"
                                  from: 0; to: 1; duration: 210; easing.type: Easing.InQuad }

                // The apple sits in the open mouth (front of the head) then travels
                // back to the head centre — down the throat — as it shrinks away, all
                // while tracking the head so it stays with the snake, not left behind.
                readonly property real mx: game.headX + Math.cos(game.heading) * 0.34
                readonly property real my: game.headY + Math.sin(game.heading) * 0.34
                readonly property real px: swallow.mx + (game.headX - swallow.mx) * swallow.t
                readonly property real py: swallow.my + (game.headY - swallow.my) * swallow.t

                Item {
                    x: swallow.px * cell
                    y: swallow.py * cell
                    scale: 1 - swallow.t * 0.82
                    opacity: swallow.t < 0.6 ? 1 : Math.max(0, (1 - swallow.t) / 0.4)
                    Rectangle {   // apple body
                        anchors.centerIn: parent
                        width: game.appleRadius * cell * 2; height: width; radius: width / 2
                        color: Theme.apple
                        Rectangle {   // highlight
                            x: parent.width * 0.22; y: parent.height * 0.18
                            width: parent.width * 0.26; height: width; radius: width / 2
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }
                    }
                    Rectangle {   // leaf
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -game.appleRadius * cell * 1.0
                        width: game.appleRadius * cell * 0.7; height: game.appleRadius * cell * 0.4
                        radius: height / 2; rotation: -28; color: Theme.appleLeaf
                    }
                }
            }

            // ── Snake body: a wedge that fades neck-green → tail-teal ──
            // A run of round-capped Shape strokes (pixel space) stepping one linear
            // head→tail gradient; the width is full at the neck and tapers
            // continuously to a soft point at the tail (per the design spec). Slices
            // overlap (see segPoints) so the corners stay smooth, not faceted.
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
                readonly property real hlen: cell * 1.15    // length along travel (longer snout)
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
                property real tongueOut: 0                    // 0..1, tongue extension after a meal

                // Dizzy eye-roll: while dead the pupils spin in circles, and keep
                // spinning until the run restarts.
                readonly property bool rolling: game.status === SnakeGame.Dead
                property real rollAngle: 0
                NumberAnimation on rollAngle {
                    running: head.rolling
                    from: 0; to: 2 * Math.PI
                    duration: 820; loops: Animation.Infinite
                }

                // The mouth opens as the head nears the apple (within ~1 cell) and
                // closes again once it moves away.
                readonly property bool nearApple: game.status === SnakeGame.Playing
                    && Math.hypot(game.headX - game.appleX, game.headY - game.appleY) < 1.6
                // About to bite itself: a body segment is both close (<~1.2 cells) AND
                // ahead of the head (positive dot with the travel direction). That
                // directional test is what tells a real head-on bite apart from a mere
                // close turn/coil (where the body sweeps past to the SIDE) — so the
                // mouth opens for a self-bite but stays shut through tight turns.
                readonly property bool nearSelf: {
                    if (game.status !== SnakeGame.Playing) return false;
                    var b = game.body, n = b.length;
                    if (n < 12) return false;                 // too short to reach itself
                    var hx = game.headX, hy = game.headY;
                    var fx = Math.cos(game.heading), fy = Math.sin(game.heading);
                    for (var k = 8; k < n; k++) {             // skip ~2 cells of neck
                        var dx = b[k].x - hx, dy = b[k].y - hy;
                        if (dx * dx + dy * dy < 1.2 * 1.2 && (dx * fx + dy * fy) > 0.35)
                            return true;                      // near AND ahead → a bite
                    }
                    return false;
                }
                // Open near an apple or a head-on self-bite; shut otherwise (incl. turns).
                property real mouthOpen: (nearApple || nearSelf) ? 1 : 0
                Behavior on mouthOpen { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                // Blink: eyes squash shut briefly every few seconds.
                SequentialAnimation on blink {
                    loops: Animation.Infinite
                    PauseAnimation { duration: 2600 }
                    NumberAnimation { to: 0.08; duration: 70; easing.type: Easing.InQuad }
                    NumberAnimation { to: 1.0;  duration: 95; easing.type: Easing.OutQuad }
                }

                // Forked pink tongue flick (matches the original): a quick double
                // flick out the snout, after each meal AND on a slow idle timer.
                Connections { target: game; function onAte() { tongueAnim.restart() } }
                Timer {
                    interval: 2600; repeat: true
                    running: game.status === SnakeGame.Playing
                    onTriggered: if (!tongueAnim.running) tongueAnim.restart()
                }
                SequentialAnimation {
                    id: tongueAnim
                    NumberAnimation { target: head; property: "tongueOut"; to: 1.0;  duration: 90; easing.type: Easing.OutQuad }
                    NumberAnimation { target: head; property: "tongueOut"; to: 0.45; duration: 80 }
                    NumberAnimation { target: head; property: "tongueOut"; to: 1.0;  duration: 80 }
                    NumberAnimation { target: head; property: "tongueOut"; to: 0.0;  duration: 120; easing.type: Easing.InQuad }
                }

                // Head capsule (flat head green) + a soft drop shadow on the board.
                Rectangle {
                    anchors.fill: parent
                    radius: head.hr
                    color: Theme.headGreen
                    antialiasing: true
                    layer.enabled: true
                    layer.smooth: true
                    layer.samples: 4
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

                // Eating mouth — an open red maw framed by the snake's own skin (a
                // deep-green lip) with a darkened throat for depth, so it reads as a
                // real opening in the head rather than a flat red patch. Eating only.
                Item {
                    id: mouth
                    visible: head.mouthOpen > 0.02
                    opacity: Math.min(1, head.mouthOpen * 1.8)
                    anchors.fill: parent
                    antialiasing: true

                    readonly property real cx: head.hlen * 0.82
                    readonly property real cy: head.hwid * 0.5
                    readonly property real mw: head.hlen * (0.15 + 0.10 * head.mouthOpen)
                    readonly property real mh: head.hwid * (0.24 + 0.58 * head.mouthOpen)
                    readonly property real lipT: head.hwid * 0.055

                    // Snake-skin lip — a lighter green rim so the opening belongs to the
                    // head without reading as a heavy dark outline.
                    Rectangle {
                        x: mouth.cx - width / 2; y: mouth.cy - height / 2
                        width: mouth.mw + mouth.lipT * 2; height: mouth.mh + mouth.lipT * 2
                        radius: Math.min(width, height) / 2
                        color: Theme.snoutCap
                        antialiasing: true
                    }
                    // Red interior.
                    Rectangle {
                        id: maw
                        x: mouth.cx - width / 2; y: mouth.cy - height / 2
                        width: mouth.mw; height: mouth.mh
                        radius: Math.min(width, height) / 2
                        color: "#e5392b"
                        antialiasing: true
                        // Dark throat — a recessed centre gives the maw real depth.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.64; height: parent.height * 0.68
                            radius: Math.min(width, height) / 2
                            color: "#5f120d"; opacity: 0.9
                            antialiasing: true
                        }
                        // Fangs — a row of white teeth biting inward from the front lip.
                        Repeater {
                            model: [0.27, 0.5, 0.73]
                            delegate: Shape {
                                required property real modelData
                                anchors.fill: parent; antialiasing: true
                                ShapePath {
                                    fillColor: "#fff3e2"; strokeColor: "transparent"
                                    startX: maw.width * 0.86; startY: maw.height * (modelData - 0.085)
                                    PathLine { x: maw.width * 0.44; y: maw.height * modelData }
                                    PathLine { x: maw.width * 0.86; y: maw.height * (modelData + 0.085) }
                                }
                            }
                        }
                        // Glossy sheen catching the light on the front (leading) lip.
                        Rectangle {
                            x: parent.width * 0.82; y: parent.height * 0.22
                            width: parent.width * 0.13; height: parent.height * 0.56
                            radius: width / 2; rotation: 7
                            color: "#ffffff"; opacity: 0.4
                            antialiasing: true
                        }
                    }
                }

                // Two nostrils well forward on the snout, roughly in front of the eyes.
                Repeater {
                    model: [0.28, 0.72]
                    delegate: Rectangle {
                        required property real modelData
                        readonly property real nr: head.hwid * 0.043
                        width: nr * 2; height: nr * 2; radius: nr
                        x: head.hlen * 0.80 - nr
                        y: head.hwid * modelData - nr
                        color: Theme.snakeNose
                        opacity: 1 - head.mouthOpen   // clear the way as the maw opens
                    }
                }

                // Eyes: a touch smaller, soft off-white with a black "ball" pupil
                // (biased toward travel) and a small catchlight. Flat; they blink.
                Repeater {
                    model: [0.14, 0.86]
                    delegate: Item {
                        required property real modelData
                        readonly property real er: head.hwid * 0.20
                        x: head.hlen * 0.44 - er
                        y: head.hwid * modelData - er
                        width: er * 2
                        height: er * 2
                        // Slightly taller than wide → a natural oval, not a pure circle.
                        // (Blink folds into the same vertical scale.)
                        transform: Scale { origin.x: er; origin.y: er; yScale: head.blink * 1.16 }
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "#f3efe3"; antialiasing: true }
                        Rectangle {   // black pupil — biased forward; rolls in circles while dead
                            width: parent.width * 0.54; height: width; radius: width / 2
                            color: "#1e1e1e"
                            antialiasing: true
                            readonly property real orbitR: parent.width * 0.14
                            x: head.rolling ? parent.width * 0.23 + orbitR * Math.cos(head.rollAngle)
                                            : parent.width * 0.38
                            y: head.rolling ? parent.height * 0.23 + orbitR * Math.sin(head.rollAngle)
                                            : parent.height * 0.23
                            Behavior on x { enabled: !head.rolling; NumberAnimation { duration: 200 } }
                            Behavior on y { enabled: !head.rolling; NumberAnimation { duration: 200 } }
                            Rectangle {   // catchlight (glossy ball)
                                width: parent.width * 0.34; height: width; radius: width / 2
                                x: parent.width * 0.14; y: parent.height * 0.12
                                color: "#ffffff"; antialiasing: true
                            }
                        }
                    }
                }

                // Forked bright-pink tongue that flicks out the snout (matches the
                // original game). Extends from the base via tongueOut.
                Item {
                    id: tongue
                    visible: head.tongueOut > 0.02
                    width: head.hwid * 0.72
                    height: head.hwid * 0.46
                    x: head.hlen * 0.90
                    y: head.hwid / 2 - height / 2
                    transform: Scale { origin.x: 0; origin.y: height / 2; xScale: head.tongueOut }
                    readonly property color pink: "#ef2b7d"
                    Rectangle {   // stalk
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.56; height: head.hwid * 0.15; radius: height / 2
                        color: tongue.pink; antialiasing: true
                    }
                    Rectangle {   // upper fork
                        x: parent.width * 0.46; y: parent.height * 0.5 - height
                        width: parent.width * 0.54; height: head.hwid * 0.115; radius: height / 2
                        rotation: -26; transformOrigin: Item.Left; color: tongue.pink; antialiasing: true
                    }
                    Rectangle {   // lower fork
                        x: parent.width * 0.46; y: parent.height * 0.5
                        width: parent.width * 0.54; height: head.hwid * 0.115; radius: height / 2
                        rotation: 26; transformOrigin: Item.Left; color: tongue.pink; antialiasing: true
                    }
                }

                // Eyebrows — since the head looks FORWARD (+x), "above the eyes" is the
                // tail side: one brow just behind each eye, angled to arc over it.
                Repeater {
                    model: [0.14, 0.86]
                    delegate: Rectangle {
                        required property real modelData
                        readonly property real dir: modelData < 0.5 ? -1 : 1   // -1 top, +1 bottom
                        width: head.hwid * 0.19                               // the brow length
                        height: Math.max(3, head.hwid * 0.055)               // thickness
                        radius: height / 2
                        color: Theme.snakeNose
                        antialiasing: true
                        x: head.hlen * 0.22 - width / 2                       // well behind the eye (tail side)
                        y: head.hwid * modelData - dir * head.hwid * 0.03 - height / 2
                        rotation: dir * 74                                    // near-vertical, tilted toward centre
                        transformOrigin: Item.Center
                    }
                }
            }

            // ── Death burst: particles fly out from the head when the run ends ──
            Repeater {
                model: 26
                delegate: Rectangle {
                    required property int index
                    visible: root.burstT < 1
                    readonly property real ang: index / 26 * 2 * Math.PI + (index % 5) * 0.29
                    readonly property real reach: cell * (1.4 + (index % 5) * 0.7)
                    readonly property real sz: cell * (0.22 + (index % 3) * 0.1)
                    readonly property real e: root.burstT       // 0 → 1 over the burst
                    width: sz; height: sz; radius: sz / 2
                    antialiasing: true
                    border.width: Math.max(1, sz * 0.14)
                    border.color: Qt.rgba(1, 1, 1, 0.55)        // bright rim so they pop
                    color: index % 4 === 0 ? Theme.snakeEye
                         : index % 4 === 1 ? Theme.snakeLight
                         : index % 4 === 2 ? Theme.snakeCrest : Theme.headGreen
                    x: game.headX * cell + Math.cos(ang) * reach * e - sz / 2
                    y: game.headY * cell + Math.sin(ang) * reach * e - sz / 2
                    opacity: Math.pow(1 - e, 0.7)               // hold brightness, fade late
                }
            }
            }   // content
        }
    }
}
