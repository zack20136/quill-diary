import '../../infrastructure/security/app_unlock_mode.dart';
import '../../infrastructure/storage/restore_precheck.dart';
import '../../infrastructure/storage/shared/portable_import_result.dart';

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
  static const String statusPreparing = '正在準備中…';
  static const String statusUnlocked = '安全鎖已解除，可以正常使用。';
  static const String statusFatalError = '初始化失敗，請稍後再試。';

  static const String unlockingWaitHint =
      '若等候過久，可能是驗證視窗被擋住。可取消後改用手動驗證。';
  static const String cancelUnlockButton = '取消並改用手動驗證';
  static const String unlockWithRecoveryButton = '使用復原金鑰解鎖';
  static const String recoveryUnlockHint =
      '輸入復原金鑰以重新解鎖本機日記庫。';
  static const String retryVerificationButton = '重新驗證';
}

abstract final class SettingsRecoveryKeyCopy {
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

abstract final class SettingsSecurityOverviewCopy {
  static const String sectionTitle = '安全狀態';
  static const String sectionDescription = '集中檢查復原金鑰、解鎖方式與索引狀態。';

  static const String recoveryKeyTitle = '復原金鑰';
  static const String recoveryKeyReady = '已建立，可用於還原與換機。';
  static const String recoveryKeyMissing = '尚未建立，資料還原能力不足。';

  static const String unlockStatusTitle = '解鎖狀態';
  static const String unlockStatusUnlocked = '日記庫目前已解鎖。';
  static const String unlockStatusLocked = '需要重新驗證後才能執行維護動作。';

  static const String unlockModeTitle = '解鎖方式';
  static const String trustedDeviceTitle = '可信裝置';
  static const String trustedDeviceReady = '此裝置可使用目前解鎖方式。';
  static const String trustedDeviceMissing = '此裝置尚未具備可信解鎖資料。';

  static const String indexTitle = '索引資料庫';

  static const String createRecoveryKeyButton = '建立復原金鑰';
  static const String rotateRecoveryKeyButton = '更新復原金鑰';
  static const String rebuildIndexButton = '重建索引';
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
  static const String sectionDescription =
      'App 在背景一段時間後回到前景時，要如何重新驗證身分以進入日記庫。';
  static const String needsRecoveryKeyBanner = '請先建立復原金鑰，才能設定解鎖方式。';

  static const String segmentNone = '無';
  static const String segmentDeviceLock = '螢幕鎖';
  static const String segmentBiometric = '生物驗證';

  static const String biometricNeedsDeviceLockHint =
      '須已登錄至少一種生物辨識，並設定裝置螢幕鎖；驗證取消或失敗時，可改以螢幕鎖解鎖，不必輸入復原金鑰。';

  static const String unlockModeChangeCancelled = '已取消變更，解鎖方式維持不變。';

  static const String unlockModeChangeAuthFailed = '驗證失敗，解鎖方式維持不變。';
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
      '匯出 Markdown 壓縮檔；可匯入 Markdown、HTML 或 Easy Diary 備份 zip。';

  static const String importNoEntriesMessage =
      '找不到可匯入的日記，請確認檔案格式。';

  static const String importAllSkippedMessage =
      '所選檔案皆無法匯入（格式不符、內容空白，或 Easy Diary 加密日記）。';

  static const String importFailureZipNoEntries =
      'zip 內找不到可匯入的 Markdown、本 App HTML 或 Easy Diary 完整備份。';

  static const String importFailureEasyDiaryUnsupportedPlatform =
      'Easy Diary 完整備份 zip 目前僅支援在 Android 裝置上匯入；'
      '請改用 Android 版 App。';

  static const String importFailureEasyDiaryRealmReadFailed =
      '無法讀取 Easy Diary 備份資料庫（可能版本不相容）。'
      '請在 Easy Diary 重新建立完整備份後再試。';

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

  static const String exportButton = '匯出 Markdown';
  static const String importButton = '匯入日記';
  static const String exportProgress = '正在匯出 Markdown，整理內容與附件中…';

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
  static const String sectionDescriptionEnabled =
      '將整個加密日記庫封裝為 .jbackup；建立後會立即檢查檔案結構。'
      '還原會覆寫本機日記庫。';

  static const String createButton = '建立並檢查備份';
  static const String restoreButton = '從本機備份還原';

  static String createSuccess(String path) => '備份已建立並通過檢查。\n位置：$path';
}

abstract final class SettingsDriveBackupCopy {
  static const String sectionTitle = 'Google Drive 備份與還原';
  static const String sectionDescriptionEnabled =
      '連結 Google Drive 後，可上傳 .jbackup 到雲端，或從雲端挑選備份還原。';
  static const String sectionDescriptionOAuthNotConfigured =
      '尚未完成 Google 登入設定（OAuth）。';

  static const String connectButton = '連結 Google Drive';
  static const String reconnectButton = '重新連結 Google Drive';
  static const String uploadButton = '上傳備份到 Google Drive';
  static const String restoreButton = '從 Google Drive 備份還原';

  static String connectedHint(String? accountLabel) {
    if (accountLabel == null || accountLabel.trim().isEmpty) {
      return '已連結 Google Drive，可上傳或還原備份。';
    }
    return '已連結 Google Drive：$accountLabel，可上傳或還原備份。';
  }
  static const String disconnectedHint = '尚未連結 Google Drive，請先完成 Google 登入與授權。';
  static const String actionsLockedHint = '要使用雲端備份與還原，請先解鎖日記庫並建立復原金鑰。';

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
  static const String noBackups = 'Google Drive 中找不到 .jbackup 備份檔。';
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

/// 設定「說明」子頁文案。
abstract final class SettingsAboutCopy {
  static const String pageTitle = '說明';

  static const String tabOverview = '概覽';
  static const String tabData = '資料與備份';
  static const String tabSecurity = '安全';

  static const List<String> overviewChips = <String>[
    '僅 Android',
    'LDJ2',
    '全文搜尋',
    '標籤目錄',
  ];

  static const String overviewHeroTitle = 'QuillLockDiary';
  static const String overviewHeroBody =
      '離線優先的 Android 加密日記。內容在本機加密存放，除非你主動備份或匯出，不會自動上傳明文。';

  static const String featuresSectionTitle = '主要功能';
  static const String featuresSectionSubtitle = '解鎖日記庫後可使用。';
  static const String featuresHomeTitle = '首頁';
  static const String featuresHomeBody =
      '時間軸、日曆、標籤管理與回顧總覽，快速找到過往日記。';
  static const String featuresEditorTitle = '編輯器';
  static const String featuresEditorBody =
      'Markdown 日記、附件、標籤與自訂顯示色；儲存後同步更新搜尋索引。';
  static const String featuresSearchTitle = '全文搜尋';
  static const String featuresSearchBody =
      '解鎖期間，標題、標籤或內文只要包含關鍵字就能找到。';

  static const String platformSectionTitle = '平台限制';
  static const String platformSectionBody = '目前僅支援 Android，無法在其他平台建立或使用加密日記庫。';

  static const String tagCatalogSectionTitle = '標籤目錄';
  static const String tagCatalogSectionSubtitle = '名稱與自訂顯示色保存在日記庫內，含尚未套用的標籤。';
  static const String tagCatalogFileLabel = '保存位置';
  static const String tagCatalogFileBody =
      '日記庫內的 tag_styles.json，含預設標籤與未使用標籤。';
  static const String tagCatalogSyncLabel = '更新時機';
  static const String tagCatalogSyncBody =
      '編輯儲存、匯入日記、標籤管理與備份還原時更新；搜尋索引僅快取自訂顯示色。';

  static const String backupSectionTitle = '完整備份';
  static const String backupSectionSubtitle = '封裝整個加密日記庫，不是解密後的明文。';
  static const String backupLocalLabel = '本機備份';
  static const String backupLocalBody =
      '匯出 .jbackup 壓縮檔，含加密日記、附件、復原設定與標籤目錄；不含搜尋索引（還原後重建）。';
  static const String backupDriveLabel = 'Google 雲端硬碟';
  static const String backupDriveBody = '上傳至應用程式專用資料夾；還原流程與本機 .jbackup 相同。';
  static const String backupRestoreAfterLabel = '還原後';
  static const String backupRestoreAfterBody =
      '搜尋索引清除並重建，本應用程式重新啟動與解鎖；標籤目錄自 tag_styles.json 載入。';

  static const String portableSectionTitle = '可攜式匯入／匯出';
  static const String portableSectionSubtitle =
      '設定頁的 Markdown／HTML 流程；逐篇寫入加密日記庫，不走 .jbackup 還原。';
  static const String portableExportLabel = '匯出';
  static const String portableExportBody =
      'Markdown 壓縮檔（解密後 .md 與附件），或本應用程式 HTML（可再次匯入）。';
  static const String portableImportLabel = '匯入';
  static const String portableImportBody =
      '支援本應用程式 Markdown／HTML、Easy Diary 完整備份（僅 Android；加密日記略過）。';

  static const List<String> securityChips = <String>[
    'LDJ2',
    'AES-256-GCM',
    'Argon2id',
    '本機儲存',
    '本機受信任裝置',
    '復原金鑰',
  ];

  static const String securityHeroTitle = '本機加密，預設離線';
  static const String securityHeroBody =
      '日記、附件與設定在本機加密後寫入日記庫；除非你主動備份或匯出，不會自動傳到外部。';

  static const String securityFlowSectionTitle = '加密與解密流程';
  static const String securityFlowSectionSubtitle = '五個步驟理解資料如何被保護。';
  static const String securityFlowStep1Title = '1. 寫下內容';
  static const String securityFlowStep1Body = '日記或附件先在裝置上處理，尚未寫成可讀明文。';
  static const String securityFlowStep2Title = '2. 產生檔案金鑰';
  static const String securityFlowStep2Body = '每個加密檔各有一組隨機金鑰，互不共用。';
  static const String securityFlowStep3Title = '3. AES-256-GCM 加密';
  static const String securityFlowStep3Body =
      '內容加密為 LDJ2 格式，並附完整性驗證，避免被悄悄竄改。';
  static const String securityFlowStep4Title = '4. 寫入日記庫';
  static const String securityFlowStep4Body =
      '本機保存加密檔、復原設定與搜尋索引，不是可讀的日記明文。';
  static const String securityFlowStep5Title = '5. 解密前先取回檔案金鑰';
  static const String securityFlowStep5Body = '須先取得檔案金鑰才能解開內容，通常走下列其中一條路徑。';
  static const String securityFlowTrustedTitle = '本機受信任裝置';
  static const String securityFlowTrustedBadge = '優先';
  static const String securityFlowTrustedBody = '若本機仍保有受信任狀態，會優先嘗試此路徑。';
  static const String securityFlowRecoveryTitle = '復原金鑰';
  static const String securityFlowRecoveryBadge = '備援';
  static const String securityFlowRecoveryBody =
      '若本機受信任裝置不可用，改以復原金鑰推導包裝金鑰後解開。';

  static const String securityHighlightsSectionTitle = '安全性重點';
  static const String securityHighlightsSectionSubtitle = '加密方式、保護範圍與適用邊界。';
  static const String securityHighlightEncryptTitle = '加密方式';
  static const String securityHighlightEncryptBody =
      '每筆日記或附件先產生檔案金鑰，再以 AES-256-GCM 加密為 LDJ2 格式。';
  static const String securityHighlightScopeTitle = '保護範圍';
  static const String securityHighlightScopeBody =
      '資料預設只在裝置上；取得加密檔也無法直接讀出，除非有金鑰。';
  static const String securityHighlightLimitTitle = '風險邊界';
  static const String securityHighlightLimitBody =
      '若裝置已取得 root 權限、遭惡意程式控制，或記憶體被讀取，保護會受限；復原金鑰須另行妥善保存。';

  static const String securityBackupSectionTitle = '備份與解鎖';
  static const String securityBackupSectionSubtitle = '備份仍是加密資料；還原後須能驗證身分才能解鎖。';
  static const String securityBackupEncryptedLabel = '備份性質';
  static const String securityBackupEncryptedBody =
      '本機 .jbackup 與 Google 雲端硬碟備份都是加密日記庫，不是明文日記。';
  static const String securityBackupUnlockLabel = '可沿用本機解鎖';
  static const String securityBackupUnlockBody =
      '同裝置、同日記庫、同一代復原金鑰，且本機仍有受信任狀態時，才可能免輸入金鑰。';
  static const String securityBackupOtherLabel = '其他情況';
  static const String securityBackupOtherBody =
      '條件不符時，須輸入建立該備份時保存的復原金鑰，才能完成還原後解鎖。';

  static const String securityRecoverySectionTitle = '復原金鑰';
  static const String securityRecoverySectionSubtitle = '最終備援，不能省略。';
  static const String securityRecoveryRoleTitle = '用途';
  static const String securityRecoveryRoleBody =
      '不直接加密日記，而是透過 Argon2id 推導包裝金鑰，用來保護檔案金鑰。';
  static const String securityRecoveryDeviceTitle = '與本機受信任裝置的關係';
  static const String securityRecoveryDeviceBody =
      '本機受信任裝置只是方便日常解鎖，不能取代復原金鑰。';
  static const String securityRecoveryRotateTitle = '更新金鑰後';
  static const String securityRecoveryRotateBody =
      '若曾更新復原金鑰，較早的備份可能仍須當時那把舊金鑰才能還原。';

  static const String securityLimitsSectionTitle = '使用提醒';
  static const String securityLimitsSectionSubtitle = '實務上最容易誤解的地方。';
  static const String securityLimitBackupLabel = '備份';
  static const String securityLimitBackupBody = '有備份仍需要復原金鑰；還原時可能須驗證金鑰。';
  static const String securityLimitKeyLabel = '金鑰保存';
  static const String securityLimitKeyBody = '復原金鑰建議離線保存，勿與手機或備份檔放在同一處。';
  static const String securityLimitVerifyLabel = '生物／螢幕鎖驗證';
  static const String securityLimitVerifyBody =
      '僅影響本機受信任裝置的解鎖體驗，不能取代復原金鑰。';
}

/// 設定「贊助」子頁文案（對齊 Google Play Billing 用語）。
abstract final class SettingsSupportCopy {
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
  static const String complianceCardBody =
      '開放後僅透過 Google Play Billing 收款，為一次性支持、非訂閱、非會員。'
      '本頁不讀取 vault，也不影響日記內容。';

  static const String purchaseButtonLabel = '尚未開放';
  static const String purchaseHint =
      '開放後會在此顯示 Google Play 價格與購買。';
  static const String billingProductDescription =
      '一次性支持開發者，不解鎖任何額外功能。';
}
