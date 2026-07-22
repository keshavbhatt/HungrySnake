#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QPoint>
#include <QPointF>
#include <QRandomGenerator>
#include <QTimer>
#include <QVariantList>
#include <deque>
#include <QtQmlIntegration/qqmlintegration.h>

// SnakeGame — grid-locked Snake with smooth visuals.
//
// The logic is classic: the snake lives on a `cols`×`rows` grid as a chain of
// cells, moves one cell per tick in one of four directions, and turns only on
// cell boundaries (a 180° reversal into itself is ignored). Eating an apple
// grows the chain by one cell; hitting a wall or its own body ends the run.
//
// The *rendering* is smooth: a `progress` fraction [0,1) tracks how far the head
// has travelled toward its next cell, and `body` is a resampled polyline that
// leads the head forward and retracts the tail by that fraction — so the snake
// glides between cells instead of snapping.
//
// World units are "cells"; QML maps one cell to a pixel size, so the sim is
// resolution-independent. Cell centres are (col+0.5, row+0.5).
class SnakeGame : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int cols        READ cols        CONSTANT)
    Q_PROPERTY(int rows        READ rows        CONSTANT)
    Q_PROPERTY(qreal headX     READ headX       NOTIFY advanced)
    Q_PROPERTY(qreal headY     READ headY       NOTIFY advanced)
    Q_PROPERTY(qreal heading   READ heading     NOTIFY advanced)   // radians
    Q_PROPERTY(qreal appleX    READ appleX      NOTIFY appleChanged)
    Q_PROPERTY(qreal appleY    READ appleY      NOTIFY appleChanged)
    Q_PROPERTY(QVariantList body READ body      NOTIFY advanced)   // world-unit points, head→tail
    Q_PROPERTY(qreal bodyWidth READ bodyWidth   CONSTANT)
    Q_PROPERTY(qreal headSize  READ headSize    CONSTANT)
    Q_PROPERTY(qreal appleRadius READ appleRadius CONSTANT)
    Q_PROPERTY(int score       READ score       NOTIFY scoreChanged)
    // Apples actually eaten this run. Kept apart from `score` because bonus foods add
    // points too — lifetime "apples" stats must not count a star as 5 apples.
    Q_PROPERTY(int apples      READ apples      NOTIFY scoreChanged)
    // ── Bonus food: a timed extra that spawns every few apples ──
    Q_PROPERTY(qreal bonusX    READ bonusX      NOTIFY bonusChanged)
    Q_PROPERTY(qreal bonusY    READ bonusY      NOTIFY bonusChanged)
    Q_PROPERTY(bool bonusActive READ bonusActive NOTIFY bonusChanged)
    Q_PROPERTY(int  bonusKind  READ bonusKind   NOTIFY bonusChanged)   // Food enum
    Q_PROPERTY(qreal bonusLife READ bonusLife   NOTIFY advanced)       // 1 → 0 as it expires
    Q_PROPERTY(int best        READ best        WRITE setBest NOTIFY bestChanged)
    Q_PROPERTY(Status status   READ status      NOTIFY statusChanged)
    Q_PROPERTY(bool waiting    READ waiting     NOTIFY waitingChanged)  // primed, awaiting first steer

public:
    enum Direction { Up = 0, Right = 1, Down = 2, Left = 3 };
    Q_ENUM(Direction)

    enum Status { Ready, Playing, Dead };
    Q_ENUM(Status)

    // Bonus food kinds. The staple apple is always on the board and is skinnable via
    // cosmetics; these are timed extras drawn as distinct SHAPES (star / leaf) so no
    // apple skin can ever be mistaken for one.
    //   Golden — worth kGoldenScore points, grows you by one like an apple.
    //   Mint   — shrinks the snake (an escape hatch when you're long and boxed in).
    enum Food { Golden = 0, Mint = 1 };
    Q_ENUM(Food)

    explicit SnakeGame(QObject *parent = nullptr);

    int   cols() const { return m_cols; }
    int   rows() const { return m_rows; }
    qreal headX() const { return m_head.x(); }
    qreal headY() const { return m_head.y(); }
    qreal heading() const { return m_heading; }
    qreal appleX() const { return m_apple.x() + 0.5; }
    qreal appleY() const { return m_apple.y() + 0.5; }
    QVariantList body() const { return m_body; }
    qreal bodyWidth() const;
    qreal headSize() const;
    qreal appleRadius() const;
    int   score() const { return m_score; }
    int   apples() const { return m_apples; }
    qreal bonusX() const { return m_bonus.x() + 0.5; }
    qreal bonusY() const { return m_bonus.y() + 0.5; }
    bool  bonusActive() const { return m_bonusActive; }
    int   bonusKind() const { return m_bonusKind; }
    qreal bonusLife() const;
    int   best() const { return m_best; }
    void  setBest(int b);
    Status status() const { return m_status; }
    bool  waiting() const { return m_awaiting; }

    // ── Actions driven from QML / dev hooks ──
    Q_INVOKABLE void start();               // (re)start a fresh run
    Q_INVOKABLE void restart() { start(); }
    Q_INVOKABLE void startSeeded(quint32 seed);   // deterministic apples (daily challenge)
    Q_INVOKABLE void pause(bool p);         // pause/resume the clock
    Q_INVOKABLE void steer(Direction dir);  // queue a turn (applied on the next cell)

signals:
    void advanced();          // one simulation frame elapsed (drives QML repaint)
    void appleChanged();
    void scoreChanged();
    void bestChanged();
    void statusChanged();
    void waitingChanged();
    void ate();               // apple eaten this frame
    void bonusChanged();      // bonus food spawned / eaten / expired
    void ateBonus(int kind);  // a bonus food was eaten this frame (Food enum)
    void died();              // the run just ended
    void turned();            // a steer input was accepted (drives the turn blip)
    void spedUp(int level);   // the speed just stepped up (level = 1,2,3…) — announce it

private:
    void step();              // advance the render clock; enter whole cells as they pass
    void arrive();            // the head has reached m_next: enter it, turn, retarget
    void retarget();          // recompute the cell ahead (m_next) and whether it's lethal
    bool stepIsLethal(const QPoint &next) const;  // would entering `next` end the run?
    void resetSnake();        // place a short snake at the centre, facing right
    void spawnApple();        // put the apple on a random empty cell
    void maybeSpawnBonus();   // every kBonusEvery apples, drop a timed bonus food
    bool cellFree(const QPoint &c) const;   // not snake, not apple, not bonus
    void rebuildBody();       // build the smooth head→tail render polyline
    void updateHead();        // head visual position + heading from cell + progress
    void die();
    void setStatus(Status s);

    static QPointF center(const QPoint &c) { return QPointF(c.x() + 0.5, c.y() + 0.5); }

    QTimer        m_timer;
    QElapsedTimer m_clock;

    int    m_cols = 19;
    int    m_rows = 13;

    std::deque<QPoint> m_cells;   // front = head cell, back = tail cell
    int    m_dir = Right;         // current travel direction
    std::deque<int> m_turns;      // buffered turns (≤2), one applied per cell
    bool   m_awaiting = false;    // primed but not moving until the first steer
    QPoint m_next;                // the cell the head is gliding toward
    bool   m_nextLethal = false;  // is m_next a wall / body? (checked before entering)
    qreal  m_progress = 0;        // [0,1) fraction from head cell toward the next

    QPointF m_head;               // head visual position (world units)
    qreal  m_heading = 0;         // head facing, radians
    QPoint m_apple;
    QVariantList m_body;

    int    m_score = 0;
    int    m_apples = 0;          // apples only (score also counts bonus points)
    QPoint m_bonus;
    bool   m_bonusActive = false;
    int    m_bonusKind = Golden;
    qreal  m_bonusTime = 0;       // seconds of life left
    int    m_applesSinceBonus = 0;
    int    m_best = 0;
    Status m_status = Ready;

    QRandomGenerator m_rng;
};
