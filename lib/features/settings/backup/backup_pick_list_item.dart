/// 還原清單對話框的單列顯示資料。
final class BackupPickListItem {
  const BackupPickListItem({
    required this.id,
    required this.createdAtLabel,
    required this.fileName,
    this.sizeLabel,
    this.onDelete,
  });

  /// 呼叫端用來對應回 [LocalBackupFile] 或 [DriveBackupFile] 的唯一識別。
  final String id;
  final String createdAtLabel;
  final String fileName;
  final String? sizeLabel;
  final Future<void> Function()? onDelete;
}
