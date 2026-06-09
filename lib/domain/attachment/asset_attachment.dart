import '../shared/value_objects.dart';

/// Metadata for an encrypted attachment stored beside a diary entry.
///
/// The actual bytes live under the vault `assets/` tree; this model is the
/// index/front-matter view used by UI, backup, and restore flows.
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
