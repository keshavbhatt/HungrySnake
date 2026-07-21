#include "LicenseController.h"
#include "HungrySnakeLicenseConfig.h"

#include <QDesktopServices>
#include <QUrl>

LicenseController::LicenseController(QObject *parent)
    : QObject(parent), m_manager(hungrySnakeLicenseConfig())
{
    connect(&m_manager, &AccountLicenseManager::licenseCheckInProgressChanged,
            this, [this](bool inProgress) {
                m_checking = inProgress;
                emit checkingChanged();
            });

    connect(&m_manager, &AccountLicenseManager::licenseStatusUpdated, this,
            [this](const AccountLicenseManager::LicenseStatus &status) {
                m_status = status;
                emit statusChanged();
            });

    connect(&m_manager, &AccountLicenseManager::serialReady, this,
            [this](const QString &serial) {
                m_accountId = serial;
                emit accountChanged();
            });

    m_manager.ensureSerial();
    m_accountId = m_manager.serial();
    m_manager.checkPurchase(m_manager.serial());
}

QString LicenseController::tier() const
{
    // Order matters: during the trial hasPaidAccess may also be true.
    if (m_status.evaluationActive)
        return QStringLiteral("trial");
    if (m_status.hasPaidAccess)
        return QStringLiteral("pro");
    return QStringLiteral("free");
}

bool LicenseController::checkAccess(const QString &featureName)
{
    if (m_status.hasPaidAccess || m_status.evaluationActive)
        return true;
    emit upgradeRequested(featureName);
    return false;
}

void LicenseController::openCheckout()
{
    QDesktopServices::openUrl(QUrl(m_manager.checkoutUrl()));
}

void LicenseController::openPortal()
{
    QDesktopServices::openUrl(QUrl(m_manager.selfServicePortalUrl()));
}

void LicenseController::refresh()
{
    m_manager.checkPurchase(m_manager.serial(), /*force=*/true);
}

#ifdef QT_DEBUG
void LicenseController::debugSetTier(const QString &tier)
{
    using S = AccountLicenseManager::DebugLicenseState;
    S s = S::None;
    if (tier == QLatin1String("pro"))         s = S::Pro;
    else if (tier == QLatin1String("trial"))  s = S::EvaluationActive;
    else if (tier == QLatin1String("free"))   s = S::EvaluationExpired;
    else if (tier == QLatin1String("neterr")) s = S::NetworkError;
    m_manager.setDebugLicenseState(s);
    m_manager.checkPurchase(m_manager.serial(), /*force=*/true);
}
#endif
