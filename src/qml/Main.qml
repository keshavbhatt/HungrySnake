import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Effects
import QtCore
import QtMultimedia
import HungrySnake
import "components"

ApplicationWindow {
    id: win
    visible: true
    width: 960
    height: 640
    minimumWidth: 720
    minimumHeight: 480
    title: "Hungry Snake"
    color: Theme.bg

    SnakeGame { id: game }
    Profile   { id: profile }   // persistent Coins currency + lifetime stats
    Cosmetics { id: cosmetics; profile: profile }   // equipped-skin palette resolver
    Achievements { id: achievements; profile: profile; game: game; cosmetics: cosmetics }
    Connections {
        target: achievements
        function onUnlocked(name) { achToast.show(qsTr("Achievement: ") + name, "medal"); }
    }
    // Re-check cosmetics-count achievements whenever the collection grows.
    Connections { target: profile; function onOwnedChanged() { achievements.check(); } }

    property bool soundOn: true
    property bool musicOn: true
    // Selected music track: -1 == Random (shuffle), else an index into musicTracks.
    property int  musicTrack: -1
    property bool settingsOpen: false
    // The best score at the moment the current run began — so, on death, we can
    // tell whether this run set a new best (game.best is already bumped by then).
    property int  bestAtRunStart: 0

    // The looping background tracks (procedurally generated — see tools/make_music.py).
    readonly property var musicTracks: [
        { name: qsTr("Canopy Calm"),   src: "qrc:/assets/sounds/music/canopy_calm.wav" },
        { name: qsTr("Moonlit Vines"), src: "qrc:/assets/sounds/music/moonlit_vines.wav" },
        { name: qsTr("Sunny Grove"),   src: "qrc:/assets/sounds/music/sunny_grove.wav" },
        { name: qsTr("Dewdrop Swing"), src: "qrc:/assets/sounds/music/dewdrop_swing.wav" },
        { name: qsTr("Dusky Hollow"),  src: "qrc:/assets/sounds/music/dusky_hollow.wav" },
        { name: qsTr("Berry Bounce"),  src: "qrc:/assets/sounds/music/berry_bounce.wav" }
    ]
    // Index of the track actually loaded into the player (resolved from musicTrack;
    // in Random mode this is chosen fresh each time playback (re)starts).
    property int currentMusicIndex: 0

    // Opening settings while a run is live pauses it (pause menu); closing resumes.
    function openSettings() {
        if (game.status === SnakeGame.Playing) game.pause(true);
        win.settingsOpen = true;
    }
    function closeSettings() {
        win.settingsOpen = false;
        if (game.status === SnakeGame.Playing) game.pause(false);
    }

    // ── Screen router ──
    // Screens: "home" (landing hub), "game" (board + HUD), "store",
    // "achievements", "daily", "about". Settings/pause stays an overlay
    // (settingsOpen), reachable from any screen. A tiny back-stack drives the
    // back button on sub-screens.
    property string route: "home"
    property var navStack: []
    function navigate(s) { win.navStack = win.navStack.concat([win.route]); win.route = s; }
    function back() {
        if (win.navStack.length > 0) {
            win.route = win.navStack[win.navStack.length - 1];
            win.navStack = win.navStack.slice(0, -1);
        } else {
            win.route = "home";
        }
    }
    // Enter the board and start a fresh run.
    function playGame() {
        win.settingsOpen = false; win.navStack = []; win.dailyActive = false;
        win.route = "game"; game.start();
    }
    // Quit to the menu (pauses a live run so its clock stops behind the hub).
    function goHome() {
        if (game.status === SnakeGame.Playing) game.pause(true);
        win.settingsOpen = false; win.navStack = []; win.dailyActive = false;
        win.route = "home";
    }

    // Redeem the Supporter unlock (generous Coin bundle + exclusive cosmetics).
    // On a real build the KTechpit AccountAndLicense purchase gates this call.
    function becomeSupporter() {
        profile.unlockSupporter(800, cosmetics.supporterIds);
        achToast.show(qsTr("Thanks for supporting Hungry Snake!"), "heart");
    }

    // ── Daily challenge ──
    // Deterministic per calendar day: the same apple seed for everyone, and a
    // target score to beat. Completing it (once/day) pays a streak-scaled reward.
    property string dailyToday: ""
    property string dailyYesterday: ""
    property int    dailySeed: 0
    property int    dailyTarget: 0
    property bool   dailyActive: false                       // a daily run is in progress
    readonly property bool dailyDone: profile.dailyLast === win.dailyToday && win.dailyToday !== ""
    readonly property int  dailyReward: 30 + Math.min(profile.dailyStreak, 10) * 5

    function _ymd(d) {
        return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2)
             + "-" + ("0" + d.getDate()).slice(-2);
    }
    function playDaily() {
        win.settingsOpen = false; win.navStack = [];
        win.dailyActive = true;
        win.route = "game"; game.startSeeded(win.dailySeed);
    }
    // Called on each apple: complete the daily the moment the target is reached.
    function tryCompleteDaily() {
        if (!win.dailyActive || game.score < win.dailyTarget) return;
        const got = profile.completeDaily(win.dailyToday, win.dailyYesterday, win.dailyReward);
        win.dailyActive = false;
        if (got > 0) {
            achToast.show(qsTr("Daily done! +") + got, "calendar");
            achievements.check();   // a longer streak may unlock Daily Devotee
        }
    }

    // ── Background music control ──
    // Pick a random track, avoiding an immediate repeat of the current one.
    function pickRandomIndex() {
        if (musicTracks.length <= 1) return 0;
        var i = Math.floor(Math.random() * musicTracks.length);
        if (i === currentMusicIndex) i = (i + 1) % musicTracks.length;
        return i;
    }
    function resolveMusicIndex() {
        if (win.musicTrack < 0) return pickRandomIndex();      // Random / shuffle
        return Math.max(0, Math.min(win.musicTrack, musicTracks.length - 1));
    }
    // Play only while music is enabled and the window is on-screen (foreground).
    function syncMusic() {
        var shouldPlay = win.musicOn
                      && win.active                       // window has focus
                      && win.visibility !== Window.Minimized
                      && win.visibility !== Window.Hidden;
        if (shouldPlay) {
            if (!bgm.playing) {
                win.currentMusicIndex = resolveMusicIndex();
                bgm.source = musicTracks[win.currentMusicIndex].src;
                bgm.play();
            }
        } else {
            bgm.stop();
        }
    }
    // Switch tracks live (e.g. the user changed the selection while playing).
    function restartMusic() {
        bgm.stop();
        syncMusic();
    }

    onMusicOnChanged: syncMusic()
    onMusicTrackChanged: restartMusic()
    onVisibilityChanged: syncMusic()
    onActiveChanged: syncMusic()

    // Persisted best score + preferences.
    Settings {
        category: "HungrySnake"
        property alias best: game.best
        property alias soundOn: win.soundOn
        property alias musicOn: win.musicOn
        property alias musicTrack: win.musicTrack
    }
    Component.onCompleted: {
        keyLayer.forceActiveFocus();
        syncMusic();
        // Resolve today's daily challenge (constant for the session).
        var now = new Date();
        win.dailyToday = win._ymd(now);
        win.dailyYesterday = win._ymd(new Date(now.getTime() - 86400000));
        win.dailySeed = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();
        win.dailyTarget = 8 + (win.dailySeed % 8);   // 8..15 apples
    }

    // ── Sound ──
    SoundEffect { id: sfxEat;   source: "qrc:/assets/sounds/eat.wav";   volume: 0.7 }
    SoundEffect { id: sfxCrash; source: "qrc:/assets/sounds/crash.wav"; volume: 0.8 }

    // ── Background music: one looping SoundEffect (stays on the light QAudioSink
    // path — no MediaPlayer/ffmpeg). The source is swapped by syncMusic(). ──
    SoundEffect {
        id: bgm
        loops: SoundEffect.Infinite
        volume: 0.7
    }

    Connections {
        target: game
        function onAte()  {
            if (win.soundOn) sfxEat.play();
            win.tryCompleteDaily();               // finish the daily on reaching its target
        }
        function onAteBonus(kind) {
            if (win.soundOn) sfxEat.play();
            win.tryCompleteDaily();               // a star's points can finish the daily too
        }
        function onDied() {
            if (win.soundOn) sfxCrash.play();
            // Bank the Coins for this run's score (apples + bonus food), and record
            // the real apple count separately for the lifetime stats.
            profile.recordRun(game.score, game.apples, game.score > win.bestAtRunStart);
            win.dailyActive = false;              // a daily attempt ends on death
            achievements.check();                 // grant any newly-earned achievements
        }
        function onStatusChanged() {
            if (game.status === SnakeGame.Playing) {
                win.bestAtRunStart = game.best;            // snapshot for the new-best check
                // On a fresh run in Random mode, reshuffle for a new tune.
                if (win.musicOn && win.musicTrack < 0)
                    win.restartMusic();
            }
        }
    }

    // ── Jungle backdrop: bright canopy up top → deep teal on the floor ──
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Theme.bgTop }
            GradientStop { position: 0.55; color: Theme.bg }
            GradientStop { position: 1.0;  color: Theme.bgDeep }
        }
    }

    // ── Decorative foliage framing the scene ──
    // Dark leaf silhouettes clustered around the edges — lighter/thinner up in the
    // canopy, denser and darker on the floor — each swaying gently in the breeze.
    Item {
        anchors.fill: parent

        component Leaf: Image {
            property real len: 360
            property real baseRot: 0
            property real swayAmt: 3
            property int  swayMs: 2800
            property real sway: 0
            // A second, faster/smaller sway on an INCOMMENSURATE period — summed with
            // the primary, the total never repeats, so it reads as natural gusting
            // rather than a metronome.
            property real sway2: 0
            readonly property real sway2Amt: swayAmt * 0.5
            readonly property int  sway2Ms: Math.round(swayMs * 0.53) + 310
            // Subtle "breathing" scale that decouples from the sway (offset period
            // so the canopy never pulses as one) — keeps the foliage feeling alive.
            property real breatheAmt: 0.026
            property int  breatheMs: swayMs + 1500
            property real breathe: 0
            width: len; height: len
            fillMode: Image.PreserveAspectFit
            sourceSize.width: len; sourceSize.height: len
            smooth: true; mipmap: true; antialiasing: true
            transformOrigin: Item.Center
            rotation: baseRot + sway + sway2
            scale: 1 + breathe
            SequentialAnimation on sway {
                loops: Animation.Infinite; running: true
                NumberAnimation { from: -swayAmt; to: swayAmt; duration: swayMs; easing.type: Easing.InOutSine }
                NumberAnimation { from: swayAmt; to: -swayAmt; duration: swayMs; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on sway2 {
                loops: Animation.Infinite; running: true
                NumberAnimation { from: -sway2Amt; to: sway2Amt; duration: sway2Ms; easing.type: Easing.InOutSine }
                NumberAnimation { from: sway2Amt; to: -sway2Amt; duration: sway2Ms; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on breathe {
                loops: Animation.Infinite; running: true
                NumberAnimation { from: -breatheAmt; to: breatheAmt; duration: breatheMs; easing.type: Easing.InOutSine }
                NumberAnimation { from: breatheAmt; to: -breatheAmt; duration: breatheMs; easing.type: Easing.InOutSine }
            }
        }

        readonly property string frond: "qrc:/assets/decor/frond.svg"
        readonly property string broad: "qrc:/assets/decor/broadleaf.svg"
        readonly property string fan:   "qrc:/assets/decor/fanpalm.svg"
        readonly property string vine:  "qrc:/assets/decor/vine.svg"

        // Painted back-to-front for depth: pale ferns high in the canopy behind,
        // dark heavy leaves on the floor in front. Left and right are arranged
        // differently — a monstera cluster on the left, a fan palm on the right —
        // so the two sides never read as a mirror.

        // ── Canopy ferns (light, small, behind) ──
        Leaf { source: parent.frond; len: 430; x: -150;                y: -180; baseRot: 150; opacity: 0.42; swayAmt: 4.2; swayMs: 3300 }
        Leaf { source: parent.frond; len: 300; x: 60;                  y: -165; baseRot: 127; opacity: 0.35; swayAmt: 4.8; swayMs: 2700 }
        Leaf { source: parent.frond; len: 400; x: parent.width - 270;  y: -185; baseRot: 214; opacity: 0.42; swayAmt: 4.0; swayMs: 3150 }
        Leaf { source: parent.frond; len: 290; x: parent.width - 115;  y: -150; baseRot: 242; opacity: 0.35; swayAmt: 5.0; swayMs: 2500 }

        // ── Vines hanging from the top canopy (rooted off the top edge) ──
        Leaf { source: parent.vine;  len: 360; x: 180;                 y: -150; baseRot: 5;   opacity: 0.50; swayAmt: 7.8; swayMs: 2600 }
        Leaf { source: parent.vine;  len: 320; x: parent.width * 0.44; y: -160; baseRot: -6;  opacity: 0.40; swayAmt: 8.6; swayMs: 3050 }
        Leaf { source: parent.vine;  len: 380; x: parent.width - 345;  y: -145; baseRot: 8;   opacity: 0.50; swayAmt: 7.2; swayMs: 2850 }

        // ── Mid sides: LEFT monstera cluster, RIGHT fan palm ──
        Leaf { source: parent.broad; len: 320; x: -95;                 y: parent.height * 0.13; baseRot: 98;  opacity: 0.50; swayAmt: 3.8; swayMs: 3500 }
        Leaf { source: parent.fan;   len: 560; x: parent.width - 360;  y: parent.height * 0.10; baseRot: 196; opacity: 0.54; swayAmt: 3.2; swayMs: 3800 }
        Leaf { source: parent.broad; len: 300; x: -135;                y: parent.height * 0.41; baseRot: 76;  opacity: 0.56; swayAmt: 4.2; swayMs: 3000 }

        // ── Floor leaves (dark, large, in front) ──
        Leaf { source: parent.frond; len: 460; x: -175;                y: parent.height - 330; baseRot: 40;  opacity: 0.66; swayAmt: 4.4; swayMs: 2900 }
        Leaf { source: parent.broad; len: 330; x: 20;                  y: parent.height - 250; baseRot: 20;  opacity: 0.66; swayAmt: 5.2; swayMs: 2400 }
        Leaf { source: parent.broad; len: 300; x: parent.width * 0.47; y: parent.height - 200; baseRot: 8;   opacity: 0.70; swayAmt: 5.6; swayMs: 2250 }
        Leaf { source: parent.frond; len: 480; x: parent.width - 330;  y: parent.height - 355; baseRot: -22; opacity: 0.68; swayAmt: 4.4; swayMs: 3200 }
        Leaf { source: parent.broad; len: 350; x: parent.width - 165;  y: parent.height - 260; baseRot: -42; opacity: 0.64; swayAmt: 4.8; swayMs: 2600 }
    }

    // ── Keyboard controls + the board ──
    Item {
        id: keyLayer
        anchors.fill: parent
        focus: true
        Keys.onPressed: (e) => {
            // Steering is only live on the board (not the hub / sub-screens / pause).
            const inGame = win.route === "game" && !win.settingsOpen;
            switch (e.key) {
            case Qt.Key_Up:    case Qt.Key_W: if (inGame) game.steer(SnakeGame.Up);    e.accepted = true; break;
            case Qt.Key_Down:  case Qt.Key_S: if (inGame) game.steer(SnakeGame.Down);  e.accepted = true; break;
            case Qt.Key_Left:  case Qt.Key_A: if (inGame) game.steer(SnakeGame.Left);  e.accepted = true; break;
            case Qt.Key_Right: case Qt.Key_D: if (inGame) game.steer(SnakeGame.Right); e.accepted = true; break;
            case Qt.Key_Space:
                if (win.settingsOpen) win.closeSettings();
                else if (win.route === "home") win.playGame();
                else if (win.route === "game" && game.status === SnakeGame.Playing) win.openSettings();
                e.accepted = true; break;
            case Qt.Key_Return: case Qt.Key_Enter:
                if (win.route === "home") win.playGame();
                else if (win.route === "game" && (game.status === SnakeGame.Dead || game.status === SnakeGame.Ready)) game.start();
                e.accepted = true; break;
            case Qt.Key_Escape:
                if (win.settingsOpen) win.closeSettings();
                else if (win.route === "game" && game.status === SnakeGame.Playing) win.openSettings();
                else if (win.route !== "home") win.back();
                e.accepted = true; break;
            }
        }

        // ── Top bar: HUD cards (left) + menu (right) ──
        // The board anchors *below* this bar, so on any resize the counters and
        // menu can never float over or touch the grid.
        Item {
            id: topBar
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 96
            visible: win.route === "game"

            Row {
                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 12

                StatCard { glyph: "apple";  value: game.score }
                StatCard { glyph: "trophy"; value: game.best }
                StatCard { glyph: "coin";  value: profile.coins }
            }

            IconButton {
                id: menuBtn
                anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                icon: "menu"
                bg: Theme.hudWood; bgBorder: Theme.hudEdge; borderWidth: 3; color: Theme.cream
                onClicked: win.openSettings()
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: Theme.shadow; shadowBlur: 0.6
                    shadowOpacity: 0.3; shadowVerticalOffset: 4; autoPaddingEnabled: true
                }
            }
        }

        // Board fills the area below the top bar, centred.
        Board {
            id: boardView
            objectName: "boardView"
            game: game
            cosmetics: cosmetics
            visible: win.route === "game"
            anchors { top: topBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
                      topMargin: 6; leftMargin: 62; rightMargin: 62; bottomMargin: 44 }
        }

        // Daily-challenge progress banner while a daily run is live.
        Row {
            visible: win.route === "game" && win.dailyActive
            anchors.horizontalCenter: boardView.horizontalCenter
            y: boardView.y + 10
            spacing: 7
            Icon { name: "calendar"; color: Theme.text; size: 20; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Daily  ") + game.score + " / " + win.dailyTarget
                color: Theme.text; font.family: Theme.ui; font.pixelSize: 17; font.weight: Font.Bold
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.5)
            }
        }

        // "Primed — press a key" hint: shown while the run is set up but not yet
        // moving (it starts on the first steer, so you can't be caught out).
        Text {
            anchors.horizontalCenter: boardView.horizontalCenter
            y: boardView.y + boardView.height * 0.72
            visible: game.waiting && win.route === "game"
            text: qsTr("Press an arrow key to start")
            color: Theme.text
            font.pixelSize: 18; font.weight: Font.DemiBold
            style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.45)
            SequentialAnimation on opacity {
                running: game.waiting; loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 620; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
            }
        }
    }

    // ── Home hub (landing screen) — over the jungle backdrop ──
    Item {
        id: homeScreen
        anchors.fill: parent
        visible: opacity > 0
        opacity: win.route === "home" ? 1 : 0
        enabled: win.route === "home"
        Behavior on opacity { NumberAnimation { duration: 220 } }

        // A vertical icon tile for the hub's secondary actions.
        component HomeTile: Item {
            id: tile
            property string icon: ""
            property string label: ""
            signal clicked
            width: 96; height: 94
            Rectangle {
                id: tileBg
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: 66; height: 66; radius: Theme.r
                color: tileMa.pressed ? Theme.insetDeep
                     : tileMa.containsMouse ? Qt.lighter(Theme.insetTan, 1.06) : Theme.insetTan
                border.width: 2; border.color: Theme.insetEdge
                Icon { anchors.centerIn: parent; name: tile.icon; color: Theme.inkStrong; size: 30 }
                MouseArea {
                    id: tileMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor; onClicked: tile.clicked()
                }
            }
            Text {
                anchors.top: tileBg.bottom; anchors.topMargin: 7
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label; color: Theme.text
                font.family: Theme.ui; font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }

        CoinBalance {
            anchors { top: parent.top; right: parent.right; topMargin: 30; rightMargin: 32 }
            value: profile.coins; iconSize: 30; ink: Theme.text
        }

        Column {
            anchors.centerIn: parent
            spacing: 24
            // Title with a chunky drop shadow. Done as a duplicate Text offset behind
            // the real one (not a MultiEffect): a crisp offset reads well on the heavy
            // display face, and — unlike layered effects in this tree — it renders in
            // headless grabs. The Item sizes to the text so the Column layout is unchanged.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: title.implicitWidth
                implicitHeight: title.implicitHeight
                Text {                                   // shadow (behind, offset down-right)
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 3
                    anchors.verticalCenterOffset: 6
                    text: title.text
                    color: Qt.rgba(0, 0, 0, 0.45)
                    font.family: title.font.family; font.pixelSize: title.font.pixelSize
                    font.weight: title.font.weight
                }
                Text {
                    id: title
                    anchors.centerIn: parent
                    text: "HUNGRY SNAKE"; color: Theme.title
                    font.family: Theme.display; font.pixelSize: 78; font.weight: Font.Bold
                    style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.32)
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Eat apples • grow • don't bite yourself")
                color: Theme.text; font.family: Theme.ui; font.pixelSize: 16
            }
            PillButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Play"); fontSize: 22; onClicked: win.playGame()
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                HomeTile { icon: "store";    label: qsTr("Store");    onClicked: win.navigate("store") }
                HomeTile { icon: "calendar"; label: qsTr("Daily");    onClicked: win.navigate("daily") }
                HomeTile { icon: "medal";    label: qsTr("Awards");   onClicked: win.navigate("achievements") }
                HomeTile { icon: "gear";     label: qsTr("Settings"); onClicked: win.openSettings() }
                HomeTile { icon: "heart";    label: qsTr("Support");  onClicked: win.navigate("about") }
            }
        }
    }

    // ── Sub-screens (Store / Daily / Achievements / About) — Stage-3 stubs.
    // Navigation is fully wired now; the bodies are filled in Stages 4–5. ──
    Item {
        id: subScreens
        anchors.fill: parent

        component StubScreen: Item {
            id: scr
            property string key: ""
            property string title: ""
            property string note: qsTr("Coming soon")
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === scr.key ? 1 : 0
            enabled: win.route === scr.key
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.4) }
            ScreenHeader {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: scr.title
                onBack: win.back()
            }
            CoinBalance {
                anchors { top: parent.top; right: parent.right; topMargin: 34; rightMargin: 32 }
                value: profile.coins; ink: Theme.text
            }
            Text {
                anchors.centerIn: parent
                text: scr.note; color: Theme.textDim
                font.family: Theme.ui; font.pixelSize: 22
            }
        }

        // ── Store — browse cosmetics by slot; buy with Coins and equip. ──
        Item {
            id: store
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === "store" ? 1 : 0
            enabled: win.route === "store"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            property int catIndex: 0
            readonly property string catSlot: cosmetics.slotList[catIndex]

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }

            ScreenHeader {
                id: storeHdr
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: qsTr("Store")
                onBack: win.back()
            }
            CoinBalance {
                anchors { verticalCenter: storeHdr.verticalCenter; right: parent.right; rightMargin: 32 }
                value: profile.coins; ink: Theme.text
            }

            Column {
                anchors { top: storeHdr.bottom; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                spacing: 22

                SegmentedControl {
                    anchors.horizontalCenter: parent.horizontalCenter
                    model: [qsTr("Snake"), qsTr("Board"), qsTr("Apple"), qsTr("Bonus")]
                    currentIndex: store.catIndex
                    onActivated: store.catIndex = index
                }

                Flow {
                    width: Math.min(win.width - 96, 700)
                    spacing: 16
                    Repeater {
                        model: cosmetics.catalogue(store.catSlot)
                        delegate: StoreCard {
                            readonly property string eqId:
                                (profile.equipped[store.catSlot] && profile.equipped[store.catSlot] !== "")
                                    ? profile.equipped[store.catSlot]
                                    : cosmetics.catalogue(store.catSlot)[0].id
                            name: modelData.name
                            price: modelData.price
                            locked: modelData.supporter === true && !profile.supporter
                            owned: modelData.supporter === true
                                   ? profile.supporter
                                   : (modelData.price === 0 || profile.owned.indexOf(modelData.id) >= 0)
                            equipped: eqId === modelData.id
                            affordable: profile.coins >= modelData.price
                            onBuy: {
                                if (profile.buy(modelData.id, modelData.price))
                                    profile.equip(store.catSlot, modelData.id);
                            }
                            onEquip: profile.equip(store.catSlot, modelData.id)
                            onUnlock: win.navigate("about")   // go redeem Supporter
                            // Previews render the REAL art (AppleArt is literally the same
                            // component the board draws), not abstract swatches.
                            preview: Component {
                                Item {
                                    id: sw
                                    anchors.fill: parent
                                    property var def: modelData      // capture the outer cosmetic def

                                    SnakeArt {
                                        visible: store.catSlot === "snake"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.92; height: 46
                                        head:  sw.def.head  || Theme.headGreen
                                        snout: sw.def.snout || Theme.snoutCap
                                        light: sw.def.light || Theme.snakeLight
                                        dark:  sw.def.dark  || Theme.snakeDark
                                        nose:  sw.def.nose  || Theme.snakeNose
                                    }
                                    BoardArt {
                                        visible: store.catSlot === "board"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.88; height: parent.height * 0.84
                                        tileA:   sw.def.a       || Theme.tileA
                                        tileB:   sw.def.b       || Theme.tileB
                                        tileGap: sw.def.gap     || Theme.tileGap
                                        frame:   sw.def.frame   || Theme.frame
                                        frameHi: sw.def.frameHi || Theme.frameHi
                                    }
                                    Row {                             // bonus-food skin: star + leaf
                                        visible: store.catSlot === "bonus"
                                        anchors.centerIn: parent
                                        spacing: 6
                                        BonusFoodArt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 34; height: 34
                                            kind: 0; life: 1; d: 26; showRing: false
                                            goldTint: sw.def.gold     || "#f0c23a"
                                            goldDeep: sw.def.goldDeep || "#a9781a"
                                        }
                                        BonusFoodArt {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 34; height: 34
                                            kind: 1; life: 1; d: 26; showRing: false
                                            mintTint: sw.def.mint     || "#5fe0a8"
                                            mintDeep: sw.def.mintDeep || "#1f8f66"
                                        }
                                    }
                                    AppleArt {                        // origin = fruit centre
                                        visible: store.catSlot === "apple"
                                        x: parent.width / 2
                                        y: parent.height / 2 + 6
                                        d: 44
                                        shadow: false                 // too tight for a drop shadow
                                        body: sw.def.body || Theme.apple
                                        leaf: sw.def.leaf || Theme.appleLeaf
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Daily challenge ──
        Item {
            id: dailyScr
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === "daily" ? 1 : 0
            enabled: win.route === "daily"
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5) }
            ScreenHeader {
                id: dhdr
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: qsTr("Daily Challenge"); onBack: win.back()
            }
            CoinBalance {
                anchors { verticalCenter: dhdr.verticalCenter; right: parent.right; rightMargin: 32 }
                value: profile.coins; ink: Theme.text
            }

            Column {
                anchors.centerIn: parent
                spacing: 22
                Icon { anchors.horizontalCenter: parent.horizontalCenter
                       name: "calendar"; color: Theme.text; size: 60 }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Reach a score of ") + win.dailyTarget
                    color: Theme.text; font.family: Theme.ui; font.pixelSize: 28; font.weight: Font.Bold
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 40
                    Column {
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: profile.dailyStreak
                               color: Theme.title; font.family: Theme.ui; font.pixelSize: 34; font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("day streak")
                               color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 14 }
                    }
                    Column {
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 5
                            Icon { name: "coin"; size: 28; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: win.dailyReward; color: Theme.text; font.family: Theme.ui
                                   font.pixelSize: 34; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: qsTr("reward")
                               color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 14 }
                    }
                }
                PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !win.dailyDone
                    text: qsTr("Play Daily"); fontSize: 20; onClicked: win.playDaily()
                }
                Row {
                    visible: win.dailyDone
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                    Icon { name: "check"; color: Theme.success; size: 26; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: qsTr("Completed today!"); color: Theme.success
                           font.family: Theme.ui; font.pixelSize: 20; font.weight: Font.Bold
                           anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // ── Achievements ──
        Item {
            id: achScr
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === "achievements" ? 1 : 0
            enabled: win.route === "achievements"
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }
            ScreenHeader {
                id: ahdr
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: qsTr("Achievements"); onBack: win.back()
            }
            CoinBalance {
                anchors { verticalCenter: ahdr.verticalCenter; right: parent.right; rightMargin: 32 }
                value: profile.coins; ink: Theme.text
            }

            Flickable {
                anchors { top: ahdr.bottom; topMargin: 12; horizontalCenter: parent.horizontalCenter
                          bottom: parent.bottom; bottomMargin: 20 }
                width: Math.min(win.width - 80, 620)
                contentHeight: achCol.implicitHeight
                clip: true
                Column {
                    id: achCol
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: achievements.list
                        delegate: Rectangle {
                            width: parent.width; height: 74; radius: Theme.r
                            readonly property int cur:
                                  modelData.stat === "apples"    ? profile.lifetimeApples
                                : modelData.stat === "games"     ? profile.gamesPlayed
                                : modelData.stat === "best"      ? game.best
                                : modelData.stat === "streak"    ? profile.bestStreak
                                : modelData.stat === "cosmetics" ? profile.owned.length : 0
                            readonly property bool done: profile.claimed.indexOf(modelData.id) >= 0
                            // A claimed row's tint sits on the dark scrim, so its text has
                            // to flip light — dark ink on that green is unreadable.
                            readonly property color ink:    done ? Theme.cream   : Theme.inkStrong
                            readonly property color inkDim: done ? Theme.textDim : Theme.inkStrong
                            color: done ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.18)
                                        : Theme.insetTan
                            border.width: 2
                            border.color: done ? Theme.success : Theme.insetEdge

                            Rectangle {
                                id: badge
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                width: 46; height: 46; radius: Theme.rsm
                                color: done ? Theme.success : Theme.hudWood
                                Icon { anchors.centerIn: parent; name: modelData.icon; color: Theme.cream; size: 26 }
                            }
                            Column {
                                id: rewardCol
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 3
                                    Icon { name: "coin"; size: 16; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.reward; color: ink; font.family: Theme.ui
                                           font.pixelSize: 15; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Text { visible: done; text: qsTr("owned"); color: Theme.title
                                       font.family: Theme.ui; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                            Column {
                                anchors { left: badge.right; leftMargin: 14; right: rewardCol.left; rightMargin: 12
                                          verticalCenter: parent.verticalCenter }
                                spacing: 6
                                Text { text: modelData.name; color: ink; font.family: Theme.ui
                                       font.pixelSize: 16; font.weight: Font.Bold }
                                Text { text: modelData.desc; color: inkDim; font.family: Theme.ui; font.pixelSize: 12 }
                                ProgressBar {
                                    width: 250
                                    value: Math.min(parent.parent.cur, modelData.target); to: modelData.target
                                    fill: parent.parent.done ? Theme.success : Theme.primary
                                }
                            }
                        }
                    }
                }
            }
        }
        // ── About / Supporter ──
        Item {
            id: aboutScr
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === "about" ? 1 : 0
            enabled: win.route === "about"
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }
            ScreenHeader {
                id: abhdr
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: qsTr("Support Hungry Snake"); onBack: win.back()
            }

            Column {
                anchors.centerIn: parent
                width: Math.min(win.width - 120, 520)
                spacing: 18

                Icon { anchors.horizontalCenter: parent.horizontalCenter
                       name: "heart"; color: Theme.danger; size: 54 }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: qsTr("Hungry Snake is free — and always will be. If you're enjoying it, become a Supporter to unlock exclusive skins and a big Coin bundle, and help fund new updates.")
                    color: Theme.text; font.family: Theme.ui; font.pixelSize: 16
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width; radius: Theme.rlg
                    color: Theme.cardTan; border.width: 2; border.color: Theme.cardEdge
                    implicitHeight: perkCol.implicitHeight + 32

                    Column {
                        id: perkCol
                        anchors { top: parent.top; topMargin: 16; horizontalCenter: parent.horizontalCenter }
                        width: parent.width - 40
                        spacing: 12

                        Column {                                   // not yet a supporter
                            visible: !profile.supporter
                            width: parent.width; spacing: 12
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Icon { name: "coin"; size: 24; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: qsTr("800 Coin bundle"); color: Theme.inkStrong; font.family: Theme.ui
                                       font.pixelSize: 16; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Icon { name: "sparkle"; color: Theme.gold; size: 24; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: qsTr("3 exclusive Supporter cosmetics"); color: Theme.inkStrong; font.family: Theme.ui
                                       font.pixelSize: 16; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            PillButton {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Become a Supporter"); fontSize: 18
                                onClicked: win.becomeSupporter()
                            }
                        }

                        Column {                                   // already a supporter
                            visible: profile.supporter
                            width: parent.width; spacing: 8
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Icon { name: "heart"; color: Theme.success; size: 26; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: qsTr("You're a Supporter — thank you!"); color: Theme.success; font.family: Theme.ui
                                       font.pixelSize: 18; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Your exclusive cosmetics are waiting in the Store.")
                                color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 14
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Made by KTechpit • Built with Qt Quick")
                    color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
                }
            }
        }
    }

    // ── Game Over overlay ──
    Rectangle {
        id: overlay
        anchors.fill: parent
        readonly property bool dead: game.status === SnakeGame.Dead && win.route === "game"
        // Hold the overlay back briefly on death so the board shake + head-burst
        // play on the clear field first, then fade the Game Over card in.
        property bool active: false
        // Coins-earned count-up shown on the card (animates 0 → what this run earned).
        property int shownCoins: 0
        onDeadChanged: { if (dead) overDelay.restart(); else active = false; }
        onActiveChanged: if (active) coinCount.restart()
        Timer { id: overDelay; interval: 430; onTriggered: overlay.active = true }
        NumberAnimation {
            id: coinCount; target: overlay; property: "shownCoins"
            from: 0; to: profile.lastRunCoins; duration: 650; easing.type: Easing.OutCubic
        }
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: overCol.implicitWidth + 88
            height: overCol.implicitHeight + 56
            radius: Theme.rlg
            color: Theme.cardTan
            border.width: 3
            border.color: Theme.cardEdge
            transformOrigin: Item.Center
            scale: overlay.active ? 1.0 : 0.9
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1.0
                shadowOpacity: 0.5; shadowVerticalOffset: 16; autoPaddingEnabled: true
            }

            Column {
                id: overCol
                anchors.centerIn: parent
                spacing: 20

                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Game Over"); color: Theme.inkStrong
                       font.family: Theme.ui; font.pixelSize: 40; font.weight: Font.Bold }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    component ScoreChip: Rectangle {
                        property string glyph: ""
                        property int value: 0
                        width: 128; height: 74; radius: Theme.r
                        color: Theme.insetTan          // inset panel — stat block in a dialog
                        Row {
                            anchors.centerIn: parent; spacing: 12
                            Item {
                                width: 36; height: 36; anchors.verticalCenter: parent.verticalCenter
                                Icon { anchors.centerIn: parent; name: glyph; size: 34 }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: value
                                   color: Theme.inkStrong; font.family: Theme.ui
                                   font.pixelSize: 32; font.weight: Font.Bold }
                        }
                    }
                    ScoreChip { glyph: "apple";  value: game.score }
                    ScoreChip { glyph: "trophy"; value: game.best }
                }

                // Coins earned this run (hidden on a fruitless run).
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: profile.lastRunCoins > 0
                    Item {
                        width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "coin"; size: 28 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + overlay.shownCoins
                        color: Theme.coinDeep; font.family: Theme.ui
                        font.pixelSize: 26; font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("coins earned")
                        color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 17
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    PillButton { text: qsTr("Continue"); fontSize: 18; onClicked: game.restart() }
                    IconButton { icon: "restart"; onClicked: game.restart() }
                    IconButton { icon: "home"; onClicked: win.goHome() }
                }
            }
        }
    }

    // ── Settings / pause dialog (kit tan card) ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0
        opacity: win.settingsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: win.closeSettings() }

        Rectangle {
            anchors.centerIn: parent
            width: 348
            radius: Theme.rlg
            color: Theme.cardTan
            border.width: 3
            border.color: Theme.cardEdge
            implicitHeight: scol.implicitHeight + 44
            transformOrigin: Item.Center
            scale: win.settingsOpen ? 1.0 : 0.9
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1.0
                shadowOpacity: 0.5; shadowVerticalOffset: 16; autoPaddingEnabled: true
            }
            MouseArea { anchors.fill: parent }   // absorb clicks so they don't dismiss

            Column {
                id: scol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 6

                Item {
                    width: parent.width; height: 46
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: game.status === SnakeGame.Playing ? qsTr("Paused") : qsTr("Settings")
                        color: Theme.inkStrong; font.family: Theme.ui
                        font.pixelSize: 24; font.weight: Font.Bold
                    }
                    IconButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        icon: "close"; iconSize: 18
                        implicitWidth: 40; implicitHeight: 40
                        onClicked: win.closeSettings()
                    }
                }

                ToggleRow { label: qsTr("Sound"); checked: win.soundOn; onToggled: win.soundOn = !win.soundOn }
                ToggleRow { label: qsTr("Music"); checked: win.musicOn; onToggled: win.musicOn = !win.musicOn }

                // ── Track selector: Random + one chip per track ──
                Item {
                    width: parent.width
                    implicitHeight: trackFlow.implicitHeight
                    opacity: win.musicOn ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Flow {
                        id: trackFlow
                        width: parent.width
                        spacing: 8

                        Repeater {
                            model: [{ label: qsTr("Random"), idx: -1 }].concat(
                                       win.musicTracks.map(function (t, i) {
                                           return { label: t.name, idx: i };
                                       }))
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: win.musicTrack === modelData.idx
                                height: 34
                                width: chipLabel.implicitWidth + 30
                                radius: height / 2
                                color: sel ? Theme.primary : Theme.insetTan
                                border.width: 2
                                border.color: sel ? Theme.primaryDeep : Theme.insetEdge
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: sel ? "white" : Theme.inkStrong
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: win.musicOn
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.musicTrack = modelData.idx
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 8 }

                PillButton {
                    width: parent.width
                    text: game.status === SnakeGame.Playing ? qsTr("Resume") : qsTr("Close")
                    onClicked: win.closeSettings()
                }
                PillButton {
                    width: parent.width
                    visible: win.route === "game"     // restarting only makes sense mid-game
                    text: qsTr("Restart")
                    raised: false
                    fill: Theme.insetTan
                    ink: Theme.inkStrong
                    weight: Font.DemiBold
                    onClicked: { game.restart(); win.closeSettings(); }
                }
                PillButton {
                    width: parent.width
                    visible: win.route === "game"     // quit the run back to the hub
                    text: qsTr("Main Menu")
                    raised: false
                    fill: Theme.insetTan
                    ink: Theme.inkStrong
                    weight: Font.DemiBold
                    onClicked: win.goHome()
                }

                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    topPadding: 2
                    text: qsTr("Space or Esc to resume")
                    color: Theme.inkSoft
                    font.pixelSize: 13
                }
            }
        }
    }

    // Auto-hide the mouse cursor after a moment of stillness (it distracts during
    // play); any mouse movement brings it straight back. Sits on top but ignores
    // buttons (Qt.NoButton) so clicks still reach the UI beneath.
    MouseArea {
        id: cursorHider
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        propagateComposedEvents: true
        property bool hidden: false
        cursorShape: hidden ? Qt.BlankCursor : Qt.ArrowCursor
        onPositionChanged: { hidden = false; hideTimer.restart(); }
        onEntered: hideTimer.restart()
        onExited: hideTimer.stop()
        Timer { id: hideTimer; interval: 2500; running: true; onTriggered: cursorHider.hidden = true }
    }

    // Transient notification (achievement unlocked / daily complete) — topmost.
    Toast {
        id: achToast
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22
    }
}
