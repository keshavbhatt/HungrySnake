#include "Leaderboard.h"

#include "LeaderboardConfig.h"   // SN_SUPABASE_URL / SN_SUPABASE_ANON_KEY (baked in by CMake)

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

#include <algorithm>

namespace {
// The seeded demo board used in mock mode — fixed so it looks the same every run.
struct Seed { const char *name; int score; };
constexpr Seed kMockSeed[] = {
    {"CobraKai", 142}, {"NoodleFang", 128}, {"SirHiss", 119}, {"Mambo", 104},
    {"PixelPython", 97}, {"GreenGoblin", 88}, {"TailChaser", 79}, {"Slytherin", 71},
    {"AppleJack", 64}, {"Wiggles", 58}, {"DangerNoodle", 49}, {"Kaa", 41},
    {"Ssssam", 33}, {"LilViper", 26}, {"Sprout", 18},
};
constexpr int kNickMax = 16;
} // namespace

Leaderboard::Leaderboard(QObject *parent) : QObject(parent)
{
    // Config precedence: environment (dev override), then QSettings (dev override),
    // then the value baked in at build time (what ships to players).
    m_baseUrl = qEnvironmentVariable("SUPABASE_URL");
    m_anonKey = qEnvironmentVariable("SUPABASE_ANON_KEY");

    QSettings s;
    s.beginGroup("leaderboard");
    if (m_baseUrl.isEmpty()) m_baseUrl = s.value("url").toString();
    if (m_anonKey.isEmpty()) m_anonKey = s.value("anonKey").toString();
    if (m_baseUrl.isEmpty()) m_baseUrl = QStringLiteral(SN_SUPABASE_URL);
    if (m_anonKey.isEmpty()) m_anonKey = QStringLiteral(SN_SUPABASE_ANON_KEY);
    m_nickname = s.value("nickname").toString();
    m_playerId = s.value("playerId").toString();
    m_myBest   = s.value("myBest", 0).toInt();
    if (m_playerId.isEmpty()) {
        m_playerId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        s.setValue("playerId", m_playerId);
    }
    s.endGroup();

    // No backend configured ⇒ mock mode (seeded demo board, works offline).
    m_mock = m_baseUrl.isEmpty() || m_anonKey.isEmpty();
}

void Leaderboard::save()
{
    QSettings s;
    s.beginGroup("leaderboard");
    s.setValue("nickname", m_nickname);
    s.setValue("playerId", m_playerId);
    s.setValue("myBest", m_myBest);
    s.endGroup();
}

void Leaderboard::setStatus(Status st, const QString &err)
{
    if (m_status == st && m_error == err)
        return;
    m_status = st;
    m_error = err;
    emit statusChanged();
}

void Leaderboard::setNickname(const QString &name)
{
    QString n = name.trimmed();
    n.truncate(kNickMax);
    if (n == m_nickname)
        return;
    m_nickname = n;
    save();
    emit nicknameChanged();
    // Renaming updates the player's EXISTING record (identity is the player_uuid, not
    // the name). If they've already posted a qualifying score, upsert to rename that
    // row — the keep_max_score trigger preserves the score. Otherwise just refresh.
    if (m_mock)
        mockRefresh();
    else if (m_myBest >= MinScore)
        netSubmit(m_myBest);
    else
        netRefresh();
}

void Leaderboard::refresh()
{
    if (m_mock) mockRefresh();
    else        netRefresh();
}

void Leaderboard::submit(int score)
{
    // Below the qualifying minimum, treat it as a non-improvement: no write, no
    // callout — but still fall through to a refresh so the board stays current.
    const bool improved = (score > m_myBest) && (score >= MinScore);
    if (improved) {
        m_myBest = score;
        save();
    }
    // Only a real improvement earns the "you reached #N" callout when the refresh lands.
    m_pendingSubmit = improved;
    if (m_mock) {
        mockRefresh();
    } else {
        if (improved) netSubmit(score);   // only write real improvements
        else          netRefresh();
    }
}

// ── Mock backend ────────────────────────────────────────────────────────────
void Leaderboard::rebuildMock()
{
    struct Row { QString name; int score; bool self; };
    QList<Row> rows;
    for (const auto &e : kMockSeed)
        rows.push_back({ QString::fromLatin1(e.name), e.score, false });
    if (hasNickname() && m_myBest > 0)
        rows.push_back({ m_nickname, m_myBest, true });

    std::stable_sort(rows.begin(), rows.end(),
                     [](const Row &a, const Row &b) { return a.score > b.score; });

    m_entries.clear();
    m_playerRank = -1;
    for (int i = 0; i < rows.size(); ++i) {
        if (rows[i].self)
            m_playerRank = i + 1;
        QVariantMap m;
        m["rank"]  = i + 1;
        m["name"]  = rows[i].name;
        m["score"] = rows[i].score;
        m["self"]  = rows[i].self;
        m_entries.push_back(m);
    }
    emit entriesChanged();
}

void Leaderboard::mockRefresh()
{
    setStatus(Loading);
    // A short delay so the loading state is real (and the UI is testable).
    QTimer::singleShot(350, this, [this] {
        rebuildMock();
        setStatus(Ready);
        if (m_pendingSubmit) {
            m_pendingSubmit = false;
            emit submitted(m_playerRank);
        }
    });
}

// ── Network backend (Supabase REST) ──────────────────────────────────────────
void Leaderboard::netRefresh()
{
    if (!m_net) m_net = new QNetworkAccessManager(this);
    setStatus(Loading);

    QUrl url(m_baseUrl + "/rest/v1/scores");
    QUrlQuery q;
    q.addQueryItem("select", "player_uuid,nickname,score");
    q.addQueryItem("order", "score.desc");
    q.addQueryItem("limit", QString::number(m_limit));
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setRawHeader("apikey", m_anonKey.toUtf8());
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_anonKey.toUtf8());

    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            m_pendingSubmit = false;
            setStatus(Error, reply->errorString());
            return;
        }
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        m_entries.clear();
        m_playerRank = -1;
        QString selfServerNick;
        for (int i = 0; i < arr.size(); ++i) {
            const QJsonObject o = arr[i].toObject();
            const QString name = o.value("nickname").toString();
            // Identity is the stable player_uuid — so a rename never loses your rank.
            const bool self = (o.value("player_uuid").toString() == m_playerId);
            if (self && m_playerRank < 0) {
                m_playerRank = i + 1;
                selfServerNick = name;
            }
            QVariantMap m;
            m["rank"]  = i + 1;
            m["name"]  = name;
            m["score"] = o.value("score").toInt();
            m["self"]  = self;
            m_entries.push_back(m);
        }
        emit entriesChanged();
        setStatus(Ready);

        // Self-heal: if our row exists but carries a stale nickname (e.g. renamed under
        // older code), push the current name once. The follow-up refresh will match and
        // stop, so this converges in a single extra round-trip.
        if (!m_healing && m_myBest >= MinScore
                && !selfServerNick.isEmpty() && selfServerNick != m_nickname) {
            m_healing = true;
            netSubmit(m_myBest);
            return;
        }
        m_healing = false;

        if (m_pendingSubmit) {
            m_pendingSubmit = false;
            emit submitted(m_playerRank);
        }
    });
}

void Leaderboard::netSubmit(int score)
{
    if (!m_net) m_net = new QNetworkAccessManager(this);

    QUrl url(m_baseUrl + "/rest/v1/scores");
    QNetworkRequest req(url);
    req.setRawHeader("apikey", m_anonKey.toUtf8());
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_anonKey.toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    // Upsert on player_uuid so the table keeps one row per player; don't echo the row back.
    req.setRawHeader("Prefer", "resolution=merge-duplicates,return=minimal");

    QJsonObject body;
    body["player_uuid"] = m_playerId;
    body["nickname"]    = m_nickname;
    body["score"]       = score;

    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            m_pendingSubmit = false;
            setStatus(Error, reply->errorString());
            return;
        }
        netRefresh();   // pull the updated board (and our new rank), then emit submitted()
    });
}
