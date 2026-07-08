import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/infrastructure/storage/editor_draft_store.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';

typedef PreparedImageFile = ({String path, String mimeType, String fileName});

Future<PendingAttachment?> stagePickedImage({
  required EditorDraftStore draftStore,
  required ImageCompressPreset preset,
  required String draftKey,
  required String sourcePath,
  required String displayName,
  required UnlockedVaultSession session,
}) async {
  final String trimmed = sourcePath.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final PreparedImageFile prepared = await compressImageIfNeeded(
    sourcePath: trimmed,
    displayName: displayName,
    preset: preset,
  );

  try {
    final String relativePath = await draftStore.stagePendingFile(
      draftKey,
      prepared.path,
      session,
    );
    final String previewPath = await draftStore
        .materializePendingFileForPreview(draftKey, relativePath, session);
    return PendingAttachment(
      sourcePath: previewPath,
      pendingRelativePath: relativePath,
      mimeType: prepared.mimeType,
      originalFilename: prepared.fileName,
    );
  } finally {
    if (prepared.path != trimmed) {
      final File tempFile = File(prepared.path);
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }
}

Future<PreparedImageFile> compressImageIfNeeded({
  required String sourcePath,
  required String displayName,
  required ImageCompressPreset preset,
}) async {
  final String trimmedPath = sourcePath.trim();
  final String trimmedName = displayName.trim().isEmpty
      ? p.basename(trimmedPath)
      : displayName.trim();

  if (preset == ImageCompressPreset.original || await _isGifFile(trimmedPath)) {
    return (
      path: trimmedPath,
      mimeType: _mimeTypeFromPath(trimmedPath),
      fileName: trimmedName,
    );
  }

  final int? quality = preset.quality;
  final int? minWidth = preset.minWidth;
  final int? minHeight = preset.minHeight;
  if (quality == null || minWidth == null || minHeight == null) {
    return (
      path: trimmedPath,
      mimeType: _mimeTypeFromPath(trimmedPath),
      fileName: trimmedName,
    );
  }

  final String tempPath = p.join(
    Directory.systemTemp.path,
    'quill_diary_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );

  try {
    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      trimmedPath,
      tempPath,
      minWidth: minWidth,
      minHeight: minHeight,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (compressed == null || !File(compressed.path).existsSync()) {
      return (
        path: trimmedPath,
        mimeType: _mimeTypeFromPath(trimmedPath),
        fileName: trimmedName,
      );
    }

    return (
      path: compressed.path,
      mimeType: 'image/jpeg',
      fileName: _jpegFileName(trimmedName),
    );
  } on Object {
    final File fallbackTemp = File(tempPath);
    if (fallbackTemp.existsSync()) {
      await fallbackTemp.delete();
    }
    return (
      path: trimmedPath,
      mimeType: _mimeTypeFromPath(trimmedPath),
      fileName: trimmedName,
    );
  }
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

String _mimeTypeFromPath(String pathValue) {
  switch (p.extension(pathValue).toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.png':
      return 'image/png';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    default:
      return 'application/octet-stream';
  }
}
