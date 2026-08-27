import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'easy_diary_realm_entry.dart';
import 'package:path/path.dart' as p;

import '../../../../domain/shared/value_objects.dart';
import '../../shared/media_type_utils.dart';
import '../../vault_repository.dart';

/// Easy Diary 將相片存成 `Photos/{uuid}`（常無副檔名），需索引並嗅探 MIME。
class EasyDiaryPhotoIndex {
  EasyDiaryPhotoIndex._(this._byLookupKey);

  final Map<String, File> _byLookupKey;

  static EasyDiaryPhotoIndex scan(Directory photosDirectory) {
    final Map<String, File> byKey = <String, File>{};
    if (!photosDirectory.existsSync()) {
      return EasyDiaryPhotoIndex._(byKey);
    }

    for (final FileSystemEntity entity in photosDirectory.listSync(
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final String fileName = p.basename(entity.path);
      if (fileName.isEmpty || fileName.startsWith('.')) {
        continue;
      }
      byKey[fileName.toLowerCase()] = entity;
      final String stem = p.basenameWithoutExtension(fileName).toLowerCase();
      if (stem.isNotEmpty) {
        byKey.putIfAbsent(stem, () => entity);
      }
    }
    return EasyDiaryPhotoIndex._(byKey);
  }

  /// Kotlin 端已正規化為檔名鍵；保留 `content:` 防禦性略過。
  File? resolve(String photoKey) {
    final String trimmed = photoKey.trim();
    if (trimmed.isEmpty || trimmed.startsWith('content:')) {
      return null;
    }

    final File? direct = _byLookupKey[trimmed.toLowerCase()];
    if (direct != null) {
      return direct;
    }

    final String stem = p.basenameWithoutExtension(trimmed).toLowerCase();
    if (stem.isNotEmpty) {
      return _byLookupKey[stem];
    }
    return null;
  }
}

String _resolveEasyDiaryImageMimeType({
  required List<int> bytes,
  required String? realmMimeType,
  required String fileNameHint,
}) {
  final String? detected = sniffKnownMediaMimeType(bytes);
  if (detected != null && detected.startsWith('image/')) return detected;

  final String realmHint = realmMimeType?.trim().toLowerCase() ?? '';
  if (realmHint.startsWith('image/') &&
      attachmentContentMatchesMimeType(bytes, realmHint)) {
    return realmHint;
  }

  final String fileNameHintMimeType = mimeTypeFromFileName(fileNameHint);
  if (fileNameHintMimeType.startsWith('image/') &&
      attachmentContentMatchesMimeType(bytes, fileNameHintMimeType)) {
    return fileNameHintMimeType;
  }
  return 'application/octet-stream';
}

/// Flutter／Skia 能否解碼此圖片；檔頭合法但內容截斷、或 HEIC 等會回傳 false。
Future<bool> canDecodeImageBytes(List<int> bytes) async {
  if (bytes.isEmpty) {
    return false;
  }
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      Uint8List.fromList(bytes),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    frame.image.dispose();
    codec.dispose();
    return true;
  } on Object {
    return false;
  }
}

final RegExp _uuidOnlyLinePattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// 移除內文中僅含相片 UUID 的占位行（附件已另存）。
String stripEasyDiaryPhotoPlaceholderLines(
  String contents,
  Set<String> importedPhotoKeys,
) {
  if (contents.trim().isEmpty || importedPhotoKeys.isEmpty) {
    return contents;
  }

  final Set<String> normalizedKeys = importedPhotoKeys
      .map((String key) => p.basename(key).toLowerCase())
      .toSet();
  final List<String> lines = contents.split('\n');
  final List<String> kept = <String>[];
  for (final String line in lines) {
    final String trimmed = line.trim();
    if (_uuidOnlyLinePattern.hasMatch(trimmed) &&
        normalizedKeys.contains(trimmed.toLowerCase())) {
      continue;
    }
    kept.add(line);
  }
  return kept.join('\n').trimRight();
}

class ResolvedEasyDiaryAttachments {
  const ResolvedEasyDiaryAttachments({
    required this.attachments,
    required this.skippedAttachments,
    required this.importedPhotoKeys,
  });

  final List<PendingAttachment> attachments;
  final int skippedAttachments;
  final Set<String> importedPhotoKeys;
}

Future<ResolvedEasyDiaryAttachments> resolveEasyDiaryPhotoAttachments({
  required List<EasyDiaryPhotoRef> photos,
  required EasyDiaryPhotoIndex photoIndex,
}) async {
  final List<PendingAttachment> attachments = <PendingAttachment>[];
  final Set<String> seen = <String>{};
  final Set<String> importedPhotoKeys = <String>{};
  var skippedAttachments = 0;

  for (final EasyDiaryPhotoRef photo in photos) {
    final File? photoFile = photoIndex.resolve(photo.photoKey);
    if (photoFile == null) {
      skippedAttachments++;
      continue;
    }

    final String dedupeKey = photoFile.path.toLowerCase();
    if (!seen.add(dedupeKey)) {
      continue;
    }

    final List<int> bytes = await photoFile.readAsBytes();
    final String mimeType = _resolveEasyDiaryImageMimeType(
      bytes: bytes,
      realmMimeType: photo.mimeType,
      fileNameHint: photoFile.path,
    );
    if (!mimeType.startsWith('image/') || !await canDecodeImageBytes(bytes)) {
      skippedAttachments++;
      continue;
    }

    final String storedName = p.basename(photoFile.path);
    final String extension = extensionFromMimeType(mimeType);
    attachments.add(
      PendingAttachment(
        assetId: generateAssetId(),
        sourcePath: photoFile.path,
        mimeType: mimeType,
        originalFilename:
            p.extension(storedName).isNotEmpty || extension == 'bin'
            ? storedName
            : '$storedName.$extension',
      ),
    );
    importedPhotoKeys.add(photo.photoKey);
  }

  return ResolvedEasyDiaryAttachments(
    attachments: attachments,
    skippedAttachments: skippedAttachments,
    importedPhotoKeys: importedPhotoKeys,
  );
}

DateOnly entryDateFromEasyDiaryRealm(String? dateString, DateTime fallback) {
  final String? trimmed = dateString?.trim();
  if (trimmed != null && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
    return DateOnly.parse(trimmed);
  }
  return DateOnly.fromDateTime(fallback);
}
