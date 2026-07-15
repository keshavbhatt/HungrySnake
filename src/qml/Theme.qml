pragma Singleton
import QtQuick

// App-wide design tokens for Snecko — a warm jungle palette: deep green canvas,
// a tan checkerboard board inside a rounded wooden frame, a green snake, red
// apples and a gold trophy.
QtObject {
    id: theme

    // ── Canvas (the jungle behind the board) — bright green up top, deep teal below ──
    readonly property color bgTop:    "#437350"
    readonly property color bg:       "#284a37"
    readonly property color bgDeep:   "#0d211c"
    // Leaf silhouette tints (lighter for the canopy up top, near-black for the floor).
    readonly property color leafLight: "#2f5b3c"
    readonly property color leafDark:  "#0c1f18"

    // ── Board ──
    readonly property color frame:    "#7a4c26"   // wooden border
    readonly property color frameHi:  "#9a6636"   // frame top bevel
    readonly property color tileA:    "#bc8a5c"   // board tile (light)
    readonly property color tileB:    "#976946"   // board tile (dark)
    readonly property color tileGap:  "#7f5838"   // seam / background between rounded tiles
    readonly property color shadow:   "#000000"   // drop shadows

    // ── HUD cards ──
    readonly property color card:       "#c99c62"
    readonly property color cardBorder: "#8a5c30"
    readonly property color cardInk:    "#fbf1d8"  // cream numerals

    // ── Snake ──
    readonly property color snakeLight: "#2ad374"  // neck green (head end of body gradient)
    readonly property color snakeDark:  "#0e4f58"  // tail teal
    readonly property color headGreen:  "#2fb268"  // head capsule
    readonly property color snoutCap:   "#1f8f56"  // darker snout cap (front third)
    readonly property color snakeEye:   "#ffdf2b"  // eye yellow
    readonly property color snakePupil: "#f2772e"  // pupil orange
    readonly property color snakeNose:  "#14603f"  // nostril
    readonly property color snakeCrest: "#e63a3a"  // tongue / eating-mouth red

    // ── Apple ──
    readonly property color apple:     "#e23b2c"
    readonly property color appleLeaf: "#57b845"
    readonly property color appleStem: "#7a4a25"

    // ── Accents ──
    readonly property color title:   "#7fca61"     // "GAME OVER" green
    readonly property color gold:    "#e6a93a"      // trophy
    readonly property color good:    "#57b98a"

    // ── Text ──
    readonly property color text:    "#f3e7cd"
    readonly property color textDim: "#d8c39c"
    readonly property color ink:     "#5a3d22"

    // ── Metrics ──
    readonly property int rsm: 10
    readonly property int r:   18
    readonly property int rlg: 26

    readonly property string ui: Qt.application.font.family
}
