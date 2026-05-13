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

  String? get normalizedTitle {
    final String? candidate = title?.trim();
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return candidate;
  }

  DiaryEntry copyWith({
    EntryId? id,
    VaultId? vaultId,
    String? title,
    bool clearTitle = false,
    DateOnly? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? mood,
    bool clearMood = false,
    String? markdownBody,
    List<AssetId>? attachmentIds,
    bool? isDeleted,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      vaultId: vaultId ?? this.vaultId,
      title: clearTitle ? null : (title ?? this.title),
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      mood: clearMood ? null : (mood ?? this.mood),
      markdownBody: markdownBody ?? this.markdownBody,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
