import QtQuick
import HungrySnake

// The achievements catalogue + the checker that grants newly-earned ones. An
// instance (takes `profile` + `game`): each entry compares a lifetime/run stat
// against a target and pays a one-time Coin reward. `check()` is called after a
// run and when cosmetics change; it emits `unlocked` per newly-earned award.
QtObject {
    id: ach
    property Profile  profile: null
    property SnakeGame game: null
    signal unlocked(string name)

    // Total paid cosmetics (for the "own all" achievement) — kept in step with Cosmetics.qml.
    readonly property int cosmeticsTotal: 12

    readonly property var list: [
        { id: "first_bite",    name: qsTr("First Bite"),    desc: qsTr("Eat your first apple"),      icon: "apple",    stat: "apples",    target: 1,   reward: 5 },
        { id: "sweet_tooth",   name: qsTr("Sweet Tooth"),   desc: qsTr("Eat 50 apples in total"),    icon: "apple",    stat: "apples",    target: 50,  reward: 20 },
        { id: "orchardist",    name: qsTr("Orchardist"),    desc: qsTr("Eat 250 apples in total"),   icon: "apple",    stat: "apples",    target: 250, reward: 60 },
        { id: "big_snake",     name: qsTr("Big Snake"),     desc: qsTr("Reach a score of 15"),       icon: "trophy",   stat: "best",      target: 15,  reward: 20 },
        { id: "anaconda",      name: qsTr("Anaconda"),      desc: qsTr("Reach a score of 30"),       icon: "trophy",   stat: "best",      target: 30,  reward: 50 },
        { id: "regular",       name: qsTr("Regular"),       desc: qsTr("Play 25 games"),             icon: "medal",    stat: "games",     target: 25,  reward: 25 },
        { id: "devotee",       name: qsTr("Daily Devotee"), desc: qsTr("Hit a 7-day daily streak"),  icon: "calendar", stat: "streak",    target: 7,   reward: 60 },
        { id: "collector",     name: qsTr("Collector"),     desc: qsTr("Own 4 cosmetics"),           icon: "store",    stat: "cosmetics", target: 4,   reward: 40 },
        { id: "completionist", name: qsTr("Completionist"), desc: qsTr("Own every cosmetic"),        icon: "sparkle",  stat: "cosmetics", target: cosmeticsTotal, reward: 150 }
    ]

    function stat(key) {
        if (!profile) return 0;
        switch (key) {
        case "apples":    return profile.lifetimeApples;
        case "games":     return profile.gamesPlayed;
        case "best":      return game ? game.best : 0;
        case "streak":    return profile.bestStreak;
        case "cosmetics": return profile.owned.length;
        }
        return 0;
    }
    function isUnlocked(a) { return profile ? (profile.claimed.indexOf(a.id) >= 0) : false; }

    // Grant any newly-earned achievements; emits unlocked(name) for each.
    function check() {
        if (!profile) return;
        for (var i = 0; i < list.length; i++) {
            var a = list[i];
            if (profile.claimed.indexOf(a.id) < 0 && stat(a.stat) >= a.target) {
                if (profile.claimAchievement(a.id, a.reward) >= 0)
                    ach.unlocked(a.name);
            }
        }
    }
}
