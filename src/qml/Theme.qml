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
    readonly property color tileA:    "#c68d56"   // board tile (light)
    readonly property color tileB:    "#a06b3b"   // board tile (dark) — clear checkerboard
    readonly property color tileGap:  "#583720"   // dark recessed grout between tiles
    readonly property color shadow:   "#000000"   // drop shadows

    // ── UI kit (from the design-system "UI Kit" doc) ──
    // Surfaces & controls chrome — distinct from the gameplay art above.
    readonly property color primary:     "#46c08a"  // primary button face
    readonly property color primaryDeep: "#33996c"  // its raised lip / pressed tone
    readonly property color cardTan:     "#e9be80"  // dialog card
    readonly property color cardEdge:    "#caa066"  // dialog card border
    readonly property color insetTan:    "#c99a5f"  // inset panel / secondary button
    readonly property color insetEdge:   "#b08a55"  // inset / chip border
    readonly property color insetDeep:   "#b48347"  // secondary button pressed
    readonly property color hudWood:     "#8a6238"  // HUD chip (floats over gameplay)
    readonly property color hudEdge:     "#6f4d2a"  // HUD chip border
    readonly property color danger:      "#d9534a"
    readonly property color dangerDeep:  "#b03d36"
    readonly property color warning:     "#f2a53a"
    readonly property color disabled:    "#d9bd94"
    readonly property color disabledInk: "#b09a77"

    // Ink (dark on tan) & cream (light on wood/dark).
    readonly property color inkStrong: "#4a2f14"
    readonly property color inkSoft:   "#7a5530"
    readonly property color cream:     "#f3dcb2"

    // Legacy aliases kept so existing call sites resolve to the kit tokens.
    readonly property color card:       cardTan
    readonly property color cardBorder: cardEdge
    readonly property color cardInk:    cream

    // ── Snake ──
    readonly property color snakeLight: "#2ad374"  // neck green (head end of body gradient)
    readonly property color snakeDark:  "#0e4f58"  // tail teal
    readonly property color headGreen:  "#2fb268"  // head capsule
    readonly property color snoutCap:   "#1f8f56"  // darker snout cap (front third)
    readonly property color snakeEye:   "#ffdf2b"  // eye yellow
    readonly property color snakePupil: "#f2772e"  // pupil orange
    readonly property color snakeNose:  "#14603f"  // nostril
    readonly property color snakeCrest: "#e63a3a"  // tongue / eating-mouth red

    // ── Berries (soft currency) ──
    readonly property color berry:     "#8360e0"
    readonly property color berryDeep: "#5a3fb0"

    // ── Store / progression state colours ──
    readonly property color success:   "#46c08a"  // owned / equipped / completed (= primary)
    readonly property color locked:     "#9c7d56"  // locked-cosmetic tint

    // ── Apple ──
    readonly property color apple:     "#e23b2c"
    readonly property color appleLeaf: "#57b845"
    readonly property color appleStem: "#7a4a25"

    // ── Accents ──
    readonly property color title:   "#7fca61"     // "GAME OVER" brand green
    readonly property color gold:    "#e6a93a"      // trophy
    readonly property color good:    primary        // alias → kit primary

    // ── Text ──
    readonly property color text:    "#f3e7cd"       // light text on the jungle bg
    readonly property color textDim: "#d8c39c"
    readonly property color ink:     inkStrong       // alias → kit ink

    // ── Metrics (radii, kit-aligned) ──
    readonly property int rsm:  10
    readonly property int r:    14   // button / control radius
    readonly property int rlg:  22   // dialog card radius
    readonly property int rChip: 999 // pills & chips

    // Bundled UI typeface (also set as the default app font in main.cpp).
    readonly property string ui: "Fredoka"
}
