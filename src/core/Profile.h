#pragma once

#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// Profile — the player's persistent meta-progression store, backed by QSettings
// under the app identity (same backing file as the QML Settings, in a separate
// "profile" group). Stage 1 owns just the Coins soft-currency and a couple of
// lifetime counters; later stages extend it with owned/equipped cosmetics,
// achievements and the daily challenge (see docs/ROADMAP.md).
//
// Design rule: Coins are earned only by playing and spent only on cosmetics —
// they never affect gameplay.
class Profile : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int coins        READ coins        NOTIFY coinsChanged)
    Q_PROPERTY(int gamesPlayed    READ gamesPlayed    NOTIFY statsChanged)
    Q_PROPERTY(int lifetimeApples READ lifetimeApples NOTIFY statsChanged)
    Q_PROPERTY(int lastRunCoins READ lastRunCoins NOTIFY lastRunChanged)
    // Cosmetics: the set of purchased cosmetic ids, and the id equipped per slot
    // (slot → id). Free/default cosmetics aren't stored in `owned` (price 0 ⇒ owned).
    Q_PROPERTY(QStringList owned  READ owned          NOTIFY ownedChanged)
    Q_PROPERTY(QVariantMap equipped READ equipped     NOTIFY equippedChanged)
    // Meta-progression: claimed achievement ids + the daily-challenge streak state.
    Q_PROPERTY(QStringList claimed READ claimed       NOTIFY claimedChanged)
    Q_PROPERTY(int dailyStreak    READ dailyStreak    NOTIFY dailyChanged)
    Q_PROPERTY(int bestStreak     READ bestStreak     NOTIFY dailyChanged)
    Q_PROPERTY(QString dailyLast  READ dailyLast      NOTIFY dailyChanged)   // last-completed date
    // One-time Supporter unlock (the game is fully free without it — this only
    // grants a Coin bundle + exclusive cosmetics and says thanks).
    Q_PROPERTY(bool supporter     READ supporter      NOTIFY supporterChanged)

public:
    explicit Profile(QObject *parent = nullptr);

    int coins()        const { return m_coins; }
    int gamesPlayed()    const { return m_gamesPlayed; }
    int lifetimeApples() const { return m_lifetimeApples; }
    int lastRunCoins() const { return m_lastRunCoins; }
    QStringList owned()  const { return m_owned; }
    QVariantMap equipped() const { return m_equipped; }
    QStringList claimed() const { return m_claimed; }
    int dailyStreak()    const { return m_dailyStreak; }
    int bestStreak()     const { return m_bestStreak; }
    QString dailyLast()  const { return m_dailyLast; }
    bool supporter()     const { return m_supporter; }

    // Award Coins outright (daily/achievement rewards, the Supporter bundle).
    Q_INVOKABLE void grant(int coins);

    // Record a finished run: bank Coins for the apples eaten (+ a new-best
    // bonus), bump lifetime stats, and remember what this run earned (for the
    // Game Over tally). Returns the Coins earned this run.
    Q_INVOKABLE int recordRun(int apples, bool newBest);

    // ── Cosmetics store ──
    Q_INVOKABLE bool owns(const QString &id) const { return m_owned.contains(id); }
    Q_INVOKABLE QString equippedIn(const QString &slot) const
        { return m_equipped.value(slot).toString(); }
    // Purchase a cosmetic: no-op success if free/already owned; deducts Coins and
    // records ownership if affordable. Returns whether the item is (now) owned.
    Q_INVOKABLE bool buy(const QString &id, int price);
    // Equip a cosmetic id into its slot (caller ensures it's owned).
    Q_INVOKABLE void equip(const QString &slot, const QString &id);

    // ── Achievements & daily ──
    // Claim an achievement's one-time reward. Grants Coins and records the id the
    // first time; returns the Coins granted, or -1 if it was already claimed.
    Q_INVOKABLE int claimAchievement(const QString &id, int reward);
    // Mark today's daily challenge complete. `today`/`yesterday` are caller-formatted
    // date strings; the streak extends if the last completion was `yesterday`, resets
    // to 1 otherwise, and is unchanged if already completed `today`. Returns the
    // Coins granted (0 if it was already done today).
    Q_INVOKABLE int completeDaily(const QString &today, const QString &yesterday, int reward);

    // Redeem the one-time Supporter unlock: mark supporter, bank a Coin bundle, and
    // add the exclusive cosmetic ids to `owned`. No-op if already a supporter. (The
    // real purchase/licensing gate lives in the caller; this just applies the grant.)
    Q_INVOKABLE void unlockSupporter(int bundle, const QStringList &exclusiveIds);

signals:
    void coinsChanged();
    void statsChanged();
    void lastRunChanged();
    void ownedChanged();
    void equippedChanged();
    void claimedChanged();
    void dailyChanged();
    void supporterChanged();

private:
    void load();
    void persist();

    QSettings m_store;
    int m_coins = 0;
    int m_gamesPlayed = 0;
    int m_lifetimeApples = 0;
    int m_lastRunCoins = 0;
    QStringList m_owned;
    QVariantMap m_equipped;   // slot → cosmetic id
    QStringList m_claimed;    // claimed achievement ids
    int m_dailyStreak = 0;
    int m_bestStreak = 0;
    QString m_dailyLast;      // date string of the last daily completion
    bool m_supporter = false;
};
