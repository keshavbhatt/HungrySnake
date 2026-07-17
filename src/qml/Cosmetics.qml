import QtQuick
import HungrySnake

// The cosmetics catalogue + the resolver for what's currently equipped. An
// instance (not a singleton) so it can bind to the Profile: set `profile` and
// read the resolved palette (headGreen, tileA, apple, …). Board.qml + the HUD
// bind to these instead of the fixed Theme colours, so equipping a skin restyles
// the game live. Cosmetics are purely visual — they never touch gameplay.
QtObject {
    id: cos
    property Profile profile: null

    // Slot order used by the Store's category tabs.
    readonly property var slotList: ["snake", "board", "apple", "bonus"]

    // ── Catalogues (price 0 == the free default, first in each list) ──
    readonly property var snakeSkins: [
        { id: "snake_jungle", name: qsTr("Jungle"), price: 0,
          head: "#2fb268", snout: "#1f8f56", light: "#2ad374", dark: "#0e4f58", nose: "#14603f" },
        { id: "snake_ember",  name: qsTr("Ember"),  price: 200,
          head: "#e0632f", snout: "#b3441c", light: "#f39442", dark: "#7a2a12", nose: "#8f3316" },
        { id: "snake_ocean",  name: qsTr("Ocean"),  price: 280,
          head: "#2f8fd6", snout: "#1c6ab3", light: "#3fb0f3", dark: "#123f7a", nose: "#164f8f" },
        { id: "snake_orchid", name: qsTr("Orchid"), price: 420,
          head: "#8a5cd6", snout: "#6a3fb3", light: "#a97cf3", dark: "#3f2a7a", nose: "#4f2f8f" },
        { id: "snake_mint",   name: qsTr("Mint"),   price: 180,
          head: "#3fd6b0", snout: "#24a888", light: "#5ff0cc", dark: "#0e5a52", nose: "#157a63" },
        { id: "snake_coral",  name: qsTr("Coral"),  price: 240,
          head: "#f0715f", snout: "#c44a3a", light: "#ff9a86", dark: "#7a2a20", nose: "#93372a" },
        { id: "snake_shadow", name: qsTr("Shadow"), price: 340,
          head: "#4a5060", snout: "#33384a", light: "#6b7288", dark: "#1a1d26", nose: "#232735" },
        { id: "snake_gold",   name: qsTr("Golden"), price: 0, supporter: true,
          head: "#e0b23f", snout: "#b3891c", light: "#f3cc55", dark: "#7a5a12", nose: "#8f6b16" }
    ]
    readonly property var boardThemes: [
        { id: "board_wood",  name: qsTr("Wood"),   price: 0,
          a: "#c68d56", b: "#a06b3b", gap: "#583720", frame: "#7a4c26", frameHi: "#9a6636" },
        { id: "board_slate", name: qsTr("Slate"),  price: 160,
          a: "#8b93a0", b: "#6c7482", gap: "#33383f", frame: "#454b54", frameHi: "#5c636d" },
        { id: "board_meadow",name: qsTr("Meadow"), price: 240,
          a: "#8fbf5a", b: "#6b9c3d", gap: "#2f4a1f", frame: "#4c7a26", frameHi: "#66a036" },
        { id: "board_sand",  name: qsTr("Desert"), price: 320,
          a: "#e0c98a", b: "#c9a866", gap: "#8a7040", frame: "#b08a55", frameHi: "#caa06a" },
        { id: "board_tide",  name: qsTr("Tide"),   price: 200,
          a: "#7fb8d6", b: "#5d94b5", gap: "#2f4a5a", frame: "#3f6d85", frameHi: "#5a90aa" },
        { id: "board_candy", name: qsTr("Candy"),  price: 260,
          a: "#f2c0d8", b: "#d998b8", gap: "#8a5570", frame: "#b06d90", frameHi: "#cf8aae" },
        { id: "board_dusk",  name: qsTr("Dusk"),   price: 340,
          a: "#7a6fa8", b: "#5b5286", gap: "#2e2846", frame: "#443c66", frameHi: "#5f5588" },
        { id: "board_obsidian", name: qsTr("Obsidian"), price: 0, supporter: true,
          a: "#3a3f4a", b: "#2a2e37", gap: "#e0b23f", frame: "#1a1d23", frameHi: "#e0b23f" }
    ]
    readonly property var appleSkins: [
        { id: "apple_red",    name: qsTr("Apple"),  price: 0,  body: "#e23b2c", leaf: "#57b845" },
        { id: "apple_gold",   name: qsTr("Golden"), price: 120, body: "#e8b53a", leaf: "#8bd05a" },
        { id: "apple_berry",  name: qsTr("Berry"),  price: 220, body: "#5b6be0", leaf: "#57b845" },
        { id: "apple_cherry", name: qsTr("Cherry"), price: 300, body: "#c81e46", leaf: "#57b845" },
        { id: "apple_lime",   name: qsTr("Lime"),   price: 140, body: "#8fd14a", leaf: "#4f9e2a" },
        { id: "apple_plum",   name: qsTr("Plum"),   price: 240, body: "#8a4fb0", leaf: "#57b845" },
        { id: "apple_melon",  name: qsTr("Melon"),  price: 280, body: "#f07f9a", leaf: "#57b845" },
        { id: "apple_diamond",name: qsTr("Diamond"),price: 0, supporter: true, body: "#79dbe0", leaf: "#8bd0d0" }
    ]

    // Bonus-food skins. IMPORTANT: these restyle how the timed Star/Mint foods LOOK —
    // the foods themselves are always available to everyone. Selling the foods would let
    // the Supporter coin bundle buy scoring power; skins keep the Store gameplay-neutral.
    // The star/leaf SHAPES are fixed for exactly this reason (see BonusFoodArt.qml).
    readonly property var bonusSkins: [
        { id: "bonus_classic", name: qsTr("Classic"), price: 0,
          gold: "#f0c23a", goldDeep: "#a9781a", mint: "#5fe0a8", mintDeep: "#1f8f66" },
        { id: "bonus_ruby",    name: qsTr("Ruby"),    price: 200,
          gold: "#f05a72", goldDeep: "#a01f38", mint: "#f0a0b8", mintDeep: "#a04f66" },
        { id: "bonus_frost",   name: qsTr("Frost"),   price: 240,
          gold: "#7fd8f0", goldDeep: "#1f6f90", mint: "#bfe8f5", mintDeep: "#4f90a8" },
        { id: "bonus_neon",    name: qsTr("Neon"),    price: 320,
          gold: "#f050d0", goldDeep: "#8a0f70", mint: "#b8f050", mintDeep: "#5f8a0f" },
        { id: "bonus_prism",   name: qsTr("Prism"),   price: 0, supporter: true,
          gold: "#e9b6ff", goldDeep: "#7a3fb0", mint: "#b6f7ff", mintDeep: "#2f7f96" }
    ]

    // Exclusive cosmetics granted by the Supporter unlock (see the About screen).
    readonly property var supporterIds: ["snake_gold", "board_obsidian", "apple_diamond", "bonus_prism"]

    function catalogue(slot) {
        return slot === "snake" ? snakeSkins
             : slot === "board" ? boardThemes
             : slot === "bonus" ? bonusSkins
             : appleSkins;
    }
    function _find(list, id) {
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id) return list[i];
        return list[0];   // default (free) entry
    }
    function _equipped(slot) {
        return (profile && profile.equipped[slot]) ? profile.equipped[slot] : catalogue(slot)[0].id;
    }

    // ── Resolved equipped definitions (re-evaluate when profile.equipped changes) ──
    readonly property var snake: _find(snakeSkins,  _equipped("snake"))
    readonly property var board: _find(boardThemes, _equipped("board"))
    readonly property var fruit: _find(appleSkins,  _equipped("apple"))
    readonly property var bonusSet: _find(bonusSkins, _equipped("bonus"))

    // ── Resolved palette (what Board.qml / HUD read) ──
    readonly property color headGreen:  snake.head
    readonly property color snoutCap:   snake.snout
    readonly property color snakeLight: snake.light
    readonly property color snakeDark:  snake.dark
    readonly property color snakeNose:  snake.nose

    readonly property color tileA:      board.a
    readonly property color tileB:      board.b
    readonly property color tileGap:    board.gap
    readonly property color frame:      board.frame
    readonly property color frameHi:    board.frameHi

    readonly property color apple:      fruit.body
    readonly property color appleLeaf:  fruit.leaf
    readonly property color appleStem:  Theme.appleStem   // constant across skins

    // Bonus-food tints (the star/leaf shapes never change — only their colours).
    readonly property color starTint:   bonusSet.gold
    readonly property color starDeep:   bonusSet.goldDeep
    readonly property color leafTint:   bonusSet.mint
    readonly property color leafDeep:   bonusSet.mintDeep
}
