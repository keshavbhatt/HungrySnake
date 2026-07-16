import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Effects
import QtCore
import QtMultimedia
import Snecko
import "components"

ApplicationWindow {
    id: win
    visible: true
    width: 960
    height: 640
    minimumWidth: 720
    minimumHeight: 480
    title: "Snecko"
    color: Theme.bg

    SnakeGame { id: game }
    Profile   { id: profile }   // persistent Berries currency + lifetime stats

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
        category: "Snecko"
        property alias best: game.best
        property alias soundOn: win.soundOn
        property alias musicOn: win.musicOn
        property alias musicTrack: win.musicTrack
    }
    Component.onCompleted: { keyLayer.forceActiveFocus(); syncMusic(); }

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
        function onAte()  { if (win.soundOn) sfxEat.play(); }
        function onDied() {
            if (win.soundOn) sfxCrash.play();
            // Bank the Berries earned this run (apples + a new-best bonus).
            profile.recordRun(game.score, game.score > win.bestAtRunStart);
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
            // Ignore steering while the pause menu is open.
            switch (e.key) {
            case Qt.Key_Up:    case Qt.Key_W: if (!win.settingsOpen) game.steer(SnakeGame.Up);    e.accepted = true; break;
            case Qt.Key_Down:  case Qt.Key_S: if (!win.settingsOpen) game.steer(SnakeGame.Down);  e.accepted = true; break;
            case Qt.Key_Left:  case Qt.Key_A: if (!win.settingsOpen) game.steer(SnakeGame.Left);  e.accepted = true; break;
            case Qt.Key_Right: case Qt.Key_D: if (!win.settingsOpen) game.steer(SnakeGame.Right); e.accepted = true; break;
            case Qt.Key_Space:
                if (win.settingsOpen) win.closeSettings();
                else if (game.status === SnakeGame.Playing) win.openSettings();
                else game.start();
                e.accepted = true; break;
            case Qt.Key_Return: case Qt.Key_Enter:
                if (game.status === SnakeGame.Dead || game.status === SnakeGame.Ready) game.start();
                e.accepted = true; break;
            case Qt.Key_Escape:
                if (win.settingsOpen) win.closeSettings();
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

            Row {
                anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                spacing: 12

                StatCard { glyph: "apple";  value: game.score }
                StatCard { glyph: "trophy"; value: game.best }
                StatCard { glyph: "berry";  value: profile.berries }
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
            anchors { top: topBar.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
                      topMargin: 6; leftMargin: 62; rightMargin: 62; bottomMargin: 44 }
        }

        // "Primed — press a key" hint: shown while the run is set up but not yet
        // moving (it starts on the first steer, so you can't be caught out).
        Text {
            anchors.horizontalCenter: boardView.horizontalCenter
            y: boardView.y + boardView.height * 0.72
            visible: game.waiting
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

    // ── Ready overlay (kit tan dialog card over a 45% scrim) ──
    Rectangle {
        anchors.fill: parent
        readonly property bool active: game.status === SnakeGame.Ready
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: opacity > 0
        opacity: active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        MouseArea { anchors.fill: parent; onClicked: game.start() }

        Rectangle {
            anchors.centerIn: parent
            width: readyCol.implicitWidth + 88
            height: readyCol.implicitHeight + 64
            radius: Theme.rlg
            color: Theme.cardTan
            border.width: 3
            border.color: Theme.cardEdge
            transformOrigin: Item.Center
            scale: parent.active ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1.0
                shadowOpacity: 0.5; shadowVerticalOffset: 16; autoPaddingEnabled: true
            }

            Column {
                id: readyCol
                anchors.centerIn: parent
                spacing: 18
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: "SNECKO"; color: Theme.primaryDeep
                       font.family: Theme.ui; font.pixelSize: 56; font.weight: Font.Bold }
                // Separator is a drawn dot, not a "·" glyph — never depends on a font.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: qsTr("Eat apples"); color: Theme.inkSoft; font.pixelSize: 15 }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter
                                width: 4; height: 4; radius: 2; color: Theme.inkSoft }
                    Text { anchors.verticalCenter: parent.verticalCenter
                           text: qsTr("avoid the walls and yourself"); color: Theme.inkSoft; font.pixelSize: 15 }
                }
                PillButton { anchors.horizontalCenter: parent.horizontalCenter
                             text: qsTr("Play"); fontSize: 19; onClicked: game.start() }
                Text { anchors.horizontalCenter: parent.horizontalCenter
                       text: qsTr("Steer with the arrow keys or WASD")
                       color: Qt.rgba(Theme.inkStrong.r, Theme.inkStrong.g, Theme.inkStrong.b, 0.55)
                       font.pixelSize: 13 }
            }
        }
    }

    // ── Game Over overlay ──
    Rectangle {
        id: overlay
        anchors.fill: parent
        readonly property bool dead: game.status === SnakeGame.Dead
        // Hold the overlay back briefly on death so the board shake + head-burst
        // play on the clear field first, then fade the Game Over card in.
        property bool active: false
        // Berries-earned count-up shown on the card (animates 0 → what this run earned).
        property int shownBerries: 0
        onDeadChanged: { if (dead) overDelay.restart(); else active = false; }
        onActiveChanged: if (active) berryCount.restart()
        Timer { id: overDelay; interval: 430; onTriggered: overlay.active = true }
        NumberAnimation {
            id: berryCount; target: overlay; property: "shownBerries"
            from: 0; to: profile.lastRunBerries; duration: 650; easing.type: Easing.OutCubic
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

                // Berries earned this run (hidden on a fruitless run).
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: profile.lastRunBerries > 0
                    Item {
                        width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "berry"; size: 28 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + overlay.shownBerries
                        color: Theme.berryDeep; font.family: Theme.ui
                        font.pixelSize: 26; font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("berries earned")
                        color: Theme.inkSoft; font.family: Theme.ui; font.pixelSize: 17
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    PillButton { text: qsTr("Continue"); fontSize: 18; onClicked: game.restart() }
                    IconButton { icon: "restart"; onClicked: game.restart() }
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
                    text: qsTr("Restart")
                    raised: false
                    fill: Theme.insetTan
                    ink: Theme.inkStrong
                    weight: Font.DemiBold
                    onClicked: { game.restart(); win.closeSettings(); }
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
}
