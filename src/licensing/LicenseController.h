#pragma once

#include "AccountLicenseManager.h"

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

/**
 * @brief QML-facing façade over the reusable AccountLicenseManager.
 *
 * Exposed to QML as a singleton (LicenseController). Any Pro feature entry point
 * calls @c checkAccess("Feature Name"): it returns true when the user has paid or
 * is inside the evaluation window, otherwise it emits @c upgradeRequested so the
 * UI can open the Upgrade view.
 */
class LicenseController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool hasPaidAccess READ hasPaidAccess NOTIFY statusChanged)
    Q_PROPERTY(bool evaluationActive READ evaluationActive NOTIFY statusChanged)
    Q_PROPERTY(int evaluationDaysRemaining READ evaluationDaysRemaining NOTIFY statusChanged)
    Q_PROPERTY(bool pro READ pro NOTIFY statusChanged)            // paid OR in trial
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)

    Q_PROPERTY(QString tier READ tier NOTIFY statusChanged)       // "pro" | "trial" | "free"
    Q_PROPERTY(QString accountId READ accountId NOTIFY accountChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)

public:
    explicit LicenseController(QObject *parent = nullptr);

    // "Actually purchased" — deliberately NOT the module's hasPaidAccess, which
    // also reports true during the trial (paid || evaluationActive). QML uses this
    // to hide the Upgrade button only once the user has truly bought Pro, so the
    // trial still shows an "Upgrade now" path.
    bool hasPaidAccess() const { return m_status.active; }
    bool evaluationActive() const { return m_status.evaluationActive; }
    int evaluationDaysRemaining() const { return m_status.evaluationDaysRemaining; }
    bool pro() const { return m_status.hasPaidAccess || m_status.evaluationActive; }
    bool checking() const { return m_checking; }

    QString tier() const;
    QString accountId() const { return m_accountId; }
    QString statusMessage() const { return m_status.message; }

    /// Gate a Pro feature. Returns true if the caller may proceed; otherwise
    /// emits upgradeRequested(featureName) and returns false.
    Q_INVOKABLE bool checkAccess(const QString &featureName);

    Q_INVOKABLE void openCheckout();   // purchase page in the browser
    Q_INVOKABLE void openPortal();     // account self-service portal
    Q_INVOKABLE void refresh();        // force a fresh remote re-check

#ifdef QT_DEBUG
    /// Debug builds only: force a simulated tier ("pro"/"trial"/"free"/"neterr").
    Q_INVOKABLE void debugSetTier(const QString &tier);
    /// Debug builds only: backdate the trial by N days and return days-remaining.
    Q_INVOKABLE int debugTrialDaysAfter(int daysElapsed)
    { return m_manager.debugTrialDaysAfterElapsed(daysElapsed); }
    /// Debug builds only: read days-remaining from the persisted start (no write).
    Q_INVOKABLE int debugReadTrialDays()
    { return m_manager.debugReadTrialDays(); }
#endif

signals:
    void statusChanged();
    void checkingChanged();
    void accountChanged();
    void upgradeRequested(const QString &featureName);

private:
    AccountLicenseManager m_manager;
    AccountLicenseManager::LicenseStatus m_status;
    QString m_accountId;
    bool m_checking = false;
};
