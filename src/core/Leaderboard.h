#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QtQmlIntegration/qqmlintegration.h>

class QNetworkAccessManager;

// Global leaderboard client. Talks to a hosted Supabase table over plain REST
// (submit a score, fetch the top N). When Supabase isn't configured — no URL/key in
// the environment or QSettings — it runs in MOCK mode against a seeded demo board so
// the whole flow (nickname prompt, submit-on-best, ranked list) is fully usable
// offline while a backend is stood up.
//
// Identity is anonymous: a random per-install `playerId` (uuid) plus a nickname the
// player picks once. Both persist in QSettings (group "leaderboard"); the only bit of
// personal data is the nickname. The player's own best is submitted as an UPSERT keyed
// on playerId, so the table holds one row per player, not one per run.
class Leaderboard : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList entries READ entries NOTIFY entriesChanged)
    Q_PROPERTY(Status status        READ status       NOTIFY statusChanged)
    Q_PROPERTY(QString errorString  READ errorString  NOTIFY statusChanged)
    Q_PROPERTY(QString nickname     READ nickname     NOTIFY nicknameChanged)
    Q_PROPERTY(bool hasNickname     READ hasNickname  NOTIFY nicknameChanged)
    Q_PROPERTY(int  playerRank      READ playerRank   NOTIFY entriesChanged)   // -1 = unranked
    Q_PROPERTY(int  playerBest      READ playerBest   NOTIFY entriesChanged)
    Q_PROPERTY(bool usingMock       READ usingMock    CONSTANT)
    Q_PROPERTY(int  minScore        READ minScore     CONSTANT)   // qualify for the board

public:
    enum Status { Idle, Loading, Ready, Error };
    Q_ENUM(Status)

    // Minimum score to appear on the global board — keeps it meaningful and filters
    // trivial/accidental runs. Enforced here (no submit below it) and in RLS.
    static constexpr int MinScore = 10;

    explicit Leaderboard(QObject *parent = nullptr);

    QVariantList entries() const { return m_entries; }
    Status  status() const { return m_status; }
    QString errorString() const { return m_error; }
    QString nickname() const { return m_nickname; }
    bool    hasNickname() const { return !m_nickname.isEmpty(); }
    int     playerRank() const { return m_playerRank; }
    int     playerBest() const { return m_myBest; }
    bool    usingMock() const { return m_mock; }
    int     minScore() const { return MinScore; }

    // Set/clear the player's display name (trimmed, clamped). Persists + refreshes.
    Q_INVOKABLE void setNickname(const QString &name);
    // (Re)load the top scores.
    Q_INVOKABLE void refresh();
    // Submit the player's best. No-op write if it isn't an improvement; always refreshes.
    Q_INVOKABLE void submit(int score);

signals:
    void entriesChanged();
    void statusChanged();
    void nicknameChanged();
    // Fired once after a real improvement is posted and the board refreshes, carrying
    // the player's new rank (-1 if they landed outside the fetched top N). Not emitted
    // for plain refreshes or no-op re-submits, so the UI can celebrate only real posts.
    void submitted(int rank);

private:
    void setStatus(Status s, const QString &err = QString());
    void save();

    void rebuildMock();          // build the ranked list from seed + the player's best
    void mockRefresh();          // simulate a fetch (short latency)

    void netRefresh();
    void netSubmit(int score);

    QNetworkAccessManager *m_net = nullptr;   // created lazily (network mode only)

    QVariantList m_entries;
    Status  m_status = Idle;
    QString m_error;

    QString m_nickname;
    QString m_playerId;
    int     m_myBest = 0;
    int     m_playerRank = -1;
    bool    m_pendingSubmit = false;   // a real post is awaiting its refresh → emit submitted()
    bool    m_healing = false;         // a stale-nickname self-heal upsert is in flight

    bool    m_mock = true;
    QString m_baseUrl;
    QString m_anonKey;
    int     m_limit = 50;
};
