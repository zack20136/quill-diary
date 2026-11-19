import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/preferences/personalization_preferences.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/shared/media_type_utils.dart';

typedef _PreparedImageFile = ({String path, String fileName});

Future<PendingAttachment> stagePickedImage({
  required EditorDraftStore draftStore,
  required ImageCompressPreset preset,
  required String draftKey,
  required String sourcePath,
  required UnlockedVaultSession session,
}) async {
  final _PreparedImageFile prepared = await _compressImage(sourcePath, preset);

  try {
    final String relativePath = await draftStore.stagePendingFile(
      draftKey,
      prepared.path,
      session,
      fileName: prepared.fileName,
      isImage: true,
    );
    final String previewPath = await draftStore
        .materializePendingFileForPreview(draftKey, relativePath, session);
    return PendingAttachment(
      assetId: generateAssetId(),
      sourcePath: previewPath,
      pendingRelativePath: relativePath,
      mimeType: mimeTypeFromFileName(prepared.fileName),
      originalFilename: prepared.fileName,
    );
  } finally {
    if (prepared.path != sourcePath) {
      final File tempFile = File(prepared.path);
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }
}

Future<_PreparedImageFile> _compressImage(
  String sourcePath,
  ImageCompressPreset preset,
) async {
  final String name = p.basename(sourcePath);
  final _PreparedImageFile original = (path: sourcePath, fileName: name);
  final int? quality = preset.quality;
  final int? minWidth = preset.minWidth;
  final int? minHeight = preset.minHeight;
  if (quality == null ||
      minWidth == null ||
      minHeight == null ||
      await _isGifFile(sourcePath)) {
    return original;
  }

  final String tempPath = p.join(
    Directory.systemTemp.path,
    'quill_diary_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );

  try {
    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      tempPath,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (compressed != null && await File(compressed.path).exists()) {
      return (path: compressed.path, fileName: _jpegFileName(name));
    }
  } on Object {
    // 轉檔失敗時使用原檔。
  }
  final File temporaryOutput = File(tempPath);
  if (await temporaryOutput.exists()) {
    await temporaryOutput.delete();
  }
  return original;
}

Future<bool> _isGifFile(String path) async {
  final File file = File(path);
  if (!file.existsSync()) {
    return false;
  }
  final List<int> header = await file.openRead(0, 6).first;
  if (header.length < 6) {
    return false;
  }
  final String signature = String.fromCharCodes(header.sublist(0, 6));
  return signature == 'GIF87a' || signature == 'GIF89a';
}

String _jpegFileName(String fileName) {
  final String base = p.basenameWithoutExtension(fileName);
  if (base.isEmpty) {
    return 'image.jpg';
  }
  return '$base.jpg';
}
