import 'package:flutter/material.dart';

import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../application/settings/settings_text.dart';

class RestorePrecheckSummaryItem {
  const RestorePrecheckSummaryItem({
    required this.icon,
    required this.title,
    required this.body,
    this.isWarning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool isWarning;
}

String restoreConfirmHeadline(AppLocalizations l10n, RestorePrecheck precheck) {
  if (precheck.willOverwriteLocalVault) {
    return l10n.settingsRestoreConfirmOverwriteHeadline;
  }
  return l10n.settingsRestoreConfirmFreshVaultHeadline;
}

List<RestorePrecheckSummaryItem> buildRestorePrecheckSummaryItems(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  final List<RestorePrecheckSummaryItem> items = <RestorePrecheckSummaryItem>[];

  items.add(
    RestorePrecheckSummaryItem(
      icon: precheck.sameVaultId
          ? Icons.home_work_outlined
          : Icons.devices_other_outlined,
      title: precheck.sameVaultId
          ? l10n.settingsRestorePrecheckSameVaultTitle
          : l10n.settingsRestorePrecheckOtherVaultTitle,
      body: precheck.sameVaultId
          ? l10n.settingsRestorePrecheckSameVaultBody
          : l10n.settingsRestorePrecheckOtherVaultBody,
    ),
  );

  if (precheck.recoveryKeyRotatedSinceBackup) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.autorenew_rounded,
        title: l10n.settingsRestorePrecheckRotatedTitle,
        body: l10n.settingsRestorePrecheckRotatedBody,
        isWarning: true,
      ),
    );
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      items.add(
        RestorePrecheckSummaryItem(
          icon: Icons.tips_and_updates_outlined,
          title: l10n.settingsRestorePrecheckHintTitle,
          body: settingsRecoveryKeyHintLine(l10n, hint),
        ),
      );
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.verified_user_outlined,
        title: l10n.settingsRestorePrecheckTrustedUnlockTitle,
        body: l10n.settingsRestorePrecheckTrustedUnlockBody,
      ),
    );
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    items.add(
      RestorePrecheckSummaryItem(
        icon: Icons.vpn_key_outlined,
        title: l10n.settingsRestorePrecheckRecoveryKeyTitle,
        body: l10n.settingsRestorePrecheckRecoveryKeyBody,
        isWarning: true,
      ),
    );
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      items.add(
        RestorePrecheckSummaryItem(
          icon: Icons.tips_and_updates_outlined,
          title: l10n.settingsRestorePrecheckHintTitle,
          body: settingsRecoveryKeyHintLine(l10n, hint),
        ),
      );
    }
  }

  items.add(
    RestorePrecheckSummaryItem(
      icon: Icons.search_outlined,
      title: l10n.settingsRestorePrecheckRebuildIndexTitle,
      body: l10n.settingsRestorePrecheckRebuildIndexBody,
    ),
  );

  items.add(
    RestorePrecheckSummaryItem(
      icon: Icons.hourglass_top_outlined,
      title: l10n.settingsRestorePrecheckRewrapTitle,
      body: l10n.settingsRestorePrecheckRewrapBody,
    ),
  );

  return items;
}

List<String> buildRestoreConfirmBulletPoints(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  final List<String> bullets = <String>[];
  if (precheck.willOverwriteLocalVault) {
    bullets.add(l10n.settingsRestoreBulletOverwriteWarning);
  } else {
    bullets.add(l10n.settingsRestoreBulletFreshVaultNote);
  }
  bullets.add(l10n.settingsRestoreBulletRebuildIndex);

  if (precheck.recoveryKeyRotatedSinceBackup) {
    bullets.add(l10n.settingsRestoreBulletRotatedBackup);
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      bullets.add(settingsRecoveryKeyHintLine(l10n, hint));
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlock);
    bullets.add(l10n.settingsRestoreBulletTrustedAutoUnlockFallback);
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    bullets.add(l10n.settingsRestoreBulletRecoveryKeyAfterRestore);
    final String hint = precheck.backupRecoveryHint;
    if (hint.isNotEmpty) {
      bullets.add(settingsRecoveryKeyHintLine(l10n, hint));
    }
  }

  bullets.add(l10n.settingsRestoreBulletRewrapNote);
  return bullets;
}

String restoreRecoveryKeyDialogSubtitle(
  AppLocalizations l10n,
  RestorePrecheck precheck,
) {
  if (precheck.recoveryKeyRotatedSinceBackup) {
    return l10n.settingsRestoreDialogSubtitleRotatedBackup;
  }
  if (precheck.sameVaultId) {
    return l10n.settingsRestoreDialogSubtitleSameVaultManual;
  }
  return l10n.settingsRestoreDialogSubtitleOtherVault;
}
