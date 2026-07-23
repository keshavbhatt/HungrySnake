#include "AppInfo.h"
#include "SnakeGame.h"

#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QTimer>
#include <QtMath>
#include <cmath>

// Dev-only apple-seeking AI: steer toward the apple along the dominant axis, but
// never pick a reversal into the neck (pick the other axis instead). Good enough
// to demo growth + turns headlessly.
static void seekPoint(SnakeGame *g, qreal tx, qreal ty)
{
    const qreal dx = tx - g->headX();
    const qreal dy = ty - g->headY();
    const qreal hx = std::cos(g->heading()), hy = std::sin(g->heading());
    const bool horiz = std::abs(hx) > std::abs(hy);

    SnakeGame::Direction pref, alt;
    if (std::abs(dx) > std::abs(dy)) {
        pref = dx > 0 ? SnakeGame::Right : SnakeGame::Left;
        alt  = dy > 0 ? SnakeGame::Down  : SnakeGame::Up;
    } else {
        pref = dy > 0 ? SnakeGame::Down  : SnakeGame::Up;
        alt  = dx > 0 ? SnakeGame::Right : SnakeGame::Left;
    }
    auto isReverse = [&](SnakeGame::Direction d) {
        return horiz ? ((hx > 0 && d == SnakeGame::Left) || (hx < 0 && d == SnakeGame::Right))
                     : ((hy > 0 && d == SnakeGame::Up)   || (hy < 0 && d == SnakeGame::Down));
    };
    g->steer(isReverse(pref) ? alt : pref);
}

// Chase the apple, or the bonus food while one is on the board.
static void seekApple(SnakeGame *g) { seekPoint(g, g->appleX(), g->appleY()); }
static void seekFood(SnakeGame *g)
{
    if (g->bonusActive()) seekPoint(g, g->bonusX(), g->bonusY());
    else                  seekPoint(g, g->appleX(), g->appleY());
}

int main(int argc, char *argv[])
{
    // Scene-wide multisample antialiasing so rotated/clipped art (the turning
    // head, snout cap, seam) renders with smooth edges instead of jagged pixels.
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setSamples(4);
    QSurfaceFormat::setDefaultFormat(fmt);

    QGuiApplication app(argc, argv);

    // Identity — set before any QSettings-derived storage is touched.
    QGuiApplication::setOrganizationName(QStringLiteral(SN_ORG_NAME));
    QGuiApplication::setApplicationName(QStringLiteral(SN_APP_NAME));
    QGuiApplication::setApplicationVersion(QStringLiteral(SN_VERSION));
    QGuiApplication::setDesktopFileName(QStringLiteral(SN_APP_ID));
    QGuiApplication::setWindowIcon(
        QIcon(QStringLiteral(":/assets/icons/" SN_APP_ID ".svg")));

    // Basic (non-native) Quick Controls style: full control over theming so the
    // game looks identical across platforms.
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Bundled typefaces (see Theme.qml `ui` / `display`):
    //  • Fredoka  — the body/UI face, also set as the default application font so
    //               every QML Text renders in it out of the box.
    //  • Titan One — the chunky display face for titles, headers, HUD numbers and
    //               buttons. Registered here so QML can ask for it by family name.
    QFontDatabase::addApplicationFont(QStringLiteral(":/assets/fonts/TitanOne.ttf"));
    if (int id = QFontDatabase::addApplicationFont(
            QStringLiteral(":/assets/fonts/Fredoka.ttf"));
        id != -1) {
        const QStringList fams = QFontDatabase::applicationFontFamilies(id);
        if (!fams.isEmpty()) {
            QFont f(fams.first());
            f.setStyleStrategy(QFont::PreferAntialias);
            QGuiApplication::setFont(f);
        }
    }

    QQmlApplicationEngine engine;

    // Expose whether this is a debug build to QML (unlocks dev-only helpers).
#ifdef SN_DEBUG
    engine.rootContext()->setContextProperty("appDebug", true);
#else
    engine.rootContext()->setContextProperty("appDebug", false);
#endif

    // Dev-only license simulation: SN_LICSET=pro|trial|free|neterr forces the
    // LicenseController's tier for headless testing/screenshots (see Main.qml's
    // Component.onCompleted). The debug setter only exists in debug builds, so this
    // is inert in Release even if the env var is set.
    engine.rootContext()->setContextProperty(
        "snLicTier", QString::fromUtf8(qgetenv("SN_LICSET")));

    // Dev builds shout about QML errors. Without this they are swallowed: a bad
    // binding just yields a blank/failed load with no clue why (this has bitten us
    // twice — a duplicate id, and a nested layer.effect rendering nothing).
#ifdef SN_DEBUG
    QObject::connect(&engine, &QQmlEngine::warnings, &app,
        [](const QList<QQmlError> &ws) {
            for (const QQmlError &e : ws)
                fprintf(stderr, "QML: %s\n", qPrintable(e.toString()));
        });
#endif
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);

    // Dev-only: SN_SHOT=<path> renders once, saves a PNG, and quits — headless
    // visual verification. Inert unless set. SN_MODE selects what to capture:
    //   (default) seek apples so the shot shows a grown snake mid-play
    //   "ready"   grab the opening Ready overlay (don't start)
    //   "die"     steer straight into a wall, then grab the Game Over overlay
    const QByteArray shot = qgetenv("SN_SHOT");
    if (!shot.isEmpty()) {
        const QByteArray mode = qgetenv("SN_MODE");
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [shot, mode, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                // Dev-only: SN_SIZE=WxH resizes the window first (resize testing).
                const QByteArray sz = qgetenv("SN_SIZE");
                if (!sz.isEmpty()) {
                    const auto parts = QString::fromUtf8(sz).split('x');
                    if (parts.size() == 2) { w->setWidth(parts[0].toInt()); w->setHeight(parts[1].toInt()); }
                }
                // Dev-only: SN_SCREEN=<home|game|store|daily|achievements|about>
                // jumps the router straight to a screen for screenshot verification.
                const QByteArray scr = qgetenv("SN_SCREEN");
                if (!scr.isEmpty())
                    w->setProperty("route", QString::fromUtf8(scr));
                // The gameplay screenshot modes live on the board, so put the router
                // there (the app otherwise launches to the "home" hub).
                else if (mode == "waiting" || mode == "eat" || mode == "die"
                      || mode == "mouth" || mode == "long" || mode == "settings"
                      || mode == "bonus" || mode == "bonuseat" || mode == "over")
                    w->setProperty("route", "game");
                auto *game = w->findChild<SnakeGame *>();
                int grabDelay = 2200;
                if (game && mode == "ready") {
                    grabDelay = 600;                 // just show the Ready overlay
                } else if (game && mode == "waiting") {
                    game->start();                   // primed, awaiting first steer (static)
                    grabDelay = 700;
                } else if (game && mode == "settings") {
                    game->start();
                    game->pause(true);               // paused pause-menu state
                    w->setProperty("settingsOpen", true);
                    grabDelay = 700;
                } else if (game && mode == "eat") {
                    // Autoplay toward the apple; grab shortly after the first bite
                    // to catch the crush splat + the new apple popping in.
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekApple(game); });
                    t->start();
                    QObject::connect(game, &SnakeGame::ate, &app, [w, shot, &app, t]() {
                        static bool once = false;
                        if (once) return;
                        once = true;
                        t->stop();
                        const int d = qEnvironmentVariableIntValue("SN_DELAY");
                        QTimer::singleShot(d > 0 ? d : 130, [w, shot, &app] {
                            w->grabWindow().save(QString::fromUtf8(shot));
                            app.quit();
                        });
                    }, Qt::QueuedConnection);
                    grabDelay = 60000;   // fallback only; the ate() handler grabs first
                } else if (game && mode == "long") {
                    // Grow a long, turning snake (autoplay eats), then grab so the
                    // body's corners can be inspected.
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekApple(game); });
                    t->start();
                    const int longEats = qEnvironmentVariableIntValue("SN_LONG_EATS") > 0
                                       ? qEnvironmentVariableIntValue("SN_LONG_EATS") : 6;
                    const int longDelay = qEnvironmentVariableIntValue("SN_LONG_DELAY") > 0
                                        ? qEnvironmentVariableIntValue("SN_LONG_DELAY") : 40;
                    auto *eaten = new int(0);
                    QObject::connect(game, &SnakeGame::ate, &app,
                        [w, shot, &app, eaten, longEats, longDelay]() {
                        if (++(*eaten) >= longEats) {
                            static bool once = false;
                            if (once) return;
                            once = true;
                            QTimer::singleShot(longDelay, [w, shot, &app] {
                                w->grabWindow().save(QString::fromUtf8(shot));
                                app.quit();
                            });
                        }
                    });
                    grabDelay = 14000;
                } else if (game && mode == "mouth") {
                    // Autoplay toward the apple; grab while the head is ~1 cell away
                    // (mouth open) but before the bite, to show the open maw.
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekApple(game); });
                    t->start();
                    auto *poll = new QTimer(&app);
                    poll->setInterval(16);
                    QObject::connect(poll, &QTimer::timeout, &app, [w, shot, &app, game, poll]() {
                        const double dx = game->appleX() - game->headX();
                        const double dy = game->appleY() - game->headY();
                        const double d = std::sqrt(dx * dx + dy * dy);
                        if (d < 1.1 && d > 0.55) {           // mouth open, not yet eaten
                            poll->stop();
                            w->grabWindow().save(QString::fromUtf8(shot));
                            app.quit();
                        }
                    });
                    poll->start();
                    grabDelay = 9000;   // fallback if the window is never hit
                } else if (game && mode == "bonus") {
                    // Autoplay chasing food; grab the instant a bonus is on the board.
                    // The dev AI often crashes before the 5 apples a bonus needs, so keep
                    // restarting until one shows up.
                    game->start();
                    QObject::connect(game, &SnakeGame::died, &app,
                                     [game]() { QTimer::singleShot(60, game, [game]{ game->start(); }); });
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekFood(game); });
                    t->start();
                    auto *poll = new QTimer(&app);
                    poll->setInterval(16);
                    QObject::connect(poll, &QTimer::timeout, &app, [w, shot, &app, poll, game]() {
                        if (game->bonusActive() && game->bonusLife() < 0.92) {
                            poll->stop();
                            w->grabWindow().save(QString::fromUtf8(shot));
                            app.quit();
                        }
                    });
                    poll->start();
                    grabDelay = 25000;
                } else if (game && mode == "bonuseat") {
                    // Autoplay chasing bonus food across several runs — used to verify the
                    // score/apples split end-to-end via the profile.
                    game->start();
                    QObject::connect(game, &SnakeGame::died, &app,
                                     [game]() { QTimer::singleShot(60, game, [game]{ game->start(); }); });
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekFood(game); });
                    t->start();
                    grabDelay = 40000;
                } else if (game && mode == "over") {
                    // Autoplay until the snake dies, then grab the Game Over card (past
                    // its ~430ms reveal). Used to check the death / new-best celebration.
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekApple(game); });
                    t->start();
                    QObject::connect(game, &SnakeGame::died, &app, [w, shot, &app, t]() {
                        static bool once = false;
                        if (once) return;
                        once = true;
                        t->stop();
                        QTimer::singleShot(700, [w, shot, &app] {
                            w->grabWindow().save(QString::fromUtf8(shot));
                            app.quit();
                        });
                    }, Qt::QueuedConnection);
                    grabDelay = 30000;
                } else if (game && mode == "die") {
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() {
                        game->steer(SnakeGame::Up);   // straight up, into the top wall
                    });
                    t->start();
                    grabDelay = 2600;                // long enough to crash
                } else if (game && scr.isEmpty()) {
                    // Default: autoplay toward apples. Skipped when SN_SCREEN targets a
                    // non-game screen, so menu/store/about grabs don't run a hidden game.
                    game->start();
                    auto *t = new QTimer(&app);
                    t->setInterval(16);
                    QObject::connect(t, &QTimer::timeout, &app, [game]() { seekApple(game); });
                    t->start();
                }
                // Dev-only: SN_DELAY=<ms> overrides when the grab fires (e.g. to
                // catch a mid-animation frame like the death shake/burst).
                const QByteArray delayEnv = qgetenv("SN_DELAY");
                if (!delayEnv.isEmpty() && mode != "eat")   // "eat" grabs off the ate() signal
                    grabDelay = delayEnv.toInt();
                QTimer::singleShot(grabDelay, [w, shot, &app] {
                    w->grabWindow().save(QString::fromUtf8(shot));
                    app.quit();
                });
            }, Qt::QueuedConnection);
    }

    // Dev-only: SN_AUTOPLAY=<dir> auto-steers the snake toward the apple and saves
    // a numbered filmstrip of PNG frames — headless gameplay verification. Inert
    // unless set.
    const QByteArray autoDir = qgetenv("SN_AUTOPLAY");
    if (!autoDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [autoDir, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *game = w->findChild<SnakeGame *>();
                if (!game) { app.quit(); return; }
                game->start();

                int *frame = new int(0);
                auto grab = [w, autoDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(autoDir)
                        + QString("/f%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };

                // Simple "seek the apple" AI drives the real steer() path.
                auto *ai = new QTimer(&app);
                ai->setInterval(16);
                QObject::connect(ai, &QTimer::timeout, &app, [game]() { seekApple(game); });
                ai->start();

                // Grab a frame every ~120ms for ~4s, then quit.
                auto *shots = new QTimer(&app);
                shots->setInterval(120);
                QObject::connect(shots, &QTimer::timeout, &app, [grab]() { grab(); });
                shots->start();
                QTimer::singleShot(4200, &app, [&app] { app.quit(); });
            }, Qt::QueuedConnection);
    }

    // Dev-only: SN_EDGE=<dir> drives the snake to the right edge then down along
    // it, saving a burst of frames — to verify the head hugs the side wall without
    // clipping or gliding through it. Inert unless set.
    const QByteArray edgeDir = qgetenv("SN_EDGE");
    if (!edgeDir.isEmpty()) {
        QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
            [edgeDir, &app](QObject *obj, const QUrl &) {
                auto *w = qobject_cast<QQuickWindow *>(obj);
                if (!w) return;
                auto *game = w->findChild<SnakeGame *>();
                if (!game) { app.quit(); return; }
                game->steer(SnakeGame::Right);   // auto-starts and heads right
                int *frame = new int(0);
                bool *turned = new bool(false);
                auto grab = [w, edgeDir, frame]() {
                    w->grabWindow().save(QString::fromUtf8(edgeDir)
                        + QString("/e%1.png").arg(*frame, 3, 10, QChar('0')));
                    ++(*frame);
                };
                // Poll the head; turn down once it nears the right wall, so we
                // reliably capture the head hugging the edge regardless of speed.
                auto *poll = new QTimer(&app);
                poll->setInterval(45);
                QObject::connect(poll, &QTimer::timeout, &app, [game, turned, grab]() {
                    if (!*turned && game->headX() > game->cols() - 1.4) {
                        game->steer(SnakeGame::Down);
                        *turned = true;
                    }
                    grab();
                });
                poll->start();
                QTimer::singleShot(3200, &app, [poll, &app] { poll->stop(); app.quit(); });
            }, Qt::QueuedConnection);
    }

    engine.loadFromModule("HungrySnake", "Main");

    return app.exec();
}
