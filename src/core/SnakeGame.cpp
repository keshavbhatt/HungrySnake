#include "SnakeGame.h"

#include <QtMath>
#include <algorithm>
#include <cmath>

namespace {
// Direction vectors, indexed by SnakeGame::Direction (Up,Right,Down,Left).
constexpr int kDCol[4] = { 0,  1, 0, -1 };
constexpr int kDRow[4] = { -1, 0, 1,  0 };
int opposite(int d) { return (d + 2) % 4; }

// Feel — all geometry is in "cells" (world units).
constexpr int   kStartLen    = 4;      // body length (cells) at score 0
constexpr qreal kBaseSpeed   = 6.5;    // cells / second at score 0
constexpr qreal kAccel       = 0.18;   // extra cells/s per apple
constexpr qreal kMaxSpeed    = 12.0;
constexpr qreal kBodyWidth   = 0.75;   // neck width; body tapers to a point at the tail
constexpr qreal kHeadSize    = 1.22;
constexpr qreal kAppleRadius = 0.42;
constexpr qreal kRenderStep  = 0.28;   // spacing of resampled render points (smaller = smoother)
constexpr int   kStepMs      = 16;     // ~60 Hz clock
constexpr qreal kDtMax       = 0.05;   // clamp long stalls (window drag, etc.)
constexpr qreal kImpact      = 0.34;   // how far the head nudges into a wall/body on death

qreal dist(const QPointF &a, const QPointF &b)
{
    const qreal dx = a.x() - b.x(), dy = a.y() - b.y();
    return std::sqrt(dx * dx + dy * dy);
}
} // namespace

SnakeGame::SnakeGame(QObject *parent)
    : QObject(parent), m_rng(QRandomGenerator::securelySeeded())
{
    m_timer.setInterval(kStepMs);
    connect(&m_timer, &QTimer::timeout, this, &SnakeGame::step);
    resetSnake();
    spawnApple();
    retarget();
}

qreal SnakeGame::bodyWidth() const   { return kBodyWidth; }
qreal SnakeGame::headSize() const    { return kHeadSize; }
qreal SnakeGame::appleRadius() const { return kAppleRadius; }

void SnakeGame::setBest(int b)
{
    if (b == m_best)
        return;
    m_best = b;
    emit bestChanged();
}

void SnakeGame::setStatus(Status s)
{
    if (s == m_status)
        return;
    m_status = s;
    emit statusChanged();
}

void SnakeGame::resetSnake()
{
    const int cx = m_cols / 2, cy = m_rows / 2;
    m_cells.clear();
    for (int i = 0; i < kStartLen; ++i)
        m_cells.push_back(QPoint(cx - i, cy));   // head at front, body to the left

    m_dir = Right;
    m_turns.clear();
    m_progress = 0;
    m_score = 0;

    updateHead();
    rebuildBody();
    emit scoreChanged();
    emit advanced();
}

void SnakeGame::spawnApple()
{
    // Keep apples off the outermost ring so eating never forces wall-hugging.
    const int x0 = (m_cols > 4) ? 1 : 0, x1 = (m_cols > 4) ? m_cols - 1 : m_cols;
    const int y0 = (m_rows > 4) ? 1 : 0, y1 = (m_rows > 4) ? m_rows - 1 : m_rows;
    const int total = m_cols * m_rows;
    for (int attempt = 0; attempt < total * 4; ++attempt) {
        const QPoint c(x0 + m_rng.bounded(x1 - x0), y0 + m_rng.bounded(y1 - y0));
        if (std::find(m_cells.begin(), m_cells.end(), c) == m_cells.end()) {
            m_apple = c;
            emit appleChanged();
            return;
        }
    }
    // Board essentially full — drop the apple on the first empty cell, if any.
    for (int y = 0; y < m_rows; ++y)
        for (int x = 0; x < m_cols; ++x) {
            const QPoint c(x, y);
            if (std::find(m_cells.begin(), m_cells.end(), c) == m_cells.end()) {
                m_apple = c;
                emit appleChanged();
                return;
            }
        }
}

void SnakeGame::start()
{
    resetSnake();
    spawnApple();
    retarget();
    setStatus(Playing);
    // Primed but not moving: the snake stays put until the first steer, so the
    // player is never thrown into motion (and a wall/self clash) before they're
    // ready. The clock/timer start on that first input.
    m_awaiting = true;
    emit waitingChanged();
}

void SnakeGame::startSeeded(quint32 seed)
{
    // Reseed so the apple sequence is identical for everyone playing this seed
    // (the daily challenge); the run itself then plays exactly like a normal one.
    m_rng = QRandomGenerator(seed);
    start();
}

void SnakeGame::pause(bool p)
{
    if (p) {
        m_timer.stop();
    } else if (m_status == Playing && !m_awaiting) {
        m_clock.restart();
        m_timer.start();
    }
}

void SnakeGame::steer(Direction dir)
{
    if (m_status == Ready)
        start();
    if (m_status != Playing)
        return;

    // The first steer sets the snake in motion — apply the direction immediately
    // (not buffered) so the very first move goes where the player pressed.
    if (m_awaiting) {
        m_awaiting = false;
        emit waitingChanged();
        if (dir != opposite(m_dir)) {
            m_dir = dir;
            retarget();
        }
        m_clock.restart();
        m_timer.start();
        return;
    }

    // Buffer up to two turns so quick successive taps aren't dropped; ignore a
    // no-op (same as the last queued direction) or a reversal into the neck.
    const int ref = m_turns.empty() ? m_dir : m_turns.back();
    if (dir == ref || dir == opposite(ref))
        return;
    if (m_turns.size() < 2)
        m_turns.push_back(dir);
}

void SnakeGame::step()
{
    qreal dt = m_clock.restart() / 1000.0;
    if (dt <= 0)
        return;
    dt = std::min(dt, kDtMax);

    const qreal speed = std::min(kBaseSpeed + m_score * kAccel, kMaxSpeed);
    m_progress += speed * dt;

    // Enter each safe cell as the head reaches it. Crucially, the cell ahead
    // (m_next) was already vetted by retarget(), so we never glide into a wall or
    // body: if the next cell is lethal we stop the head *at* it (a small impact
    // nudge) instead of sliding through, then end the run.
    while (m_progress >= 1.0 && !m_nextLethal) {
        m_progress -= 1.0;
        arrive();
    }

    if (m_nextLethal) {
        m_progress = std::min(m_progress, kImpact);   // head presses into the wall/body
        updateHead();
        rebuildBody();
        emit advanced();
        if (m_progress >= kImpact)
            die();
        return;
    }

    updateHead();
    rebuildBody();
    emit advanced();
}

void SnakeGame::arrive()
{
    // m_next was pre-verified safe by retarget(); enter it.
    const bool eating = (m_next == m_apple);
    m_cells.push_front(m_next);
    if (eating) {
        ++m_score;
        emit scoreChanged();
        emit ate();
        spawnApple();          // body keeps its tail this step → grows by one cell
    } else {
        m_cells.pop_back();
    }

    // Apply the next buffered turn (never a direct reversal), then look ahead.
    if (!m_turns.empty()) {
        const int d = m_turns.front();
        m_turns.pop_front();
        if (d != opposite(m_dir))
            m_dir = d;
    }
    retarget();
}

bool SnakeGame::stepIsLethal(const QPoint &next) const
{
    // Walls are lethal (classic Snake).
    if (next.x() < 0 || next.x() >= m_cols || next.y() < 0 || next.y() >= m_rows)
        return true;
    // Body: the tail cell vacates as we advance (unless we're about to eat), so
    // moving into the current tail is legal.
    const bool eating = (next == m_apple);
    const int checkCount = static_cast<int>(m_cells.size()) - (eating ? 0 : 1);
    for (int i = 0; i < checkCount; ++i)
        if (m_cells[i] == next)
            return true;
    return false;
}

void SnakeGame::retarget()
{
    m_next = m_cells.front() + QPoint(kDCol[m_dir], kDRow[m_dir]);
    m_nextLethal = stepIsLethal(m_next);
}

void SnakeGame::updateHead()
{
    const QPoint h = m_cells.front();
    m_head = center(h) + QPointF(kDCol[m_dir] * m_progress, kDRow[m_dir] * m_progress);
    m_heading = std::atan2(kDRow[m_dir], kDCol[m_dir]);
}

void SnakeGame::rebuildBody()
{
    const int n = static_cast<int>(m_cells.size());
    if (n == 0) {
        m_body = QVariantList();
        return;
    }

    // ── Build the smooth "spine": head point (m_head) → cell centres → tail. ──
    // m_head leads the front cell by `progress` while playing, or sits at the
    // impact point when dead, so the rendered body always ends exactly at the head.
    QVector<QPointF> spine;
    spine.reserve(n + 2);
    spine.push_back(m_head);
    for (int i = 0; i <= n - 2; ++i)
        spine.push_back(center(m_cells[i]));
    if (n >= 2) {
        const QPointF a = center(m_cells[n - 1]);   // tail
        const QPointF b = center(m_cells[n - 2]);
        spine.push_back(a + (b - a) * m_progress);  // retracts toward the neck
    }

    // ── Resample into evenly spaced render points (head → tail). ──
    QVariantList pts;
    pts.reserve(static_cast<int>(spine.size() / kRenderStep) + 4);
    pts.push_back(QVariant::fromValue(spine.first()));
    qreal acc = 0, next = kRenderStep;
    for (int i = 1; i < spine.size(); ++i) {
        const QPointF a = spine[i - 1], b = spine[i];
        const qreal seg = dist(a, b);
        if (seg <= 1e-9)
            continue;
        while (acc + seg >= next) {
            const qreal t = (next - acc) / seg;
            pts.push_back(QVariant::fromValue(QPointF(a.x() + (b.x() - a.x()) * t,
                                                      a.y() + (b.y() - a.y()) * t)));
            next += kRenderStep;
        }
        acc += seg;
    }
    const QPointF tail = spine.last();
    if (pts.isEmpty() || dist(pts.last().toPointF(), tail) > 1e-4)
        pts.push_back(QVariant::fromValue(tail));

    m_body = pts;
}

void SnakeGame::die()
{
    m_timer.stop();
    if (m_score > m_best) {
        m_best = m_score;
        emit bestChanged();
    }
    setStatus(Dead);
    emit died();
}
