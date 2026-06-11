import '../shared/value_objects.dart';

/// 加解密前後的標準日記內容模型。
///
/// 儲存層將此模型編碼為含前置資訊的 Markdown 後再加密文件；
/// 搜尋索引衍生自這些欄位。
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
    );
  }
}
