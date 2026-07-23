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
    visibility: Window.FullScreen   // the game always launches fullscreen
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
    Leaderboard { id: leaderboard }   // global ranks (Supabase REST, or a mock demo board offline)
    Connections {
        target: achievements
        function onUnlocked(name) { achToast.show(qsTr("Achievement: ") + name, "medal"); }
    }
    // Celebrate a posted personal best with the player's new global rank.
    Connections {
        target: leaderboard
        function onSubmitted(rank) {
            achToast.show(rank > 0 ? qsTr("You reached #%1 worldwide!").arg(rank)
                                   : qsTr("Best posted to the leaderboard!"), "trophy");
        }
    }
    // The Supporter Pack is verified by the KTechpit license backend. When it confirms
    // a paid license, grant the benefits once (Coin bundle + exclusive cosmetics). We
    // never revoke — the pack is "yours forever" — so this only ever unlocks.
    Connections {
        target: LicenseController
        function onStatusChanged() {
            if (LicenseController.hasPaidAccess && !profile.supporter) {
                profile.unlockSupporter(800, cosmetics.supporterIds);
                achToast.show(qsTr("Thanks for supporting Hungry Snake!"), "heart");
            }
        }
    }
    // Re-check cosmetics-count achievements whenever the collection grows.
    Connections { target: profile; function onOwnedChanged() { achievements.check(); } }

    property bool soundOn: true
    property bool turnSoundOn: false      // the per-turn blip is opt-in (off by default)
    property bool musicOn: true
    // The game always launches fullscreen (see the window's `visibility` above). F11
    // still toggles for the current session, but the choice is not persisted.
    readonly property bool isFullscreen: win.visibility === Window.FullScreen
    // Selected music track: -1 == Random (shuffle), else an index into musicTracks.
    property int  musicTrack: -1
    property bool settingsOpen: false     // the audio/music Settings panel
    property bool pauseOpen: false         // the in-game Pause menu (quick actions)
    // The best score at the moment the current run began — so, on death, we can
    // tell whether this run set a new best (game.best is already bumped by then).
    property int  bestAtRunStart: 0
    property bool newBestFired: false     // "New Best!" already celebrated this run
    property bool lastRunWasBest: false   // did the finished run set a record?
    property bool lbNickAsked: false      // once true, stop auto-prompting for a leaderboard nickname

    // Supporter status follows the LIVE license (the license layer caches it offline,
    // so a real buyer stays a Supporter without a connection). This — not the persisted
    // profile.supporter flag — drives the About screen and the Store's exclusive items,
    // so the real purchase state (and the SN_LICSET dev hook) actually control it.
    // profile.supporter is kept only as the one-time "Coin bundle already granted" guard.
    readonly property bool isSupporter: LicenseController.hasPaidAccess

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

    // The in-game Pause menu (quick actions) pauses the run; closing resumes.
    function openPause() {
        if (game.status === SnakeGame.Playing) game.pause(true);
        win.pauseOpen = true;
    }
    function closePause() {
        win.pauseOpen = false;
        if (game.status === SnakeGame.Playing) game.pause(false);
    }
    // The Settings panel (audio + music) is a SEPARATE dialog — opened from the Home
    // tile or the Pause menu's Settings button. It doesn't touch the run (the Pause
    // menu already paused it when reached from in-game), so it can layer over Pause.
    function openSettings() { win.settingsOpen = true; }
    function closeSettings() { win.settingsOpen = false; }

    // F11 toggles fullscreen for the current session only (not persisted — the next
    // launch is always fullscreen).
    function setFullscreen(on) { win.visibility = on ? Window.FullScreen : Window.Windowed; }
    function toggleFullscreen() { win.setFullscreen(!win.isFullscreen); }

    // Quit outright. Fullscreen hides the window's close button, so the game needs its
    // own exit (the Home "Quit" tile and Ctrl+Q both call this).
    function quitApp() { Qt.quit(); }

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
        win.settingsOpen = false; win.pauseOpen = false; win.navStack = []; win.dailyActive = false;
        win.route = "game"; game.start();
    }
    // Quit to the menu (pauses a live run so its clock stops behind the hub).
    function goHome() {
        if (game.status === SnakeGame.Playing) game.pause(true);
        win.settingsOpen = false; win.pauseOpen = false; win.navStack = []; win.dailyActive = false;
        win.route = "home";
    }

    // Start the Supporter Pack purchase: opens the KTechpit checkout in the browser.
    // The actual grant happens only once the license backend verifies the purchase
    // (see the LicenseController Connections below) — never optimistically here.
    function becomeSupporter() {
        LicenseController.openCheckout();
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
        win.settingsOpen = false; win.pauseOpen = false; win.navStack = [];
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
    // Step the track selection through [Random, track0..trackN] (wraps). musicTrack
    // is -1 for Random, else the track index. Drives the compact ◂ Track ▸ stepper.
    function stepMusicTrack(dir) {
        const count = win.musicTracks.length + 1;                 // +1 for Random
        let cur = win.musicTrack === -1 ? 0 : win.musicTrack + 1;
        cur = (cur + dir + count) % count;
        win.musicTrack = cur === 0 ? -1 : cur - 1;
    }
    readonly property string musicTrackName:
        win.musicTrack === -1 ? qsTr("Random") : win.musicTracks[win.musicTrack].name

    onMusicOnChanged: syncMusic()
    onMusicTrackChanged: restartMusic()
    onVisibilityChanged: syncMusic()
    onActiveChanged: syncMusic()
    // Any navigation re-arms the keyboard handler. Without this, a text field (e.g. the
    // leaderboard nickname editor) that grabbed focus keeps it, so the game would get no
    // arrow/space input after you leave that screen.
    onRouteChanged: keyLayer.forceActiveFocus()

    // Persisted best score + preferences.
    Settings {
        category: "HungrySnake"
        property alias best: game.best
        property alias soundOn: win.soundOn
        property alias turnSoundOn: win.turnSoundOn
        property alias musicOn: win.musicOn
        property alias musicTrack: win.musicTrack
        property alias lbNickAsked: win.lbNickAsked
    }
    Component.onCompleted: {
        keyLayer.forceActiveFocus();
        syncMusic();
        // Fetch the global board at launch so the player's rank is known everywhere
        // (the Home pill), not only after they open the Ranks screen. Only meaningful
        // once they've joined with a nickname.
        if (leaderboard.hasNickname) leaderboard.refresh();
        // Resolve today's daily challenge (constant for the session).
        var now = new Date();
        win.dailyToday = win._ymd(now);
        win.dailyYesterday = win._ymd(new Date(now.getTime() - 86400000));
        win.dailySeed = now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();
        win.dailyTarget = 8 + (win.dailySeed % 8);   // 8..15 apples
        // Dev-only: force a simulated license tier for headless testing/screenshots
        // (SN_LICSET=pro|trial|free|neterr). `debugSetTier` only exists in debug builds,
        // so the guard makes this a no-op in Release.
        if (snLicTier && LicenseController.debugSetTier)
            LicenseController.debugSetTier(snLicTier);
    }

    // ── Sound ──
    SoundEffect { id: sfxCrash; source: "qrc:/assets/sounds/crash.wav"; volume: 0.8 }
    // Apple bite — a real recording (assets/sounds/eat.wav, not generated).
    SoundEffect { id: sfxEat; source: "qrc:/assets/sounds/eat.wav"; volume: 0.85 }
    // A short pentatonic run: consecutive turns cycle these so it plays a rising
    // melody (Google-Snake style) rather than one repeated blip.
    SoundEffect { id: sfxTurn0; source: "qrc:/assets/sounds/turn0.wav"; volume: 0.6 }
    SoundEffect { id: sfxTurn1; source: "qrc:/assets/sounds/turn1.wav"; volume: 0.6 }
    SoundEffect { id: sfxTurn2; source: "qrc:/assets/sounds/turn2.wav"; volume: 0.6 }
    SoundEffect { id: sfxTurn3; source: "qrc:/assets/sounds/turn3.wav"; volume: 0.6 }
    SoundEffect { id: sfxTurn4; source: "qrc:/assets/sounds/turn4.wav"; volume: 0.6 }
    readonly property var sfxTurns: [sfxTurn0, sfxTurn1, sfxTurn2, sfxTurn3, sfxTurn4]
    property int turnNote: 0

    // ── Background music: one looping SoundEffect (stays on the light QAudioSink
    // path — no MediaPlayer/ffmpeg). The source is swapped by syncMusic(). ──
    SoundEffect {
        id: bgm
        loops: SoundEffect.Infinite
        volume: 0.7
    }

    Connections {
        target: game
        function onTurned() {                                      // arrow-press blip (cycles pitch)
            if (!win.soundOn || !win.turnSoundOn) return;          // opt-in, off by default
            win.sfxTurns[win.turnNote].play();
            win.turnNote = (win.turnNote + 1) % win.sfxTurns.length;
        }
        function onAte()  {
            if (win.soundOn) sfxEat.play();
            win.tryCompleteDaily();               // finish the daily on reaching its target
        }
        function onSpedUp(level) { achToast.show(qsTr("Speed up!"), "sparkle"); }
        function onAteBonus(kind) {
            if (win.soundOn) sfxEat.play();
            win.tryCompleteDaily();               // a star's points can finish the daily too
        }
        // Celebrate the moment this run first overtakes the previous best.
        function onScoreChanged() {
            if (!win.newBestFired && win.bestAtRunStart > 0 && game.score > win.bestAtRunStart) {
                win.newBestFired = true;
                achToast.show(qsTr("New Best!"), "trophy");
            }
        }
        function onDied() {
            if (win.soundOn) sfxCrash.play();
            win.lastRunWasBest = game.score > win.bestAtRunStart;   // for the Game Over card
            // Bank the Coins for this run's score (apples + bonus food), and record
            // the real apple count separately for the lifetime stats.
            profile.recordRun(game.score, game.apples, win.lastRunWasBest);
            win.dailyActive = false;              // a daily attempt ends on death
            achievements.check();                 // grant any newly-earned achievements
            // Post a new personal best to the global leaderboard (only if the player
            // has picked a nickname — otherwise they'll be prompted on the Ranks screen).
            if (win.lastRunWasBest && leaderboard.hasNickname && game.best >= leaderboard.minScore)
                leaderboard.submit(game.best);
        }
        function onStatusChanged() {
            if (game.status === SnakeGame.Playing) {
                win.bestAtRunStart = game.best;            // snapshot for the new-best check
                win.newBestFired = false;                  // reset the celebration for this run
                win.turnNote = 0;                          // restart the turn melody from the low note
                // On a fresh run in Random mode, reshuffle for a new tune.
                if (win.musicOn && win.musicTrack < 0)
                    win.restartMusic();
            }
        }
    }

    // ── Backdrop: the equipped background scene's 3-stop gradient (canopy → floor).
    // Cosmetics resolves the colours; a Behavior cross-fades when the scene changes.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: cosmetics.sceneTop;    Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 0.55; color: cosmetics.sceneMid;    Behavior on color { ColorAnimation { duration: 400 } } }
            GradientStop { position: 1.0;  color: cosmetics.sceneBottom; Behavior on color { ColorAnimation { duration: 400 } } }
        }
    }

    // Per-scene static scenery (sun/hills, pine treeline, mountains, coal ridge, snow
    // drifts, moon) — each scene's OWN artifacts, drawn behind the atmosphere particles
    // so snow/embers/motes drift in front of it. Jungle uses the foliage layer instead.
    SceneScape {
        anchors.fill: parent
        kind: cosmetics.sceneScape
    }

    // Scene atmosphere — ALL of it (stars/aurora AND snow/embers/motes/fireflies) sits
    // behind the foliage and the board, so it reads as a far background and never
    // distracts over the gameplay. The two planes only order the effects among
    // themselves (sky behind air); both are behind the board.
    SceneFx {
        anchors.fill: parent
        plane: "back"
        fx: cosmetics.sceneFx
    }
    SceneFx {
        anchors.fill: parent
        plane: "front"
        fx: cosmetics.sceneFx
    }

    // ── Decorative foliage framing the scene ──
    // Dark leaf silhouettes clustered around the edges — lighter/thinner up in the
    // canopy, denser and darker on the floor — each swaying gently in the breeze.
    // The scene fades them (0 for Snowfall, where snow replaces them).
    Item {
        anchors.fill: parent
        opacity: cosmetics.sceneLeaf
        visible: opacity > 0            // scenes with leaf 0 (Ember, Snowfall) skip it entirely
        Behavior on opacity { NumberAnimation { duration: 400 } }

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
            // Steering is only live on the board (not the hub / sub-screens / dialogs).
            const inGame = win.route === "game" && !win.settingsOpen && !win.pauseOpen;
            switch (e.key) {
            case Qt.Key_Up:    case Qt.Key_W: if (inGame) game.steer(SnakeGame.Up);    e.accepted = true; break;
            case Qt.Key_Down:  case Qt.Key_S: if (inGame) game.steer(SnakeGame.Down);  e.accepted = true; break;
            case Qt.Key_Left:  case Qt.Key_A: if (inGame) game.steer(SnakeGame.Left);  e.accepted = true; break;
            case Qt.Key_Right: case Qt.Key_D: if (inGame) game.steer(SnakeGame.Right); e.accepted = true; break;
            case Qt.Key_Space:
                if (win.settingsOpen) win.closeSettings();
                else if (win.pauseOpen) win.closePause();
                else if (win.route === "home") win.playGame();
                else if (win.route === "game" && game.status === SnakeGame.Playing) win.openPause();
                else if (win.route === "game" && game.status === SnakeGame.Dead) game.restart();  // Play Again
                e.accepted = true; break;
            case Qt.Key_Return: case Qt.Key_Enter:
                if (win.route === "home") win.playGame();
                else if (win.route === "game" && (game.status === SnakeGame.Dead || game.status === SnakeGame.Ready)) game.start();
                e.accepted = true; break;
            case Qt.Key_F11:
                win.toggleFullscreen(); e.accepted = true; break;
            case Qt.Key_Q:
                if (e.modifiers & Qt.ControlModifier) { win.quitApp(); e.accepted = true; }
                break;
            case Qt.Key_Escape:
                if (win.settingsOpen) win.closeSettings();
                else if (win.pauseOpen) win.closePause();
                else if (win.route === "game" && game.status === SnakeGame.Playing) win.openPause();
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
                // Climbs live once the run overtakes your record, so beating your
                // best is visible as it happens (not only on Game Over).
                StatCard { glyph: "trophy"; value: Math.max(game.best, game.score) }
                StatCard { glyph: "coin";  value: profile.coins }
            }

            IconButton {
                id: menuBtn
                anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                icon: "pause"
                bg: Theme.hudWood; bgBorder: Theme.hudEdge; borderWidth: 3; color: Theme.cream
                onClicked: win.openPause()
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
            property string badge: ""
            signal clicked
            width: 96; height: 94

            Rectangle {
                id: tileBg
                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                width: 66; height: 66; radius: Theme.r     // square, as before
                color: tileMa.pressed ? Theme.insetDeep
                     : tileMa.containsMouse ? Qt.lighter(Theme.insetTan, 1.06) : Theme.insetTan
                Behavior on color { ColorAnimation { duration: 110 } }
                border.width: 2; border.color: Theme.insetEdge
                // Slight lift on hover (a visual Translate, so the anchored layout is
                // undisturbed); settles back down + darkens on press.
                property real lift: (tileMa.containsMouse && !tileMa.pressed) ? -3 : 0
                Behavior on lift { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                transform: Translate { y: tileBg.lift }

                Icon { anchors.centerIn: parent; name: tile.icon; color: Theme.inkStrong; size: 30 }
                Badge {                                      // e.g. the Daily "!" flag
                    visible: tile.badge !== ""
                    text: tile.badge
                    anchors { right: parent.right; rightMargin: -6; top: parent.top; topMargin: -6 }
                }
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

        // Top bar: a Best-score pill (left) + a Coins pill (right), both on wood.
        Rectangle {
            id: bestPill
            anchors { top: parent.top; left: parent.left; topMargin: 22; leftMargin: 30 }
            height: 40; radius: height / 2
            width: bestRow.implicitWidth + 34
            color: Theme.hudWood; border.width: 3; border.color: Theme.hudEdge
            Row {
                id: bestRow
                anchors.centerIn: parent; spacing: 8
                Rectangle { width: 10; height: 10; radius: 5; color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter }
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: qsTr("Best · ") + game.best
                       color: Theme.cream; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.DemiBold }
            }
        }
        // Persistent global-rank pill — shown once the player holds a ranked best, so
        // their standing is visible on the hub, not just inside the Ranks screen. Tap
        // to open the full leaderboard.
        Rectangle {
            id: rankPill
            visible: leaderboard.playerRank > 0
            anchors { top: bestPill.bottom; left: parent.left; topMargin: 10; leftMargin: 30 }
            height: 40; radius: height / 2
            width: rankRow.implicitWidth + 32
            color: rankMa.containsMouse ? Qt.lighter(Theme.hudWood, 1.12) : Theme.hudWood
            Behavior on color { ColorAnimation { duration: 120 } }
            border.width: 3; border.color: Theme.hudEdge
            Row {
                id: rankRow
                anchors.centerIn: parent; spacing: 7
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "ranks"; size: 20; color: Theme.gold }
                Text { anchors.verticalCenter: parent.verticalCenter
                       text: (leaderboard.usingMock ? qsTr("Demo #") : qsTr("Rank #")) + leaderboard.playerRank
                       color: Theme.cream; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.DemiBold }
            }
            MouseArea {
                id: rankMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor; onClicked: win.navigate("leaderboard")
            }
        }
        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 22; rightMargin: 30 }
            height: 40; radius: height / 2
            width: coinPill.implicitWidth + 30
            color: Theme.hudWood; border.width: 3; border.color: Theme.hudEdge
            CoinBalance {
                id: coinPill
                anchors.centerIn: parent
                value: profile.coins; iconSize: 24; ink: Theme.cream
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 22

            // Mascot — the Goof head, matching the app icon, gently bobbing above the
            // title as the hero of the lockup.
            MascotHead {
                id: mascot
                anchors.horizontalCenter: parent.horizontalCenter
                size: 128
                property real bob: 0
                transform: Translate { y: mascot.bob }
                SequentialAnimation on bob {
                    running: homeScreen.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: -12; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0;   duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            // Title with an extruded drop shadow — a duplicate Text offset straight down
            // in the title's own darker green (not a MultiEffect, which wouldn't grab
            // headless). The Item sizes to the text so the Column layout is unchanged.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: title.implicitWidth
                implicitHeight: title.implicitHeight
                Text {                                   // extruded shadow, straight down
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 6
                    text: title.text
                    color: "#2e7d43"                     // the title's own darker green
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
                // A cheeky little apple perched on the corner, tilted for life. Fixed
                // classic red (not the equipped skin) so the logo stays brand-stable.
                AppleArt {
                    id: logoApple
                    d: 46
                    shadow: false
                    transformOrigin: Item.Center
                    x: title.width * 1.04          // sitting just past the final "E"
                    y: title.height * 0.12         // perched up top so the "E" stays visible
                    // Lively idle motion: a wide tilt swing + a hop on an offset period,
                    // so it never repeats and clearly reads as alive.
                    property real rot: 12
                    property real hop: 0
                    rotation: rot
                    transform: Translate { y: logoApple.hop }
                    SequentialAnimation on rot {
                        loops: Animation.Infinite
                        NumberAnimation { to: -8; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 22; duration: 900; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on hop {
                        loops: Animation.Infinite
                        NumberAnimation { to: -9; duration: 680; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0;  duration: 680; easing.type: Easing.InOutSine }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Eat apples • grow • don't bite yourself")
                color: Theme.text; font.family: Theme.ui; font.pixelSize: 16
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 9
                PillButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Play"); icon: "play"; fontSize: 27; onClicked: win.playGame()
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("or press Space")
                    color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 13
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12
                HomeTile { icon: "store";    label: qsTr("Store");    onClicked: win.navigate("store") }
                HomeTile { icon: "calendar"; label: qsTr("Daily");    onClicked: win.navigate("daily")
                           badge: win.dailyDone ? "" : "!" }
                HomeTile { icon: "medal";    label: qsTr("Awards");   onClicked: win.navigate("achievements") }
                HomeTile { icon: "ranks";    label: qsTr("Ranks");    onClicked: win.navigate("leaderboard") }
                HomeTile { icon: "gear";     label: qsTr("Settings"); onClicked: win.openSettings() }
                HomeTile { icon: "heart";    label: qsTr("Support");  onClicked: win.navigate("about") }
                HomeTile { icon: "power";    label: qsTr("Quit");     onClicked: win.quitApp() }
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
            // Not-enough-coins → Supporter upsell prompt.
            property bool   coinPromptOpen: false
            property string coinPromptName: ""
            property int    coinPromptPrice: 0

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
                    model: [qsTr("Snake"), qsTr("Board"), qsTr("Apple"), qsTr("Bonus"), qsTr("Scene")]
                    currentIndex: store.catIndex
                    onActivated: store.catIndex = index
                }

                Flow {
                    // Exactly four 150px cards + three 16px gaps = 648, so the centered
                    // Flow centres the grid instead of leaving dead space on the right.
                    width: Math.min(win.width - 96, 648)
                    spacing: 16
                    Repeater {
                        model: cosmetics.storeOrder(store.catSlot)
                        delegate: StoreCard {
                            readonly property string eqId:
                                (profile.equipped[store.catSlot] && profile.equipped[store.catSlot] !== "")
                                    ? profile.equipped[store.catSlot]
                                    : cosmetics.catalogue(store.catSlot)[0].id
                            name: modelData.name
                            price: modelData.price
                            locked: modelData.supporter === true && !win.isSupporter
                            owned: modelData.supporter === true
                                   ? win.isSupporter
                                   : (modelData.price === 0 || profile.owned.indexOf(modelData.id) >= 0)
                            equipped: eqId === modelData.id
                            affordable: profile.coins >= modelData.price
                            onBuy: {
                                if (profile.buy(modelData.id, modelData.price))
                                    profile.equip(store.catSlot, modelData.id);
                            }
                            onEquip: profile.equip(store.catSlot, modelData.id)
                            onUnlock: win.navigate("about")   // go redeem Supporter
                            onNeedCoins: {                    // can't afford → propose Supporter
                                store.coinPromptName = modelData.name;
                                store.coinPromptPrice = modelData.price;
                                store.coinPromptOpen = true;
                            }
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
                                    Rectangle {                       // scene: a mini gradient sky
                                        id: sceneSwatch
                                        visible: store.catSlot === "scene"
                                        anchors.centerIn: parent
                                        width: parent.width * 0.84; height: parent.height * 0.8
                                        radius: 8; clip: true
                                        readonly property string fx: sw.def.fx || "none"
                                        gradient: Gradient {
                                            GradientStop { position: 0.0;  color: sw.def.top    || "#00000000" }
                                            GradientStop { position: 0.55; color: sw.def.mid    || "#00000000" }
                                            GradientStop { position: 1.0;  color: sw.def.bottom || "#00000000" }
                                        }

                                        // Live atmosphere: the real SceneFx effects rendered at 3× and
                                        // scaled down, so a full-screen field reads correctly in a
                                        // thumbnail without re-tuning any particle sizes. Density is
                                        // thinned to match on-screen sparsity; both planes are stacked
                                        // (sky behind, air in front) exactly as in game. Runs only while
                                        // the Scene tab is actually showing.
                                        Item {
                                            id: fxHost
                                            anchors.centerIn: parent
                                            width: sceneSwatch.width * 3
                                            height: sceneSwatch.height * 3
                                            scale: 1 / 3
                                            readonly property bool live: win.route === "store" && store.catSlot === "scene"
                                            SceneFx {
                                                anchors.fill: parent; plane: "back"
                                                fx: sceneSwatch.fx; density: 0.3; active: fxHost.live
                                            }
                                            SceneFx {
                                                anchors.fill: parent; plane: "front"
                                                fx: sceneSwatch.fx; density: 0.3; active: fxHost.live
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── Not-enough-coins → Supporter upsell ──
            Rectangle {
                anchors.fill: parent
                visible: opacity > 0
                opacity: store.coinPromptOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                color: Qt.rgba(0, 0, 0, 0.55)
                MouseArea { anchors.fill: parent; onClicked: store.coinPromptOpen = false }

                Rectangle {
                    anchors.centerIn: parent
                    width: 360; radius: Theme.rlg
                    color: Theme.cardTan; border.width: 3; border.color: Theme.cardEdge
                    implicitHeight: cpCol.implicitHeight + 40
                    transformOrigin: Item.Center
                    scale: store.coinPromptOpen ? 1 : 0.9
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    MouseArea { anchors.fill: parent }   // absorb clicks so the card doesn't dismiss

                    Column {
                        id: cpCol
                        anchors.centerIn: parent; width: parent.width - 40; spacing: 14
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "coin"; size: 46 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Not enough coins")
                            color: Theme.inkStrong; font.family: Theme.ui; font.pixelSize: 22; font.weight: Font.Bold
                        }
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            text: qsTr("%1 costs %2 coins — you have %3.")
                                  .arg(store.coinPromptName).arg(store.coinPromptPrice).arg(profile.coins)
                            color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 14
                        }
                        Text {
                            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                            text: qsTr("Become a Supporter to get an 800-coin bundle and every exclusive cosmetic.")
                            color: Theme.inkStrong; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.DemiBold
                        }
                        PillButton {
                            width: parent.width
                            text: qsTr("Become a Supporter"); fontSize: 17
                            onClicked: { store.coinPromptOpen = false; win.navigate("about"); }
                        }
                        PillButton {
                            width: parent.width
                            text: qsTr("Maybe later"); raised: false
                            fill: Theme.insetTan; ink: Theme.inkStrong
                            onClicked: store.coinPromptOpen = false
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
        // ── Global leaderboard ──
        Item {
            id: lbScr
            anchors.fill: parent
            visible: opacity > 0
            opacity: win.route === "leaderboard" ? 1 : 0
            enabled: win.route === "leaderboard"
            Behavior on opacity { NumberAnimation { duration: 200 } }
            property bool editingNick: false

            // Load the board (and sync the player's best) whenever this screen opens.
            Connections {
                target: win
                function onRouteChanged() {
                    if (win.route !== "leaderboard") return;
                    lbScr.editingNick = false;
                    if (leaderboard.hasNickname && game.best > 0) leaderboard.submit(game.best);
                    else leaderboard.refresh();
                }
            }

            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55) }
            ScreenHeader {
                id: lhdr
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 22 }
                title: qsTr("Leaderboard"); onBack: win.back()
            }

            Item {
                anchors { top: lhdr.bottom; topMargin: 20; bottom: parent.bottom; bottomMargin: 22
                          horizontalCenter: parent.horizontalCenter }
                width: Math.min(win.width - 80, 560)

                // — Nickname gate — shown until the player picks a name (or is editing it) —
                Column {
                    id: nickGate
                    readonly property bool editing: leaderboard.hasNickname   // already joined ⇒ editing
                    function commit() {
                        if (nickField.text.trim().length === 0) return;
                        leaderboard.setNickname(nickField.text);
                        lbScr.editingNick = false;
                        keyLayer.forceActiveFocus();
                    }
                    visible: !leaderboard.hasNickname || lbScr.editingNick
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: 16
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "trophy"; size: 52; color: Theme.title }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: nickGate.editing ? qsTr("Change your leaderboard name")
                                               : qsTr("Pick a nickname to join\nthe global leaderboard")
                        color: Theme.text; font.family: Theme.ui; font.pixelSize: 18; font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        TextField {
                            id: nickField
                            width: 240; height: 48
                            leftPadding: 14; rightPadding: 14
                            verticalAlignment: Text.AlignVCenter
                            placeholderText: qsTr("Your name")
                            maximumLength: 16
                            color: Theme.inkStrong
                            placeholderTextColor: Theme.inkSoft     // readable on the tan field
                            font.family: Theme.ui; font.pixelSize: 16; font.weight: Font.DemiBold
                            background: Rectangle {
                                radius: Theme.rsm; color: Theme.insetTan
                                border.width: 2
                                border.color: nickField.activeFocus ? Theme.primary : Theme.insetEdge
                            }
                            onAccepted: nickGate.commit()
                        }
                        PillButton {
                            text: nickGate.editing ? qsTr("Save") : qsTr("Join")
                            enabled: nickField.text.trim().length > 0
                            onClicked: nickGate.commit()
                        }
                    }
                    // Cancel — only when editing an existing name (a first-time player
                    // has nothing to go back to).
                    Text {
                        visible: nickGate.editing
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Cancel"); color: Theme.textDim
                        font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.DemiBold
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { lbScr.editingNick = false; keyLayer.forceActiveFocus() } }
                    }
                }

                // — The ranked board —
                Item {
                    id: boardWrap
                    visible: leaderboard.hasNickname && !lbScr.editingNick
                    anchors.fill: parent

                    // Summary strip: your rank/best (left), a Change-name button + a
                    // Refresh button whose icon spins while a load is in flight (right).
                    Item {
                        id: lbSummary
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 40

                        component ChipButton: Rectangle {
                            id: chip
                            property alias label: chipText.text
                            property string glyph: ""
                            signal tapped
                            implicitWidth: chipRow.implicitWidth + 24
                            implicitHeight: 36
                            radius: height / 2
                            color: chipMa.pressed ? Theme.insetDeep
                                 : chipMa.containsMouse ? Qt.lighter(Theme.insetTan, 1.06) : Theme.insetTan
                            border.width: 2; border.color: Theme.insetEdge
                            Row {
                                id: chipRow
                                anchors.centerIn: parent; spacing: 6
                                Icon { visible: chip.glyph !== ""; name: chip.glyph; size: 17
                                       color: Theme.inkStrong; anchors.verticalCenter: parent.verticalCenter }
                                Text { id: chipText; color: Theme.inkStrong; font.family: Theme.ui
                                       font.pixelSize: 13; font.weight: Font.Bold
                                       anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: chipMa; anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor; onClicked: chip.tapped() }
                        }

                        Text {
                            anchors { left: parent.left; right: lbActions.left; rightMargin: 12
                                      verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: (leaderboard.usingMock ? qsTr("Demo · ") : "")
                                  + (leaderboard.playerRank > 0
                                     ? qsTr("You're #%1 · best %2").arg(leaderboard.playerRank).arg(leaderboard.playerBest)
                                     : qsTr("Play a game to join the board!"))
                            color: Theme.text; font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.Bold
                        }
                        Row {
                            id: lbActions
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            ChipButton {
                                label: qsTr("Change name"); glyph: "edit"
                                onTapped: { nickField.text = leaderboard.nickname; lbScr.editingNick = true; nickField.forceActiveFocus() }
                            }
                            // Refresh — the icon spins while loading, so a tap has visible effect.
                            Rectangle {
                                width: 36; height: 36; radius: height / 2
                                color: refreshMa.pressed ? Theme.insetDeep
                                     : refreshMa.containsMouse ? Qt.lighter(Theme.insetTan, 1.06) : Theme.insetTan
                                border.width: 2; border.color: Theme.insetEdge
                                Icon {
                                    id: refreshIcon
                                    anchors.centerIn: parent; name: "restart"; size: 20; color: Theme.inkStrong
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                        running: leaderboard.status === Leaderboard.Loading
                                        onRunningChanged: if (!running) refreshIcon.rotation = 0
                                    }
                                }
                                MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: leaderboard.status !== Leaderboard.Loading
                                            onClicked: leaderboard.refresh() }
                            }
                        }
                    }

                    ListView {
                        id: lbList
                        anchors { top: lbSummary.bottom; topMargin: 16; left: parent.left
                                  right: parent.right; bottom: parent.bottom }
                        clip: true
                        spacing: 8
                        model: leaderboard.entries
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool self: modelData.self === true
                            readonly property int rank: modelData.rank
                            width: ListView.view.width; height: 46; radius: Theme.rsm
                            color: self ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.24)
                                        : Theme.insetTan
                            border.width: self ? 2 : 1
                            border.color: self ? Theme.primary : Theme.insetEdge

                            Rectangle {                              // rank badge
                                id: rankBadge
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                width: 30; height: 30; radius: 15
                                color: rank === 1 ? "#e0b23f" : rank === 2 ? "#c2ccd8"
                                     : rank === 3 ? "#cf9160" : Theme.hudWood
                                Text {
                                    anchors.centerIn: parent; text: rank
                                    color: rank <= 3 ? "#3a2a06" : Theme.cream
                                    font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Bold
                                }
                            }
                            Text {                                   // name
                                anchors { left: rankBadge.right; leftMargin: 12; right: scoreText.left; rightMargin: 10
                                          verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight
                                text: modelData.name + (self ? qsTr(" (you)") : "")
                                // The self row sits on a dark-green highlight, so its text
                                // flips to cream — dark ink would be unreadable there.
                                color: self ? Theme.cream : Theme.inkStrong
                                font.family: Theme.ui; font.pixelSize: 16; font.weight: self ? Font.Bold : Font.DemiBold
                            }
                            Text {                                   // score
                                id: scoreText
                                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                text: modelData.score
                                color: self ? Theme.cream : Theme.inkStrong
                                font.family: Theme.display; font.pixelSize: 18
                            }
                        }
                    }

                    Text {                                           // loading / error states
                        anchors.centerIn: parent
                        visible: leaderboard.entries.length === 0
                        text: leaderboard.status === Leaderboard.Error
                              ? qsTr("Couldn't load scores.\nTap ↻ to retry.")
                              : qsTr("Loading scores…")
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textDim; font.family: Theme.ui; font.pixelSize: 15
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

                        // ── Reusable, obviously-interactive bits (no hidden text-clicks) ──
                        // A clear secondary button (bordered tan pill) with an optional spinner.
                        component ActionChip: Rectangle {
                            id: chip
                            property alias label: chipLbl.text
                            property string glyph: ""
                            property bool busy: false
                            signal tapped
                            implicitWidth: chipRow.implicitWidth + 30
                            implicitHeight: 40
                            radius: height / 2
                            color: chipMa.pressed ? Theme.insetDeep
                                 : chipMa.containsMouse ? Qt.lighter(Theme.insetTan, 1.06) : Theme.insetTan
                            border.width: 2; border.color: Theme.insetEdge
                            Row {
                                id: chipRow; anchors.centerIn: parent; spacing: 6
                                Icon {
                                    visible: chip.glyph !== ""; name: chip.glyph; size: 16
                                    color: Theme.inkStrong; anchors.verticalCenter: parent.verticalCenter
                                    RotationAnimation on rotation {
                                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                        running: chip.busy; onRunningChanged: if (!running) rotation = 0
                                    }
                                }
                                Text {
                                    id: chipLbl; color: Theme.inkStrong; font.family: Theme.ui
                                    font.pixelSize: 14; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                id: chipMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: chip.tapped()
                            }
                        }

                        // A caption + the Supporter ID in a selectable field + a real Copy button.
                        component IdCopyBlock: Column {
                            property string caption: ""
                            width: parent ? parent.width : 320
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                text: caption
                                color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 12; font.weight: Font.DemiBold
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Rectangle {
                                    width: idField.implicitWidth + 24; height: 36; radius: Theme.rsm
                                    color: Theme.insetTan; border.width: 2; border.color: Theme.insetEdge
                                    TextInput {
                                        id: idField; anchors.centerIn: parent
                                        text: LicenseController.accountId
                                        readOnly: true; selectByMouse: true
                                        color: Theme.inkStrong; font.family: Theme.ui
                                        font.pixelSize: 13; font.weight: Font.DemiBold
                                    }
                                }
                                Rectangle {
                                    width: cpLbl.implicitWidth + 28; height: 36; radius: Theme.rsm
                                    color: cpMa.pressed ? Theme.primaryDeep
                                         : cpMa.containsMouse ? Qt.lighter(Theme.primary, 1.05) : Theme.primary
                                    Text { id: cpLbl; anchors.centerIn: parent; text: qsTr("Copy")
                                           color: Theme.inkStrong; font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.Bold }
                                    MouseArea {
                                        id: cpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { idField.selectAll(); idField.copy();
                                                     achToast.show(qsTr("Supporter ID copied"), "check"); }
                                    }
                                }
                            }
                        }

                        Column {                                   // not yet a supporter
                            id: buyCol
                            visible: !win.isSupporter
                            width: parent.width; spacing: 12
                            property bool restoreTried: false

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
                                onClicked: win.becomeSupporter()      // opens the KTechpit checkout
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Already bought it?")
                                color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                            }
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                                ActionChip {
                                    glyph: "restart"; busy: LicenseController.checking
                                    label: LicenseController.checking ? qsTr("Checking…") : qsTr("Restore")
                                    onTapped: { buyCol.restoreTried = true; LicenseController.refresh(); }
                                }
                                ActionChip { label: qsTr("Open portal"); onTapped: LicenseController.openPortal() }
                            }
                            Text {
                                visible: buyCol.restoreTried && !win.isSupporter && !LicenseController.checking
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                                text: qsTr("No purchase found for this Supporter ID yet.")
                                color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 12
                            }

                            IdCopyBlock {
                                caption: qsTr("Your Supporter ID — paste this on the portal to restore or migrate")
                            }
                        }

                        Column {                                   // already a supporter
                            visible: win.isSupporter
                            width: parent.width; spacing: 10
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter; spacing: 8
                                Icon { name: "heart"; color: Theme.successInk; size: 26; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: qsTr("You're a Supporter — thank you!"); color: Theme.successInk; font.family: Theme.ui
                                       font.pixelSize: 18; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Your exclusive cosmetics are waiting in the Store.")
                                color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 14
                            }
                            IdCopyBlock {
                                caption: qsTr("Your Supporter ID — copy it to migrate to another device")
                            }
                            ActionChip {
                                anchors.horizontalCenter: parent.horizontalCenter
                                label: qsTr("Open portal"); onTapped: LicenseController.openPortal()
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
        // Leaving Dead (Play Again / Home) must cancel any pending reveal, otherwise the
        // delayed timer fires on the now-live game and the card gets stuck open with no
        // way to dismiss it (restart() no-ops once status is already Playing).
        onDeadChanged: { if (dead) overDelay.restart(); else { overDelay.stop(); active = false; } }
        onActiveChanged: if (active) coinCount.restart()
        Timer { id: overDelay; interval: 430; onTriggered: overlay.active = overlay.dead }
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

                // Record-breaking celebration: a gold banner that pops in when the run
                // set a new best. It sparkles + scale-bounces to feel like an event.
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: win.lastRunWasBest
                    implicitWidth: nbPill.width; implicitHeight: nbPill.height
                    Rectangle {
                        id: nbPill
                        anchors.centerIn: parent
                        width: nbRow.implicitWidth + 34; height: 40; radius: height / 2
                        color: Theme.gold; border.width: 3; border.color: Qt.darker(Theme.gold, 1.35)
                        Row {
                            id: nbRow
                            anchors.centerIn: parent; spacing: 8
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "trophy"; size: 24 }
                            Text { anchors.verticalCenter: parent.verticalCenter
                                   text: qsTr("NEW BEST!"); color: "#5a3a06"
                                   font.family: Theme.display; font.pixelSize: 20; font.weight: Font.Bold }
                        }
                        // Pop in with a bounce whenever the card reveals a record.
                        scale: overlay.active && win.lastRunWasBest ? 1 : 0.4
                        opacity: overlay.active && win.lastRunWasBest ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 260 } }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    component ScoreChip: Rectangle {
                        property string glyph: ""
                        property string caption: ""
                        property int value: 0
                        width: 132; height: 74; radius: Theme.r
                        color: Theme.insetTan          // inset panel — stat block in a dialog
                        Row {
                            anchors.centerIn: parent; spacing: 10
                            Icon { name: glyph; size: 32; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: value; color: Theme.inkStrong; font.family: Theme.ui
                                       font.pixelSize: 30; font.weight: Font.Bold }
                                Text { text: caption; color: Theme.inkStrong; font.family: Theme.ui
                                       font.pixelSize: 12; font.weight: Font.DemiBold }
                            }
                        }
                    }
                    ScoreChip { glyph: "apple";  caption: qsTr("Score"); value: game.score }
                    ScoreChip { glyph: "trophy"; caption: qsTr("Best");  value: game.best }
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

                // First-best nudge: offer to post to the global leaderboard, but only
                // when this run set a record AND the player has no nickname yet AND
                // hasn't declined before. Once they have a name, new bests auto-submit
                // silently (see onDied), so this never shows again.
                Column {
                    id: nickPrompt
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: overCol.width
                    spacing: 10
                    visible: win.lastRunWasBest && !leaderboard.hasNickname && !win.lbNickAsked
                             && game.best >= leaderboard.minScore

                    function postScore() {
                        if (overNick.text.trim().length === 0) return;
                        leaderboard.setNickname(overNick.text);   // persists + refreshes
                        leaderboard.submit(game.best);            // post the record (toasts the rank on completion)
                        win.lbNickAsked = true;
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Post your best to the global leaderboard!")
                        color: Theme.inkStrong; font.family: Theme.ui
                        font.pixelSize: 16; font.weight: Font.DemiBold
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        TextField {
                            id: overNick
                            width: 200; height: 46
                            leftPadding: 14; rightPadding: 14
                            verticalAlignment: Text.AlignVCenter
                            placeholderText: qsTr("Your name")
                            maximumLength: 16
                            color: Theme.inkStrong; placeholderTextColor: Theme.textDim
                            font.family: Theme.ui; font.pixelSize: 16; font.weight: Font.DemiBold
                            background: Rectangle {
                                radius: Theme.rsm; color: Theme.insetTan
                                border.width: 2
                                border.color: overNick.activeFocus ? Theme.primary : Theme.insetEdge
                            }
                            onAccepted: nickPrompt.postScore()
                        }
                        PillButton {
                            text: qsTr("Post"); fontSize: 16
                            enabled: overNick.text.trim().length > 0
                            onClicked: nickPrompt.postScore()
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Not now")
                        color: Theme.title; font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: win.lbNickAsked = true }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    // One clear primary action (Play Again = a fresh run) + Home. The old
                    // card had "Continue" and a restart icon that did the same thing.
                    PillButton { icon: "play"; text: qsTr("Play Again"); fontSize: 18; onClicked: game.restart() }
                    IconButton { icon: "home"; onClicked: win.goHome() }
                }
            }
        }
    }

    // Shared dialog shadow.
    component DialogShadow: MultiEffect {
        shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1.0
        shadowOpacity: 0.5; shadowVerticalOffset: 16; autoPaddingEnabled: true
    }

    // ── Pause menu (in-game quick actions) ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0
        opacity: win.pauseOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: win.closePause() }

        Rectangle {
            anchors.centerIn: parent
            width: 320; radius: Theme.rlg
            color: Theme.cardTan; border.width: 3; border.color: Theme.cardEdge
            implicitHeight: pcol.implicitHeight + 44
            transformOrigin: Item.Center
            scale: win.pauseOpen ? 1.0 : 0.9
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: DialogShadow {}
            MouseArea { anchors.fill: parent }

            Column {
                id: pcol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 12

                Item {
                    width: parent.width; height: 38
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Paused"); color: Theme.inkStrong; font.family: Theme.ui
                        font.pixelSize: 24; font.weight: Font.Bold
                    }
                    IconButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        icon: "close"; iconSize: 18; implicitWidth: 40; implicitHeight: 40
                        onClicked: win.closePause()
                    }
                }

                PillButton {
                    width: parent.width; icon: "play"; text: qsTr("Resume"); fontSize: 18
                    onClicked: win.closePause()
                }
                Row {
                    width: parent.width; spacing: 10
                    PillButton {
                        width: (parent.width - parent.spacing) / 2
                        icon: "restart"; text: qsTr("Restart"); raised: false
                        fill: Theme.insetTan; ink: Theme.inkStrong; weight: Font.DemiBold
                        onClicked: { game.restart(); win.closePause(); }
                    }
                    PillButton {
                        width: (parent.width - parent.spacing) / 2
                        icon: "home"; text: qsTr("Home"); raised: false
                        fill: Theme.insetTan; ink: Theme.inkStrong; weight: Font.DemiBold
                        onClicked: win.goHome()
                    }
                }
                PillButton {
                    width: parent.width; icon: "gear"; text: qsTr("Settings"); raised: false
                    fill: Theme.insetTan; ink: Theme.inkStrong; weight: Font.DemiBold
                    onClicked: win.openSettings()
                }

                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; topPadding: 2
                    text: qsTr("Space or Esc to resume")
                    color: Theme.inkSoft; font.pixelSize: 13
                }
            }
        }
    }

    // ── Settings (audio + music) — a SEPARATE dialog, opened from the Home tile or the
    // Pause menu's Settings button. Declared after Pause so it layers on top of it. ──
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0
        opacity: win.settingsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: win.closeSettings() }

        Rectangle {
            anchors.centerIn: parent
            width: 360; radius: Theme.rlg
            color: Theme.cardTan; border.width: 3; border.color: Theme.cardEdge
            implicitHeight: scol.implicitHeight + 44
            transformOrigin: Item.Center
            scale: win.settingsOpen ? 1.0 : 0.9
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: DialogShadow {}
            MouseArea { anchors.fill: parent }

            Column {
                id: scol
                anchors.centerIn: parent
                width: parent.width - 44
                spacing: 8

                Item {
                    width: parent.width; height: 38
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Settings"); color: Theme.inkStrong; font.family: Theme.ui
                        font.pixelSize: 24; font.weight: Font.Bold
                    }
                    IconButton {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        icon: "close"; iconSize: 18; implicitWidth: 40; implicitHeight: 40
                        onClicked: win.closeSettings()
                    }
                }

                ToggleRow { label: qsTr("Sound"); checked: win.soundOn; onToggled: win.soundOn = !win.soundOn }
                ToggleRow { label: qsTr("Turn sound"); checked: win.turnSoundOn; onToggled: win.turnSoundOn = !win.turnSoundOn }
                ToggleRow { label: qsTr("Music"); checked: win.musicOn; onToggled: win.musicOn = !win.musicOn }

                Text {
                    width: parent.width; topPadding: 6
                    text: qsTr("Music track"); color: Theme.inkSoft
                    font.family: Theme.ui; font.pixelSize: 13; font.weight: Font.DemiBold
                    opacity: win.musicOn ? 1.0 : 0.4
                }
                // Track selector: Random + one chip per track.
                Item {
                    width: parent.width
                    implicitHeight: trackFlow.implicitHeight
                    opacity: win.musicOn ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Flow {
                        id: trackFlow
                        width: parent.width; spacing: 8
                        Repeater {
                            model: [{ label: qsTr("Random"), idx: -1 }].concat(
                                       win.musicTracks.map(function (t, i) { return { label: t.name, idx: i }; }))
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: win.musicTrack === modelData.idx
                                height: 34; width: chipLabel.implicitWidth + 30; radius: height / 2
                                color: sel ? Theme.primary : Theme.insetTan
                                border.width: 2; border.color: sel ? Theme.primaryDeep : Theme.insetEdge
                                Behavior on color { ColorAnimation { duration: 140 } }
                                Text {
                                    id: chipLabel; anchors.centerIn: parent; text: modelData.label
                                    color: Theme.inkStrong; font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent; enabled: win.musicOn
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.musicTrack = modelData.idx
                                }
                            }
                        }
                    }
                }

                Item { width: 1; height: 6 }
                PillButton { width: parent.width; text: qsTr("Done"); fontSize: 17; onClicked: win.closeSettings() }
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
        // Only ACTIVE during real play. A full-screen hoverEnabled MouseArea swallows
        // hover from every button beneath it (clicks still pass via Qt.NoButton, which
        // is why press worked but hover didn't) — so it must be inert on menus/dialogs.
        // It's also the only place the cursor should auto-hide anyway.
        enabled: win.route === "game" && game.status === SnakeGame.Playing
                 && !win.settingsOpen && !win.pauseOpen
        hoverEnabled: enabled
        propagateComposedEvents: true
        property bool hidden: false
        cursorShape: hidden ? Qt.BlankCursor : Qt.ArrowCursor
        onPositionChanged: { hidden = false; hideTimer.restart(); }
        onEntered: hideTimer.restart()
        onExited: hideTimer.stop()
        onEnabledChanged: { hidden = false; if (enabled) hideTimer.restart(); else hideTimer.stop(); }
        Timer { id: hideTimer; interval: 2500; running: cursorHider.enabled; onTriggered: cursorHider.hidden = true }
    }


    // Transient notification (achievement unlocked / daily complete) — topmost.
    Toast {
        id: achToast
        anchors.horizontalCenter: parent.horizontalCenter
        y: 22
    }
}
