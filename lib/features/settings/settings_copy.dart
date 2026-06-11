import '../../domain/shared/vault_backup_policy.dart';
import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/unlock_mode_policy.dart';
import '../session/session_timeout_policy.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../infrastructure/storage/shared/portable_import_result.dart';
import '../../shared/copy/common_copy.dart';
import 'legal_disclosures.dart';

/// 設定頁與相關對話框的繁體中文文案（單一來源）。
///
/// UI 用語與標點規範：
/// - 金鑰：復原金鑰
/// - 資料：日記庫
/// - 裝置：本機；授權相關用「可信裝置」
/// - 並列：匯入 / 匯出、備份 / 還原（半形斜線，兩側各一空格）
/// - 中繼資料：日記 · 標籤 · 數量（半形中點，兩側各一空格）
/// - 句內並列：頓號「、」
/// - 標籤＋值：全形冒號「：」
/// - 補充說明：全形括號「（）」
/// - 省略：Unicode「…」，不用三個半形句點
/// - 日期（Route A）：`2026年6月9日`；量詞前加空格：`3 天`
/// - 空值占位：em dash「—」
/// - 驗證：生物驗證、裝置螢幕鎖
/// - 末四碼：`末四碼：XXXX`
abstract final class SettingsCopy {
  static const String pageTitle = '設定';

  static const String actionCancel = CommonCopy.actionCancel;
  static const String actionClose = '關閉';
  static const String actionDelete = CommonCopy.actionDelete;
  static const String actionConfirm = '確認還原';
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
  static const String sectionDescription = 'Quill Diary 目前僅支援 Android。';
}

abstract final class SettingsSecurityLockCopy {
  static const String statusPreparing = '正在準備中…';
  static const String statusUnlocked = '已解鎖，可以正常使用。';
  static const String statusFatalError = '初始化失敗，請稍後再試。';

  static const String unlockingWaitHint =
      '若等候過久，驗證視窗可能被擋住。可取消後改用手動驗證。';
  static const String cancelUnlockButton = '取消並改用手動驗證';
  static const String unlockWithRecoveryButton = '使用復原金鑰解鎖';
  static const String recoveryUnlockHint = '輸入復原金鑰以解鎖日記庫。';
  static const String retryVerificationButton = '重新驗證';
}

abstract final class SettingsRecoveryKeyCopy {
  static const String notSetupBanner =
      '尚未建立復原金鑰。請先建立，以便換機、備份與還原。';
  static const String setupBanner = '復原金鑰已建立，請確認已妥善保存。';
  static const String createButton = '建立復原金鑰';
  static const String rotateButton = '更新復原金鑰';

  static const String factVaultLabel = '日記庫';
  static const String factHintLabel = '末四碼';
  static const String factKdfLabel = '加密方式';

  static const String saveDialogTitle = '請保存復原金鑰';
  static const String saveNewDialogTitle = '請保存新的復原金鑰';

  static const String copyButton = '複製';
  static const String copiedMessage = '已複製到剪貼簿';

  static const String rotateDialogTitle = '更新復原金鑰？';
  static const String rotateDialogBody =
      '將產生全新的復原金鑰，請立即保存。\n\n'
      '既有本機或 Google Drive 備份仍須使用舊金鑰還原；更新後請重新建立備份。';
}

abstract final class SettingsSecurityOverviewCopy {
  static const String sectionTitle = '安全狀態';
  static const String sectionDescription = '查看復原金鑰、解鎖方式與搜尋索引是否正常。';

  static const String recoveryKeyTitle = '復原金鑰';
  static const String recoveryKeyReady = '已建立，可用於換機與還原。';
  static const String recoveryKeyReadySaved = recoveryKeyReady;
  static const String recoveryKeyMissing = '尚未建立，請先建立後再備份或還原。';
  static const String recoveryKeyMissingOverview = recoveryKeyMissing;

  static const String unlockStatusTitle = '解鎖狀態';
  static const String unlockStatusUnlocked = '日記庫目前已解鎖。';
  static const String unlockStatusLocked = '請先解鎖，才能備份、還原或調整設定。';

  static const String unlockModeTitle = '解鎖方式';
  static const String trustedDeviceTitle = '可信裝置';
  static const String trustedDeviceReady = '這台裝置已完成驗證，可快速解鎖。';
  static const String trustedDeviceReadyOverview = trustedDeviceReady;
  static const String trustedDeviceMissing = '這台裝置尚未完成驗證。';
  static const String unlockModeNeedsRecoveryKeyMessage =
      '建立復原金鑰後，即可設定解鎖方式。';

  static String unlockModeProtectedMessage(String unlockModeLabel) =>
      '目前以 $unlockModeLabel 保護此裝置。';

  static const String indexTitle = '搜尋索引';

  static const String createRecoveryKeyButton = '建立復原金鑰';
  static const String rotateRecoveryKeyButton = '更新復原金鑰';
  static const String rebuildIndexButton = '重建索引';

  static const String healthLevelOk = '正常';
  static const String healthLevelWarning = '需注意';
  static const String healthLevelError = '錯誤';
}

extension AppUnlockModeSettingsCopy on AppUnlockMode {
  /// 分段按鈕等短標籤。
  String get shortLabel => switch (this) {
        AppUnlockMode.none => SettingsUnlockMethodCopy.segmentNone,
        AppUnlockMode.deviceLock => SettingsUnlockMethodCopy.segmentDeviceLock,
        AppUnlockMode.biometric => SettingsUnlockMethodCopy.segmentBiometric,
      };

  /// 安全概覽等完整標籤。
  String get fullLabel => switch (this) {
        AppUnlockMode.none => '無',
        AppUnlockMode.deviceLock => '裝置螢幕鎖',
        AppUnlockMode.biometric => '生物驗證',
      };
}

abstract final class SettingsUnlockMethodCopy {
  static const String sectionTitle = '解鎖方式';

  /// 區塊說明（背景逾時取自 [sessionBackgroundTimeoutLabel]）。
  static String get sectionDescription =>
      '背景超過 ${sessionBackgroundTimeoutLabel()} 未使用會鎖定，短時間切換 App 不會。'
      '鎖定後回到 App 時，請依下方方式重新驗證。';

  static const String needsRecoveryKeyBanner = '請先建立復原金鑰，才能設定解鎖方式。';

  static const String segmentNone = '無';
  static const String segmentDeviceLock = '螢幕鎖';
  static const String segmentBiometric = '生物驗證';

  static const String biometricNeedsDeviceLockHint =
      '須已設定螢幕鎖並登錄生物辨識。\n'
      '驗證取消或失敗時，可改以螢幕鎖解鎖，不必輸入復原金鑰。';

  static const String unlockModeChangeCancelled = kUnlockModeChangeCancelledMessage;

  static const String unlockModeChangeAuthFailed = kUnlockModeChangeAuthFailedMessage;

  static String unlockModeDescription(AppUnlockMode mode) => switch (mode) {
        AppUnlockMode.none =>
          '鎖定後不額外驗證，直接解鎖。適合尚未設定螢幕鎖的裝置，安全性較低。',
        AppUnlockMode.deviceLock =>
          '鎖定後以螢幕鎖（PIN、圖案或密碼）驗證。請先在裝置設定中建立螢幕鎖。',
        AppUnlockMode.biometric =>
          '鎖定後以指紋或臉部驗證；取消或失敗時可改以螢幕鎖，不必輸入復原金鑰。',
      };
}

/// 備份 / 還原 / 匯入 / 匯出在設定頁不可用時的說明（空字串表示可用）。
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
      '請先解鎖日記庫，才能備份、還原或匯入 / 匯出。';
  static const String needsRecoveryKeyMessage =
      '請先建立復原金鑰，才能備份、還原或匯入 / 匯出。';
}

abstract final class SettingsImportExportCopy {
  static const String sectionTitle = '匯入與匯出';
  static const String sectionDescriptionEnabled =
      '可從其他 App 匯入日記，或將日記匯出成檔案。'
      '支援 Markdown、HTML 與 Easy Diary 備份。';

  static const String importNoEntriesMessage =
      '找不到可匯入的日記，請確認檔案格式。';

  static const String importAllSkippedMessage =
      '所選檔案皆無法匯入（格式不符、內容空白，或 Easy Diary 加密日記）。';

  static const String importFailureZipNoEntries =
      'zip 內找不到可匯入的 Markdown、HTML 或 Easy Diary 完整備份。';

  static const String importFailureEasyDiaryUnsupportedPlatform =
      'Easy Diary 備份目前僅支援在 Android 上匯入。';

  static const String importFailureEasyDiaryRealmReadFailed =
      '無法讀取 Easy Diary 備份，可能版本不相容。'
      '請在 Easy Diary 重新建立備份後再試。';

  static const String importFailureEasyDiaryEmptyBackup =
      'Easy Diary 備份檔內沒有可匯入的日記。';

  static const String importFailureEasyDiaryAllEncrypted =
      'Easy Diary 備份內的日記皆為加密狀態，無法匯入。';

  static String messageForFailureCode(String? failureCode) {
    return switch (failureCode) {
      PortableImportFailureCode.zipNoEntries => importFailureZipNoEntries,
      PortableImportFailureCode.easyDiaryUnsupportedPlatform =>
        importFailureEasyDiaryUnsupportedPlatform,
      PortableImportFailureCode.easyDiaryRealmReadFailed =>
        importFailureEasyDiaryRealmReadFailed,
      PortableImportFailureCode.easyDiaryEmptyBackup => importFailureEasyDiaryEmptyBackup,
      PortableImportFailureCode.easyDiaryAllEncrypted => importFailureEasyDiaryAllEncrypted,
      _ => '',
    };
  }

  static const String importProgress = '正在匯入日記，請稍候…';

  static const String exportButton = '匯出日記';
  static const String importButton = '匯入日記';
  static const String exportProgress = '正在匯出日記，整理內容與附件中…';

  static String exportSuccess(String path) => '已匯出：$path';
  static String importSuccess(int count) => '已匯入 $count 篇日記。';
  static String importSuccessWithSkippedFiles(int count, int skippedFiles) =>
      '已匯入 $count 篇日記，$skippedFiles 個檔案無法解析。';
  static String importSuccessWithSkippedAttachments(int count, int skippedAttachments) =>
      '已匯入 $count 篇日記，$skippedAttachments 張圖片無法匯入。';
  static String importSuccessWithSkippedFilesAndAttachments(
    int count,
    int skippedFiles,
    int skippedAttachments,
  ) =>
      '已匯入 $count 篇日記，$skippedFiles 個檔案無法解析，'
      '$skippedAttachments 張圖片無法匯入。';
}

abstract final class SettingsLocalBackupCopy {
  static const String sectionTitle = '本機備份與還原';
  static String get sectionDescriptionEnabled =>
      '建立完整備份並存於本機，還原會覆蓋目前日記。'
      '（本機最多保留 ${VaultBackupPolicy.retainCount} 份）';

  static const String createButton = '建立本機備份';
  static const String restoreButton = '從本機備份還原';
  static const String exportToExternalButton = '匯出備份到資料夾';
  static const String importFromExternalButton = '匯入外部備份';
  static const String pickDialogTitle = '選擇本機備份';
  static const String pickExternalBackupDialogTitle =
      VaultBackupPolicy.pickBackupFileDialogTitle;
  static const String noBackups = '目前沒有本機備份。';
  static const String deleteBackupTooltip = '刪除備份';
  static const String deleteConfirmTitle = '刪除本機備份？';

  static String backupSuccessInApp(String fileName) => '已建立本機備份：$fileName';
  static String backupExportSuccess(String fileName) => '已匯出備份：$fileName';
  static String backupInspectFailed(String message) => '備份檢查未通過。\n$message';
  static String deleteBackupSuccess(String fileName) => '已刪除本機備份：$fileName';
  static String deleteConfirmBody(String fileName) =>
      '將刪除 $fileName。此動作不會影響目前日記庫。';
}

abstract final class SettingsDriveBackupCopy {
  static const String sectionTitle = 'Google Drive 備份與還原';
  static const String sectionDescriptionEnabled =
      '連結 Google Drive 後，可上傳備份到雲端，或從雲端還原。';
  static const String sectionDescriptionOAuthNotConfigured =
      '此版本尚未設定 Google 登入，暫無法使用雲端備份。';

  static const String connectButton = '連結 Google Drive';
  static const String reconnectButton = '重新連結 Google Drive';
  static const String uploadButton = '上傳備份到 Google Drive';
  static const String restoreButton = '從 Google Drive 備份還原';
  static const String downloadProgress = '正在從 Google Drive 下載備份…';
  static String get retainHint =>
      'Google Drive 會自動保留最新 ${VaultBackupPolicy.retainCount} 份 zip 備份。';

  static String connectedHint(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return '已連結 Google Drive，可上傳或還原備份。';
    }
    return '已連結 Google Drive：$accountLabel，可上傳或還原備份。';
  }
  static const String disconnectedHint = '尚未連結 Google Drive，請先完成 Google 登入與授權。';
  static const String actionsLockedHint = '請先解鎖日記庫並建立復原金鑰。';

  static String connectSuccess(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return 'Google Drive 已連結。';
    }
    return 'Google Drive 已連結：$accountLabel';
  }

  static String reconnectSuccess(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return '已重新連結 Google Drive。';
    }
    return '已重新連結 Google Drive：$accountLabel';
  }
  static const String uploadSuccess = '備份已上傳到 Google Drive。';
  static const String noBackups = 'Google Drive 中找不到 zip 備份檔。';
  static const String pickDialogTitle = '選擇 Google Drive 備份';
  static const String unknownCreatedTime = '無建立時間';
}

abstract final class SettingsRestoreDialogCopy {
  static const String confirmLocalTitle = '還原本機備份？';
  static const String confirmDriveTitle = '還原 Google Drive 備份？';
  static String driveFileLine(String name) => '檔案：$name';

  static const String recoveryKeyDialogTitle = '輸入備份復原金鑰';
  static const String recoveryKeyEmptyError = '請輸入復原金鑰。';
  static const String recoveryKeyVerifyNote =
      '金鑰正確才會開始還原；錯誤則不會覆寫本機資料。';

  static const String subtitleRotatedBackup =
      '此備份在更新復原金鑰之前建立。'
      '請輸入建立該備份時保存的舊金鑰，不是目前這把新金鑰。';
  static const String subtitleSameVaultManual =
      '本機無法自動解鎖此備份。'
      '請輸入建立此備份時保存的復原金鑰。';
  static const String subtitleOtherVault =
      '此備份來自其他裝置。'
      '請輸入建立此備份時保存的復原金鑰。';
}

abstract final class SettingsRestoreBulletCopy {
  static const String overwriteWarning = '將以備份內容覆蓋本機日記，現有資料無法復原。';
  static const String rebuildIndex = '搜尋索引會在解鎖後重新建立。';
  static const String backupWithoutRecovery =
      '此備份尚未建立復原金鑰，還原後請重新建立。';
  static const String rotatedBackup =
      '此備份在更新復原金鑰之前建立。'
      '還原後請輸入建立該備份時保存的舊復原金鑰，不是目前這把新金鑰。';
  static const String trustedAutoUnlock =
      '若備份與本機使用同一把復原金鑰，還原後通常可直接使用。';
  static const String trustedAutoUnlockFallback =
      '若無法直接解鎖，請輸入建立此備份時保存的復原金鑰。';
  static const String recoveryKeyAfterRestore =
      '還原後需輸入建立此備份時保存的復原金鑰。';
  static const String rewrapNote = '還原後首次解鎖可能需要較久，請保持 App 開啟。';
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

/// 索引重建與 Google Drive 連線進度文案。
abstract final class SettingsIndexCopy {
  static const String readyMessage = '可隨時重建，讓搜尋恢復正常。';
  static const String lockedMessage = '解鎖後可重建搜尋索引。';
  static const String lockedOverviewMessage = lockedMessage;
  static const String connectDriveProgress = '正在連結 Google Drive…';
  static const String reconnectDriveProgress = '正在重新連結 Google Drive…';

  static String rebuildCompleted(int entryCount, String finishedAt) =>
      '最近重建完成：$entryCount 篇日記，$finishedAt。';

  static String rebuildSuccess(int entryCount, String duration) =>
      '搜尋索引已重建：$entryCount 篇日記，耗時 $duration';
}

/// 設定「贊助」子頁文案（對齊 Google Play Billing 用語）。
abstract final class SettingsSupportCopy {
  static const String navButtonLabel = '贊助';
  static const String pageTitle = '贊助開發';

  static const String heroTitle = '支持開發者';
  static const String heroBody =
      '純粹支持，不會解鎖任何額外功能。'
      '有支持、沒支持，App 功能完全一樣。';

  static const String statusCardTitle = '作者還懶得把這段做完';
  static const String statusCardBody =
      'Google Play 一次性支持流程還在待辦清單裡。'
      '這頁先占位，避免讓人誤以為付費能換取功能。';

  static const String complianceCardTitle = '付款與隱私';
  static const String complianceCardBody = LegalDisclosures.billingSupportPageBody;

  static const String purchaseButtonLabel = '尚未開放';
  static const String purchaseHint =
      '開放後會在此顯示 Google Play 價格與購買。';
  static const String billingProductDescription =
      '一次性支持開發者，不解鎖任何額外功能。';
}
