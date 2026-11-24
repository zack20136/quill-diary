import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';

Future<PendingAttachment> stagePickedImage({
  required EditorDraftStore draftStore,
  required ImageCompressPreset preset,
  required String draftKey,
  required String sourcePath,
  required UnlockedVaultSession session,
}) async {
  final String name = p.basename(sourcePath);
  final original = await readPickedAttachmentFile(
    sourcePath,
    fileName: name,
    isImage: true,
  );
  final compressed = sniffKnownMediaMimeType(original) == 'image/gif'
      ? null
      : await _compressImage(sourcePath, preset);
  final String fileName = compressed == null ? name : _jpegFileName(name);
  final String relativePath = await draftStore.stagePendingBytes(
    draftKey,
    compressed ?? original,
    fileName,
    session,
  );
  return PendingAttachment(
    assetId: generateAssetId(),
    encryptedDraftSource: (
      draftKey: draftKey,
      path: await draftStore.pendingAbsolutePath(draftKey, relativePath),
    ),
    pendingRelativePath: relativePath,
    mimeType: mimeTypeFromFileName(fileName),
    originalFilename: fileName,
  );
}

Future<List<int>?> _compressImage(
  String sourcePath,
  ImageCompressPreset preset,
) async {
  final int? quality = preset.quality;
  final int? minWidth = preset.minWidth;
  final int? minHeight = preset.minHeight;
  if (quality == null || minWidth == null || minHeight == null) return null;

  try {
    final compressed = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    return compressed?.isNotEmpty == true ? compressed : null;
  } on Object {
    return null;
  }
}

String _jpegFileName(String fileName) {
  final String base = p.basenameWithoutExtension(fileName);
  if (base.isEmpty) {
    return 'image.jpg';
  }
  return '$base.jpg';
}
