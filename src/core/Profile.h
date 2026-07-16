#pragma once

#include <QObject>
#include <QSettings>
#include <QStringList>
#include <QVariantMap>
#include <QtQmlIntegration/qqmlintegration.h>

// Profile — the player's persistent meta-progression store, backed by QSettings
// under the app identity (same backing file as the QML Settings, in a separate
// "profile" group). Stage 1 owns just the Berries soft-currency and a couple of
// lifetime counters; later stages extend it with owned/equipped cosmetics,
// achievements and the daily challenge (see docs/ROADMAP.md).
//
// Design rule: Berries are earned only by playing and spent only on cosmetics —
// they never affect gameplay.
class Profile : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int berries        READ berries        NOTIFY berriesChanged)
    Q_PROPERTY(int gamesPlayed    READ gamesPlayed    NOTIFY statsChanged)
    Q_PROPERTY(int lifetimeApples READ lifetimeApples NOTIFY statsChanged)
    Q_PROPERTY(int lastRunBerries READ lastRunBerries NOTIFY lastRunChanged)
    // Cosmetics: the set of purchased cosmetic ids, and the id equipped per slot
    // (slot → id). Free/default cosmetics aren't stored in `owned` (price 0 ⇒ owned).
    Q_PROPERTY(QStringList owned  READ owned          NOTIFY ownedChanged)
    Q_PROPERTY(QVariantMap equipped READ equipped     NOTIFY equippedChanged)

public:
    explicit Profile(QObject *parent = nullptr);

    int berries()        const { return m_berries; }
    int gamesPlayed()    const { return m_gamesPlayed; }
    int lifetimeApples() const { return m_lifetimeApples; }
    int lastRunBerries() const { return m_lastRunBerries; }
    QStringList owned()  const { return m_owned; }
    QVariantMap equipped() const { return m_equipped; }

    // Award Berries outright (daily/achievement rewards, the Supporter bundle).
    Q_INVOKABLE void grant(int berries);

    // Record a finished run: bank Berries for the apples eaten (+ a new-best
    // bonus), bump lifetime stats, and remember what this run earned (for the
    // Game Over tally). Returns the Berries earned this run.
    Q_INVOKABLE int recordRun(int apples, bool newBest);

    // ── Cosmetics store ──
    Q_INVOKABLE bool owns(const QString &id) const { return m_owned.contains(id); }
    Q_INVOKABLE QString equippedIn(const QString &slot) const
        { return m_equipped.value(slot).toString(); }
    // Purchase a cosmetic: no-op success if free/already owned; deducts Berries and
    // records ownership if affordable. Returns whether the item is (now) owned.
    Q_INVOKABLE bool buy(const QString &id, int price);
    // Equip a cosmetic id into its slot (caller ensures it's owned).
    Q_INVOKABLE void equip(const QString &slot, const QString &id);

signals:
    void berriesChanged();
    void statsChanged();
    void lastRunChanged();
    void ownedChanged();
    void equippedChanged();

private:
    void load();
    void persist();

    QSettings m_store;
    int m_berries = 0;
    int m_gamesPlayed = 0;
    int m_lifetimeApples = 0;
    int m_lastRunBerries = 0;
    QStringList m_owned;
    QVariantMap m_equipped;   // slot → cosmetic id
};
