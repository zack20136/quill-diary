/// 可攜式匯入失敗原因（穩定識別碼，UI 文案見 AppLocalizations settingsImportExport*）。
abstract final class PortableImportFailureCode {
  static const String zipNoEntries = 'zip_no_entries';
  static const String easyDiaryUnsupportedPlatform =
      'easy_diary_unsupported_platform';
  static const String easyDiaryRealmReadFailed = 'easy_diary_realm_read_failed';
  static const String easyDiaryEmptyBackup = 'easy_diary_empty_backup';
  static const String easyDiaryAllEncrypted = 'easy_diary_all_encrypted';
}

/// 可攜式匯入（資料夾或 zip 解壓後）的統計結果。
class PortableImportResult {
  const PortableImportResult({
    required this.importedEntries,
    required this.skippedFiles,
    this.skippedAttachments = 0,
    this.failureCode,
    this.failureMessage,
  });

  /// 成功寫入日記庫的篇數。
  final int importedEntries;

  /// 整份檔案無法解析、空白略過、或加密日記略過的次數。
  final int skippedFiles;

  /// 附件參考無法解碼或找不到本機檔案的次數。
  final int skippedAttachments;

  /// 匯入失敗或無法完成時的穩定識別碼。
  final String? failureCode;

  /// 過渡用完整訊息；新程式碼應優先使用 [failureCode]。
  final String? failureMessage;
}
