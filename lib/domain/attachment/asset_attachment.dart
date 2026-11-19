import 'dart:typed_data';

import 'package:quill_diary/domain/shared/value_objects.dart';

final class AttachmentFormatMismatchException implements Exception {
  const AttachmentFormatMismatchException(this.fileName);

  final String fileName;
}

enum AttachmentSizeLimit {
  file(25),
  image(10);

  const AttachmentSizeLimit(this.megabytes);

  final int megabytes;

  void checkLength(int bytes, String fileName) {
    if (bytes > megabytes * 1000000) {
      throw AttachmentTooLargeException(fileName, this);
    }
  }
}

final class AttachmentTooLargeException implements Exception {
  const AttachmentTooLargeException(this.fileName, this.limit);

  final String fileName;
  final AttachmentSizeLimit limit;
}

/// 儲存在日記條目旁的加密附件中繼資料。
///
/// 實際位元組位於日記庫 `assets/` 樹下；此模型為 UI、備份與還原流程
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

class PendingAttachment {
  PendingAttachment({
    required this.assetId,
    this.bytes,
    this.sourcePath,
    this.encryptedDraftSource,
    this.pendingRelativePath,
    required this.mimeType,
    required this.originalFilename,
  }) : assert(
         (bytes != null && bytes.isNotEmpty) ||
             (sourcePath != null && sourcePath.trim().isNotEmpty) ||
             encryptedDraftSource != null,
         'PendingAttachment 需要 bytes 或來源路徑',
       );

  final AssetId assetId;

  /// 內嵌或已讀入記憶體的附件（例如 HTML 資料 URI）。
  final Uint8List? bytes;

  /// 暫時明文路徑（materialize 後供預覽與正式儲存讀取）。
  final String? sourcePath;

  final ({String draftKey, String path})? encryptedDraftSource;

  /// 加密 pending 附件在草稿目錄下的相對路徑（例如 `pending/*.enc`）。
  final String? pendingRelativePath;
  final String mimeType;
  final String originalFilename;
}
