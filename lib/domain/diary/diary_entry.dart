import '../shared/value_objects.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.vaultId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    required this.markdownBody,
    this.title,
    this.tags = const <String>[],
    this.attachmentIds = const <AssetId>[],
    this.mood,
    this.isDeleted = false,
  });

  final EntryId id;
  final VaultId vaultId;
  final String? title;
  final DateOnly date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final String? mood;
  final String markdownBody;
  final List<AssetId> attachmentIds;
  final bool isDeleted;
}
