import '../../domain/shared/vault_backup_policy.dart';
import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/security/unlock_mode_policy.dart';
import '../session/session_messages.dart';
import '../session/state/app_session_state.dart';
import '../session/session_timeout_policy.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../infrastructure/storage/shared/portable_import_result.dart';
import '../../infrastructure/storage/backup_task_progress.dart';
import '../../shared/copy/common_copy.dart';

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

/// 備份、還原與 Google Drive 傳輸進度文案。
abstract final class SettingsBackupTaskProgressCopy {
  static const String startingAfterRestore = '正在啟動還原後的日記庫…';

  static String label(BackupTaskProgress progress) {
    final String base = switch (progress.phase) {
      BackupTaskPhase.creatingBackup => '正在建立備份…',
      BackupTaskPhase.copyingBackup => '正在寫入備份…',
      BackupTaskPhase.uploadingDrive => '正在上傳到 Google Drive…',
      BackupTaskPhase.downloadingDrive => '正在從 Google Drive 下載…',
      BackupTaskPhase.restoringBackup => '正在還原備份，請勿關閉應用程式…',
      BackupTaskPhase.startingAfterRestore => startingAfterRestore,
    };
    final double? fraction = progress.fraction;
    if (fraction == null) {
      return base;
    }
    return '$base ${(fraction * 100).round()}%';
  }
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
  static const String recoveryKeyMissing = '尚未建立，請先建立後再備份或匯出。';
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

  /// 區塊說明；[sessionTimeout] 取自個人化設定的自動鎖定時間。
  static String sectionDescription(Duration sessionTimeout) =>
      '${SettingsSessionTimeoutCopy.backgroundLockExplanation(sessionTimeout)}'
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

/// 自動鎖定（背景逾時）相關說明文案。
abstract final class SettingsSessionTimeoutCopy {
  static String backgroundLockExplanation(Duration timeout) =>
      'App 放在背景超過 ${sessionBackgroundTimeoutLabel(timeout)} 會自動鎖定；如果只是短時間切換 App，通常不會。';

  static String aboutBackgroundTimeoutBody(Duration timeout) =>
      '${backgroundLockExplanation(timeout)}'
      '你可以在個人化頁調整成 1 / 3 / 5 / 10 分鐘。'
      '若正在備份、還原或匯入匯出，會先暫停自動鎖定；等你回來後，再依目前的解鎖方式重新驗證。';
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
  static String get sectionDescriptionEnabled =>
      '連結 Google 帳號後，可上傳備份到雲端或從雲端還原，還原會覆蓋目前日記。'
      '（雲端最多保留 ${VaultBackupPolicy.retainCount} 份）';

  static const String sectionDescriptionOAuthNotConfigured =
      '此版本尚未設定 Google 登入，暫無法使用雲端備份。';

  static const String linkButton = '連結 Google 帳號';
  static const String switchAccountButton = '切換帳號';
  static const String disconnectButton = '中斷連結';
  static const String uploadButton = '備份到 Google Drive';
  static const String restoreButton = '從 Google Drive 還原';

  static const String disconnectedLabel = '尚未連結 Google 帳號';
  static const String fallbackAccountLabel = 'Google 帳號';
  static String linkSuccess(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return 'Google 帳號已連結，可以開始備份或還原。';
    }
    return 'Google 帳號已連結：$accountLabel';
  }

  static String switchAccountSuccess(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return '已切換 Google 帳號。';
    }
    return '已切換為 $accountLabel';
  }

  static const String disconnectSuccess =
      '已中斷 Google 帳號連線，雲端備份仍會保留。';
  static const String disconnectConfirmTitle = '中斷 Google 帳號連線？';
  static const String disconnectConfirmBody =
      '中斷後需重新連結才能備份或還原。雲端上的備份檔不會被刪除。';

  static String uploadSuccess(String fileName) => '已備份到 Google Drive：$fileName';
  static String backupInspectFailed(String message) => '雲端備份未完成。\n$message';
  static const String noBackups = 'Google Drive 目前沒有可用備份，請先建立一份。';
  static const String pickDialogTitle = '選擇 Google Drive 備份';
  static const String unknownCreatedTime = '無建立時間';
  static const String deleteBackupTooltip = '刪除備份';
  static const String deleteConfirmTitle = '刪除 Google Drive 備份？';

  static String deleteBackupSuccess(String fileName) =>
      '已從 Google Drive 刪除：$fileName';
  static String deleteConfirmBody(String fileName) =>
      '將刪除 $fileName。此動作不會影響目前日記庫。';
  static String restoreSuccess(String fileName) => '已從 Google Drive 還原：$fileName';
}

/// 還原完成後的 SnackBar 文案；雲端還原會附上備份檔名。
String driveAwarePostRestoreSnackBarMessage({
  required AppLockStatus status,
  String? sessionMessage,
  String? driveBackupName,
}) {
  final String statusMessage =
      snackbarMessageForPostRestore(status, sessionMessage: sessionMessage);
  if (driveBackupName == null || driveBackupName.trim().isEmpty) {
    return statusMessage;
  }
  final String driveMessage =
      SettingsDriveBackupCopy.restoreSuccess(driveBackupName.trim());
  if (status == AppLockStatus.unlocked &&
      statusMessage == kRestoreSuccessUnlockedMessage) {
    return driveMessage;
  }
  return '$driveMessage\n$statusMessage';
}

abstract final class SettingsRestoreDialogCopy {
  static const String confirmLocalTitle = '還原本機備份？';
  static const String confirmDriveTitle = '從 Google Drive 還原？';
  static String driveFileLine(String name) => '備份：$name';

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
  static const String linkDriveProgress = '正在連結 Google 帳號…';
  static const String switchDriveAccountProgress = '正在切換帳號…';
  static const String disconnectDriveProgress = '正在中斷連線…';

  static String rebuildCompleted(int entryCount, String finishedAt) =>
      '最近重建完成：$entryCount 篇日記，$finishedAt。';

  static String rebuildSuccess(int entryCount, String duration) =>
      '搜尋索引已重建：$entryCount 篇日記，耗時 $duration';
}

/// 設定「贊助」子頁文案（對齊 Google Play Billing 用語）。
abstract final class SettingsSupportCopy {
  static const String navButtonLabel = '支持';
  static const String pageTitle = '支持開發者';

  static const String heroTitle = '自願支持';
  static const String heroBody =
      '您可透過 Google Play 提供一次性支持。'
      '本項支持不附帶額外功能，亦不影響日記內容的存取與使用。';

  static const List<String> heroChips = <String>[
    '不提供額外功能',
    '可重複購買',
    'Google Play 付款',
  ];

  static const String complianceCardTitle = '付款與資料說明';
  static const String complianceCardBody =
      '付款由 Google Play 處理，屬一次性支持，非訂閱或會員方案。'
      '本應用程式不保存支持紀錄，亦不讀取日記內容。';

  static const String productsSectionTitle = '支持方案';
  static const String productsSectionBody =
      '金額與幣別由 Google Play 依所在地區顯示；各方案皆可重複支持。';
  static const String buyButtonPrefix = '支持';
  static const String recommendedTierBadge = '常用';

  static const String pendingMessage = '付款處理中，請稍候。';
  static const String thanksMessage = '感謝您的支持。';
  static const String errorMessage = '付款未完成，請稍後再試。';
  static const String billingUnavailableMessage =
      '目前無法使用 Google Play 購買功能，請於已安裝 Google Play 商店的 Android 裝置上操作。';
  static const String productLoadErrorTitle = '暫時無法載入支持方案';
  static const String productLoadErrorBody = '請稍後再試。';
  static const String productsNotReadyTitle = '暫時無法顯示支持方案';
  static const String productsNotReadyBody =
      '請確認網路連線正常；若問題持續，請更新本應用程式後再試。';
  static const String productsQueryFailedTitle = '目前無法連線至 Google Play';
  static const String productsQueryFailedBody = '請確認網路連線後再試。';
  static const String productsPartialMessage =
      '部分方案暫時無法顯示，您仍可選擇其他可用金額。';
  static const String retryLoadProductsLabel = '重新載入';
  static const String footerNote = '是否提供支持，請依您的需求自行決定。';

  static SupportNoticeCopy noticeForProductLoadError(String? errorCode) {
    return switch (errorCode) {
      'no_products' => const SupportNoticeCopy(
        title: productsNotReadyTitle,
        body: productsNotReadyBody,
      ),
      'query_failed' => const SupportNoticeCopy(
        title: productsQueryFailedTitle,
        body: productsQueryFailedBody,
      ),
      _ => const SupportNoticeCopy(
        title: productLoadErrorTitle,
        body: productLoadErrorBody,
      ),
    };
  }

  static SponsorTierCopy? tierForProduct(String productId) {
    for (final SponsorTierCopy tier in sponsorTiers) {
      if (tier.productId == productId) {
        return tier;
      }
    }
    return null;
  }

  /// 五檔梯次（由低到高；價格由 Google Play 顯示，App 不寫死）。
  /// [productId] 須與 [BillingConfig.sponsorProductIdsOrdered] 一致。
  static const List<SponsorTierCopy> sponsorTiers = <SponsorTierCopy>[
    SponsorTierCopy(
      productId: 'sponsor_coffee',
      label: '請開發者喝杯咖啡',
      hint: '支持 Quill Diary 持續開發與維護',
    ),
    SponsorTierCopy(
      productId: 'sponsor_snack',
      label: '請開發者吃點心',
      hint: '讓 Quill Diary 能繼續穩定改進',
    ),
    SponsorTierCopy(
      productId: 'sponsor_lunch',
      label: '請開發者吃午餐',
      hint: '幫助 Quill Diary 持續變得更好',
    ),
    SponsorTierCopy(
      productId: 'sponsor_boost',
      label: '大力支持',
      hint: '成為我們持續開發、維護與改善的動力',
    ),
    SponsorTierCopy(
      productId: 'sponsor_super',
      label: '大大大大大力支持',
      hint: '幫助我們更安心投入長期開發與維護',
    ),
  ];
}

/// 贊助頁簡短提示（標題 + 內文）。
class SupportNoticeCopy {
  const SupportNoticeCopy({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

/// 贊助梯次 UI 文案（與 Play 商品 ID 對應，不寫死價格）。
class SponsorTierCopy {
  const SponsorTierCopy({
    required this.productId,
    required this.label,
    required this.hint,
    this.recommended = false,
  });

  final String productId;
  final String label;
  final String hint;
  final bool recommended;
}
