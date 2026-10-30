// SPDX-FileCopyrightText: 2026 Keshav Bhatt (Ktechpit)
// SPDX-License-Identifier: LicenseRef-Ktechpit-Licensing-Module

#pragma once

#include "AccountLicenseConfig.h"

#include <QCoreApplication>
#include <QStringLiteral>

/**
 * @brief AccountLicenseConfig for Hungry Snake.
 *
 * A thin client over the shared ktechpit "USS" backend, keyed by
 * @c slug=hungrysnake (mirrors the sibling apps, e.g. ArrowEscape).
 *
 * Hungry Snake is fully free — this backend only gates the one-time
 * "Supporter Pack" (a Coin bundle + exclusive cosmetics). There is NO trial and
 * nothing is ever locked behind it, so @c evaluationDurationSecs is 0.
 */
inline AccountLicenseConfig hungrySnakeLicenseConfig()
{
    AccountLicenseConfig cfg;

    cfg.appCode = QStringLiteral("HS");
    cfg.appName = QStringLiteral("Hungry Snake");

    // Must match QGuiApplication::setOrganizationName / setApplicationName
    // (set from AppInfo.h in main.cpp before any storage is touched).
    cfg.settingsOrgName = QCoreApplication::organizationName();
    cfg.settingsAppName = QCoreApplication::applicationName();

    cfg.checkStatusEndpoint =
        QStringLiteral("https://ktechpit.com/USS/public/check/status.php");
    cfg.checkoutUrlTemplate = QStringLiteral(
        "https://ktechpit.com/USS/public/checkout.php?slug=hungrysnake&accountId=%1");
    cfg.selfServicePortalUrl =
        QStringLiteral("https://ktechpit.com/USS/public/user/");

    // No trial — the game is free; the Supporter Pack is a one-time purchase.
    cfg.evaluationDurationSecs = 0;

    return cfg;
}
