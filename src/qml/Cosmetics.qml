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
    readonly property var slotList: ["snake", "board", "apple"]

    // ── Catalogues (price 0 == the free default, first in each list) ──
    readonly property var snakeSkins: [
        { id: "snake_jungle", name: qsTr("Jungle"), price: 0,
          head: "#2fb268", snout: "#1f8f56", light: "#2ad374", dark: "#0e4f58", nose: "#14603f" },
        { id: "snake_ember",  name: qsTr("Ember"),  price: 80,
          head: "#e0632f", snout: "#b3441c", light: "#f39442", dark: "#7a2a12", nose: "#8f3316" },
        { id: "snake_ocean",  name: qsTr("Ocean"),  price: 80,
          head: "#2f8fd6", snout: "#1c6ab3", light: "#3fb0f3", dark: "#123f7a", nose: "#164f8f" },
        { id: "snake_orchid", name: qsTr("Orchid"), price: 120,
          head: "#8a5cd6", snout: "#6a3fb3", light: "#a97cf3", dark: "#3f2a7a", nose: "#4f2f8f" },
        { id: "snake_gold",   name: qsTr("Golden"), price: 0, supporter: true,
          head: "#e0b23f", snout: "#b3891c", light: "#f3cc55", dark: "#7a5a12", nose: "#8f6b16" }
    ]
    readonly property var boardThemes: [
        { id: "board_wood",  name: qsTr("Wood"),   price: 0,
          a: "#c68d56", b: "#a06b3b", gap: "#583720", frame: "#7a4c26", frameHi: "#9a6636" },
        { id: "board_slate", name: qsTr("Slate"),  price: 70,
          a: "#8b93a0", b: "#6c7482", gap: "#33383f", frame: "#454b54", frameHi: "#5c636d" },
        { id: "board_meadow",name: qsTr("Meadow"), price: 70,
          a: "#8fbf5a", b: "#6b9c3d", gap: "#2f4a1f", frame: "#4c7a26", frameHi: "#66a036" },
        { id: "board_sand",  name: qsTr("Desert"), price: 90,
          a: "#e0c98a", b: "#c9a866", gap: "#8a7040", frame: "#b08a55", frameHi: "#caa06a" },
        { id: "board_obsidian", name: qsTr("Obsidian"), price: 0, supporter: true,
          a: "#3a3f4a", b: "#2a2e37", gap: "#e0b23f", frame: "#1a1d23", frameHi: "#e0b23f" }
    ]
    readonly property var appleSkins: [
        { id: "apple_red",    name: qsTr("Apple"),  price: 0,  body: "#e23b2c", leaf: "#57b845" },
        { id: "apple_gold",   name: qsTr("Golden"), price: 60, body: "#e8b53a", leaf: "#8bd05a" },
        { id: "apple_berry",  name: qsTr("Berry"),  price: 60, body: "#5b6be0", leaf: "#57b845" },
        { id: "apple_cherry", name: qsTr("Cherry"), price: 90, body: "#c81e46", leaf: "#57b845" },
        { id: "apple_diamond",name: qsTr("Diamond"),price: 0, supporter: true, body: "#79dbe0", leaf: "#8bd0d0" }
    ]

    // Exclusive cosmetics granted by the Supporter unlock (see the About screen).
    readonly property var supporterIds: ["snake_gold", "board_obsidian", "apple_diamond"]

    function catalogue(slot) {
        return slot === "snake" ? snakeSkins
             : slot === "board" ? boardThemes
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
}
