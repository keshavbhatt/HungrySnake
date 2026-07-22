import QtQuick

// Picks the atmospheric layer for the equipped background scene. Two instances are
// placed in Main: plane "back" (sky: stars, aurora) sits behind the board; plane
// "front" (air: snow, embers, motes, fireflies) drifts over everything. Each effect
// is gated on both its `fx` name and its plane, and builds zero nodes when inactive,
// so only the equipped scene's layer costs anything.
Item {
    id: root
    property string fx: "none"      // cosmetics.sceneFx
    property string plane: "front"  // "back" | "front"
    property bool   active: true
    // Scales every effect's particle/star count. 1.0 = the full in-game field; the
    // Store previews render it smaller (e.g. ~0.3) so a thumbnail isn't a blizzard.
    property real   density: 1.0

    // ── Sky (back plane) ──────────────────────────────────────────────────────
    StarField {
        anchors.fill: parent
        running: root.active && root.plane === "back" && root.fx === "stars"
        showMoon: true
        count: Math.max(10, Math.round(60 * root.density))
    }
    AuroraLayer {
        anchors.fill: parent
        running: root.active && root.plane === "back" && root.fx === "aurora"
        density: root.density
    }

    // ── Air (front plane) ─────────────────────────────────────────────────────
    FireflyField {
        anchors.fill: parent
        running: root.active && root.plane === "front" && root.fx === "fireflies"
        count: Math.max(4, Math.round(16 * root.density))
    }
    // Warm dust motes rising in the sunset light — slow, soft, no flicker.
    ParticleField {
        anchors.fill: parent
        running: root.active && root.plane === "front" && root.fx === "motes"
        count: Math.max(6, Math.round(34 * root.density)); minSize: 3; maxSize: 9
        core: "#ffe9cf"; glow: "#ffbe86"
        direction: -1; durMin: 11000; durMax: 20000; swayMax: 34
        flicker: false; baseOpacity: 0.5
    }
    // Rising embers — hot, flickering. Fewer and slower than before (they were too
    // fast/busy, and cheaper to render behind the board).
    ParticleField {
        anchors.fill: parent
        running: root.active && root.plane === "front" && root.fx === "embers"
        count: Math.max(6, Math.round(28 * root.density)); minSize: 2.5; maxSize: 7
        core: "#ffd98a"; glow: "#ff5a1e"
        direction: -1; durMin: 8500; durMax: 16000; swayMax: 32
        flicker: true; baseOpacity: 0.92
    }
    SnowLayer {
        anchors.fill: parent
        running: root.active && root.plane === "front" && root.fx === "snow"
        count: Math.max(8, Math.round(44 * root.density))
        fallMin: 8000; fallMax: 18000                     // drift a bit more gently
    }
}
