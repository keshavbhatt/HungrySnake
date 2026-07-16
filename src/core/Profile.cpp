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
    m_store.endGroup();
}

void Profile::persist()
{
    m_store.beginGroup(QLatin1String(kGroup));
    m_store.setValue(QLatin1String(kKeySchema), kSchemaVersion);
    m_store.setValue(QLatin1String(kKeyBerries), m_berries);
    m_store.setValue(QLatin1String(kKeyGames), m_gamesPlayed);
    m_store.setValue(QLatin1String(kKeyApples), m_lifetimeApples);
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
