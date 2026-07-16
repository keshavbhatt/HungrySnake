#include "Profile.h"

#include <algorithm>

namespace {
// Berry economy — tunable; see docs/ROADMAP.md (§1). Kept deliberately simple in
// Stage 1: one Berry per apple, a small bonus for beating your best.
constexpr int kBerriesPerApple = 1;
constexpr int kNewBestBonus    = 5;
constexpr int kSchemaVersion   = 1;

constexpr auto kGroup          = "profile";
constexpr auto kKeySchema      = "schema";
constexpr auto kKeyBerries     = "berries";
constexpr auto kKeyGames       = "gamesPlayed";
constexpr auto kKeyApples      = "lifetimeApples";
constexpr auto kKeyOwned       = "owned";
constexpr auto kKeyClaimed     = "claimed";
constexpr auto kKeyStreak      = "dailyStreak";
constexpr auto kKeyBestStreak  = "bestStreak";
constexpr auto kKeyDailyLast   = "dailyLast";
constexpr auto kEquipGroup     = "profile/equipped";
} // namespace

Profile::Profile(QObject *parent)
    : QObject(parent)   // QSettings() uses the org/app set in main() before QML loads
{
    load();
}

void Profile::load()
{
    m_store.beginGroup(QLatin1String(kGroup));
    m_berries        = m_store.value(QLatin1String(kKeyBerries), 0).toInt();
    m_gamesPlayed    = m_store.value(QLatin1String(kKeyGames), 0).toInt();
    m_lifetimeApples = m_store.value(QLatin1String(kKeyApples), 0).toInt();
    m_owned          = m_store.value(QLatin1String(kKeyOwned)).toStringList();
    m_claimed        = m_store.value(QLatin1String(kKeyClaimed)).toStringList();
    m_dailyStreak    = m_store.value(QLatin1String(kKeyStreak), 0).toInt();
    m_bestStreak     = m_store.value(QLatin1String(kKeyBestStreak), 0).toInt();
    m_dailyLast      = m_store.value(QLatin1String(kKeyDailyLast)).toString();
    m_store.endGroup();

    // Equipped ids live in their own group (slot = key, id = value).
    m_equipped.clear();
    m_store.beginGroup(QLatin1String(kEquipGroup));
    const auto slotKeys = m_store.childKeys();
    for (const QString &slot : slotKeys)
        m_equipped.insert(slot, m_store.value(slot));
    m_store.endGroup();
}

void Profile::persist()
{
    m_store.beginGroup(QLatin1String(kGroup));
    m_store.setValue(QLatin1String(kKeySchema), kSchemaVersion);
    m_store.setValue(QLatin1String(kKeyBerries), m_berries);
    m_store.setValue(QLatin1String(kKeyGames), m_gamesPlayed);
    m_store.setValue(QLatin1String(kKeyApples), m_lifetimeApples);
    m_store.setValue(QLatin1String(kKeyOwned), m_owned);
    m_store.setValue(QLatin1String(kKeyClaimed), m_claimed);
    m_store.setValue(QLatin1String(kKeyStreak), m_dailyStreak);
    m_store.setValue(QLatin1String(kKeyBestStreak), m_bestStreak);
    m_store.setValue(QLatin1String(kKeyDailyLast), m_dailyLast);
    m_store.endGroup();

    m_store.beginGroup(QLatin1String(kEquipGroup));
    for (auto it = m_equipped.constBegin(); it != m_equipped.constEnd(); ++it)
        m_store.setValue(it.key(), it.value());
    m_store.endGroup();
}

void Profile::grant(int berries)
{
    if (berries <= 0)
        return;
    m_berries += berries;
    persist();
    emit berriesChanged();
}

int Profile::recordRun(int apples, bool newBest)
{
    const int a = std::max(0, apples);
    const int earned = a * kBerriesPerApple + (newBest ? kNewBestBonus : 0);

    m_lifetimeApples += a;
    m_gamesPlayed    += 1;
    m_berries        += earned;
    m_lastRunBerries  = earned;

    persist();
    emit berriesChanged();
    emit statsChanged();
    emit lastRunChanged();
    return earned;
}

bool Profile::buy(const QString &id, int price)
{
    if (price <= 0 || m_owned.contains(id))
        return true;                 // free / already owned
    if (m_berries < price)
        return false;                // can't afford
    m_berries -= price;
    m_owned.append(id);
    persist();
    emit berriesChanged();
    emit ownedChanged();
    return true;
}

void Profile::equip(const QString &slot, const QString &id)
{
    if (m_equipped.value(slot).toString() == id)
        return;
    m_equipped.insert(slot, id);
    persist();
    emit equippedChanged();
}

int Profile::claimAchievement(const QString &id, int reward)
{
    if (m_claimed.contains(id))
        return -1;                   // already claimed
    m_claimed.append(id);
    const int r = std::max(0, reward);
    m_berries += r;
    persist();
    emit claimedChanged();
    emit berriesChanged();
    return r;
}

int Profile::completeDaily(const QString &today, const QString &yesterday, int reward)
{
    if (m_dailyLast == today)
        return 0;                    // already done today
    m_dailyStreak = (m_dailyLast == yesterday) ? m_dailyStreak + 1 : 1;
    m_bestStreak  = std::max(m_bestStreak, m_dailyStreak);
    m_dailyLast   = today;
    const int r = std::max(0, reward);
    m_berries += r;
    persist();
    emit dailyChanged();
    emit berriesChanged();
    return r;
}
