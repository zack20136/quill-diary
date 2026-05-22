import '../../infrastructure/storage/restore_precheck.dart';

/// 設定頁與相關對話框的繁體中文文案（單一來源）。
///
/// 用語規範：
/// - 金鑰：復原金鑰
/// - 資料：日記庫
/// - 裝置：本機；授權相關用「本機受信任裝置」
/// - 並列：匯入／匯出、備份／還原（全形斜線）
/// - 驗證：生物驗證、裝置螢幕鎖
/// - 末四碼：`末四碼：XXXX`
abstract final class SettingsCopy {
  static const String pageTitle = '設定';

  static const String actionCancel = '取消';
  static const String actionClose = '關閉';
  static const String actionConfirm = '還原';
  static const String actionUpdate = '更新';
  static const String actionVerifyAndRestore = '驗證並還原';

  static const String progressDefault = '處理中，請稍候…';

  static const String recoveryKeyFieldLabel = '復原金鑰';
  static const String recoveryKeyFieldHint = 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX';

  /// 末四碼提示行（chip、橫幅、對話框共用格式）。
  static String recoveryKeyHintLine(String hint) => '末四碼：$hint';
}

abstract final class SettingsPlatformCopy {
  static const String sectionTitle = '平台限制';
  static const String sectionDescription = '此版本僅支援 Android 上的加密日記庫。';
}

abstract final class SettingsSecurityLockCopy {
  static const String sectionTitle = '安全鎖狀態';
  static const String sectionDescription = '查看安全鎖是否已解除，必要時可用復原金鑰重新進入。';
  static const String loadErrorDescription = '讀取狀態時發生錯誤。';

  static const String statusPreparing = '正在準備中…';
  static const String statusUnlocked = '安全鎖已解除，可以正常使用。';
  static const String statusFatalError = '初始化失敗，請稍後再試。';

  static const String unlockingWaitHint =
      '若等候過久，可能是驗證視窗被擋住。可取消後改用手動驗證。';
  static const String cancelUnlockButton = '取消並改用手動驗證';
  static const String unlockWithDeviceLockButton = '使用裝置螢幕鎖解鎖';
  static const String unlockWithRecoveryButton = '使用復原金鑰解鎖';
  static const String recoveryUnlockHint =
      '輸入復原金鑰以重新解鎖本機日記庫。';
  static const String retryVerificationButton = '重新驗證';
}

abstract final class SettingsRecoveryKeyCopy {
  static const String sectionTitle = '復原金鑰';
  static const String sectionDescription = '裝置無法自動解鎖時的備用金鑰，請妥善保存。';
  static const String loadErrorDescription = '讀取復原金鑰設定失敗。';

  static const String notSetupBanner =
      '尚未建立復原金鑰。日記庫無法自動解鎖時，將無法重新進入。';
  static const String setupBanner = '復原金鑰已建立。需要時可用它重新解鎖本機日記庫。';
  static const String createButton = '建立復原金鑰';
  static const String rotateButton = '更新復原金鑰';

  static const String factVaultLabel = '日記庫';
  static const String factHintLabel = '末四碼';
  static const String factKdfLabel = '加密方式';

  static const String saveDialogTitle = '請保存復原金鑰';
  static const String saveNewDialogTitle = '請保存新的復原金鑰';

  static const String rotateDialogTitle = '更新復原金鑰？';
  static const String rotateDialogBody =
      '將產生全新的復原金鑰，請立即保存。\n\n'
      '既有本機或 Google Drive 備份仍須使用舊金鑰還原；更新後請重新建立備份。';
}

abstract final class SettingsUnlockMethodCopy {
  static const String sectionTitle = '解鎖方式';
  static const String sectionDescription =
      'App 在背景一段時間後回到前景時，要如何重新驗證身分以進入日記庫。';
  static const String needsRecoveryKeyBanner = '請先建立復原金鑰，才能設定解鎖方式。';

  /// 分段按鈕標籤（較短，完整名稱見 [UnlockMethodSectionBody.labelForMode]）。
  static const String segmentDeviceLock = '螢幕鎖';

  static const String biometricNeedsDeviceLockHint =
      '須已登錄至少一種生物辨識，並設定裝置螢幕鎖；驗證取消或失敗時，可改以螢幕鎖解鎖，不必輸入復原金鑰。';
}

/// 備份／還原／匯入／匯出在設定頁不可用時的說明（空字串表示可用）。
String sensitiveVaultTransferDisabledReason({
  required bool hasUnlockedSession,
  required bool hasRecoveryKey,
}) {
  if (!hasUnlockedSession) {
    return SettingsSensitiveVaultCopy.needsUnlockMessage;
  }
  if (!hasRecoveryKey) {
    return SettingsSensitiveVaultCopy.needsRecoveryKeyMessage;
  }
  return '';
}

abstract final class SettingsSensitiveVaultCopy {
  static const String needsUnlockMessage =
      '請先解鎖日記庫後，再進行備份、還原或匯入／匯出。';
  static const String needsRecoveryKeyMessage =
      '請先建立復原金鑰後，再進行備份、還原或匯入／匯出。';
}

abstract final class SettingsImportExportCopy {
  static const String sectionTitle = '匯入與匯出';
  static const String sectionDescriptionEnabled =
      '匯出日記為 Markdown 壓縮檔；可匯入 Markdown、HTML 或 zip。';

  static const String exportButton = '匯出日記';
  static const String importButton = '匯入檔案';
  static const String exportProgress = '正在匯出日記，整理內容與附件中…';

  static String exportSuccess(String path) => '已匯出 Markdown 壓縮檔：$path';
  static String importSuccess(int count) => '已匯入 $count 篇日記。';
  static String importSuccessWithSkipped(int count, int skipped) =>
      '已匯入 $count 篇日記，略過 $skipped 個檔案。';
}

abstract final class SettingsLocalBackupCopy {
  static const String sectionTitle = '本機備份與還原';
  static const String sectionDescriptionEnabled =
      '將整個加密日記庫儲存成 .jbackup，預設位置為 Downloads/quill-lock-dairy。建立後會立即檢查檔案結構；還原會覆寫本機資料。';

  static const String createButton = '建立並檢查備份';
  static const String restoreButton = '從本機備份還原';

  static String createSuccess(String path) => '備份已建立並通過檢查。\n位置：$path';
}

abstract final class SettingsDriveBackupCopy {
  static const String sectionTitle = 'Google Drive 備份與還原';
  static const String sectionDescriptionEnabled =
      '將 .jbackup 上傳到 Google Drive，或從雲端下載備份還原。還原後可能需要輸入建立備份時保存的復原金鑰。';

  static const String uploadButton = '上傳備份到 Google Drive';
  static const String restoreButton = '從 Google Drive 備份還原';

  static const String uploadSuccess = '備份已上傳到 Google Drive。';
  static const String noBackups = 'Google Drive 中找不到 .jbackup 備份檔。';
  static const String pickDialogTitle = '選擇 Google Drive 備份';
  static const String unknownCreatedTime = '無建立時間';

  static const String googleHelpHint =
      '如果你剛調整 Google Drive 權限或授權設定，先重新登入再重試通常就能完成授權。';
  static const String googleHelpRetryButton = '重新登入後重試';
}

abstract final class SettingsRestoreDialogCopy {
  static const String confirmLocalTitle = '還原本機備份？';
  static const String confirmDriveTitle = '還原 Google Drive 備份？';
  static String driveFileLine(String name) => '檔案：$name';

  static const String recoveryKeyDialogTitle = '輸入備份復原金鑰';
  static const String recoveryKeyEmptyError = '請輸入復原金鑰。';
  static const String recoveryKeyVerifyNote =
      '金鑰正確後才會開始還原；錯誤則不會覆寫本機資料。';

  static const String subtitleRotatedBackup =
      '此備份在「更新復原金鑰」之前建立。請輸入建立該備份時保存的舊金鑰（不是目前這把新金鑰）。';
  static const String subtitleSameVaultManual =
      '本機無法自動解鎖此備份。請輸入建立此備份時保存的復原金鑰。';
  static const String subtitleOtherVault =
      '此備份來自其他裝置或不同授權狀態。請輸入建立此備份時保存的復原金鑰。';
}

abstract final class SettingsRestoreBulletCopy {
  static const String overwriteWarning = '將以備份內容覆寫本機日記庫，現有資料無法復原。';
  static const String rebuildIndex = '索引會在解鎖後重新建立。';
  static const String backupWithoutRecovery =
      '此備份尚未建立復原金鑰；還原後請重新建立。';
  static const String rotatedBackup =
      '此備份在「更新復原金鑰」之前建立；還原後請輸入建立該備份時保存的舊復原金鑰（不是目前這把新金鑰）。';
  static const String trustedAutoUnlock = '還原後會先嘗試以本機受信任裝置自動解鎖。';
  static const String trustedAutoUnlockFallback =
      '若驗證失敗，再輸入建立此備份時保存的復原金鑰。';
  static const String recoveryKeyAfterRestore =
      '還原後需輸入建立此備份時保存的復原金鑰（非本機後來新建的另一把）。';
  static const String rewrapNote = '首次解鎖可能需重新包裝加密檔，請保持 App 開啟。';
}

/// 還原確認對話框的 bullet 列表（文案來自 [SettingsRestoreBulletCopy]）。
List<String> buildRestoreConfirmBulletPoints(RestorePrecheck precheck) {
  final List<String> bullets = <String>[
    SettingsRestoreBulletCopy.overwriteWarning,
    SettingsRestoreBulletCopy.rebuildIndex,
  ];

  if (!precheck.backupHasRecovery) {
    bullets.add(SettingsRestoreBulletCopy.backupWithoutRecovery);
    return bullets;
  }

  if (precheck.recoveryKeyRotatedSinceBackup) {
    bullets.add(SettingsRestoreBulletCopy.rotatedBackup);
    final String? hint = precheck.backupRecoveryHint;
    if (hint != null && hint.isNotEmpty) {
      bullets.add(SettingsCopy.recoveryKeyHintLine(hint));
    }
  } else if (precheck.expectsTrustedUnlockAfterRestore) {
    bullets.add(SettingsRestoreBulletCopy.trustedAutoUnlock);
    bullets.add(SettingsRestoreBulletCopy.trustedAutoUnlockFallback);
  } else if (precheck.expectsRecoveryKeyAfterRestore) {
    bullets.add(SettingsRestoreBulletCopy.recoveryKeyAfterRestore);
    final String? hint = precheck.backupRecoveryHint;
    if (hint != null && hint.isNotEmpty) {
      bullets.add(SettingsCopy.recoveryKeyHintLine(hint));
    }
  }

  bullets.add(SettingsRestoreBulletCopy.rewrapNote);
  return bullets;
}

/// 還原前金鑰對話框的說明文字。
String restoreRecoveryKeyDialogSubtitle(RestorePrecheck precheck) {
  if (precheck.recoveryKeyRotatedSinceBackup) {
    return SettingsRestoreDialogCopy.subtitleRotatedBackup;
  }
  if (precheck.sameVaultId) {
    return SettingsRestoreDialogCopy.subtitleSameVaultManual;
  }
  return SettingsRestoreDialogCopy.subtitleOtherVault;
}
