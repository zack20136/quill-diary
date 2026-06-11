import '../shared/value_objects.dart';

/// 儲存在日記條目旁的加密附件中繼資料。
///
/// 實際位元組位於 vault `assets/` 樹下；此模型為 UI、備份與還原流程
/// 使用的索引／前置資訊視圖。
class AssetAttachment {
  const AssetAttachment({
    required this.id,
    required this.entryId,
    required this.mimeType,
    required this.safeFilename,
    required this.byteSize,
    required this.createdAt,
    required this.sha256,
    this.originalFilename,
    this.width,
    this.height,
  });

  final AssetId id;
  final EntryId entryId;
  final String mimeType;
  final String? originalFilename;
  final String safeFilename;
  final int? width;
  final int? height;
  final int byteSize;
  final DateTime createdAt;
  final String sha256;

  AssetAttachment copyWith({
    AssetId? id,
    EntryId? entryId,
    String? mimeType,
    String? originalFilename,
    String? safeFilename,
    int? width,
    int? height,
    int? byteSize,
    DateTime? createdAt,
    String? sha256,
  }) {
    return AssetAttachment(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      mimeType: mimeType ?? this.mimeType,
      originalFilename: originalFilename ?? this.originalFilename,
      safeFilename: safeFilename ?? this.safeFilename,
      width: width ?? this.width,
      height: height ?? this.height,
      byteSize: byteSize ?? this.byteSize,
      createdAt: createdAt ?? this.createdAt,
      sha256: sha256 ?? this.sha256,
    );
  }
}
