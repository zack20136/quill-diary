/// 可攜式匯入（資料夾或 zip 解壓後）的統計結果。
class PortableImportResult {
  const PortableImportResult({
    required this.importedEntries,
    required this.skippedFiles,
    this.skippedAttachments = 0,
    this.failureMessage,
  });

  /// 成功寫入日記庫的篇數。
  final int importedEntries;

  /// 整份檔案無法解析或無有效段落而略過的次數。
  final int skippedFiles;

  /// 附件參考無法解碼或找不到本機檔案的次數。
  final int skippedAttachments;

  /// 匯入失敗或無法完成時的說明（例如不支援的平台、Realm 不相容）。
  final String? failureMessage;
}
