final class BackupPickListItem {
  const BackupPickListItem({
    required this.id,
    required this.createdAtLabel,
    required this.fileName,
    this.sizeLabel,
    this.onDelete,
  });

  final String id;
  final String createdAtLabel;
  final String fileName;
  final String? sizeLabel;
  final Future<void> Function()? onDelete;
}
