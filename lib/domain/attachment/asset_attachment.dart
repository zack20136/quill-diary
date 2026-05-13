import '../shared/value_objects.dart';

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
}
