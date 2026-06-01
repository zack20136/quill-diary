import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Easy Diary 將相片存成 `Photos/{uuid}`（常無副檔名），需索引並嗅探 MIME。
class EasyDiaryPhotoIndex {
  EasyDiaryPhotoIndex._(this._byLookupKey);

  final Map<String, File> _byLookupKey;

  static EasyDiaryPhotoIndex scan(Directory photosDirectory) {
    final Map<String, File> byKey = <String, File>{};
    if (!photosDirectory.existsSync()) {
      return EasyDiaryPhotoIndex._(byKey);
    }

    for (final FileSystemEntity entity in photosDirectory.listSync(followLinks: false)) {
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

  File? resolve(String photoReference) {
    final String trimmed = photoReference.trim();
    if (trimmed.isEmpty || trimmed.startsWith('content:')) {
      return null;
    }

    final String fileName = p.basename(trimmed.split('?').first.split('#').first);
    if (fileName.isEmpty) {
      return null;
    }

    final File? direct = _byLookupKey[fileName.toLowerCase()];
    if (direct != null) {
      return direct;
    }

    final String stem = p.basenameWithoutExtension(fileName).toLowerCase();
    if (stem.isNotEmpty) {
      return _byLookupKey[stem];
    }
    return null;
  }
}

/// 從檔案開頭位元組判斷圖片 MIME（Easy Diary 相片常無副檔名）。
String sniffImageMimeType(Uint8List header, {String? fileNameHint}) {
  if (header.length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (header.length >= 8 &&
      header[0] == 0x89 &&
      header[1] == 0x50 &&
      header[2] == 0x4E &&
      header[3] == 0x47) {
    return 'image/png';
  }
  if (header.length >= 6 &&
      header[0] == 0x47 &&
      header[1] == 0x49 &&
      header[2] == 0x46 &&
      header[3] == 0x38) {
    return 'image/gif';
  }
  if (header.length >= 12 &&
      header[0] == 0x52 &&
      header[1] == 0x49 &&
      header[2] == 0x46 &&
      header[3] == 0x46 &&
      header[8] == 0x57 &&
      header[9] == 0x45 &&
      header[10] == 0x42 &&
      header[11] == 0x50) {
    return 'image/webp';
  }
  if (header.length >= 2 && header[0] == 0x42 && header[1] == 0x4D) {
    return 'image/bmp';
  }

  final String extension = p.extension(fileNameHint ?? '').toLowerCase();
  return switch (extension) {
    '.png' => 'image/png',
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    '.heic' => 'image/heic',
    _ => 'application/octet-stream',
  };
}

Future<Uint8List> readFileHeader(File file, {int length = 16}) async {
  final RandomAccessFile handle = await file.open();
  try {
    final Uint8List header = await handle.read(length);
    return header;
  } finally {
    await handle.close();
  }
}

String preferredImageFilename({
  required String storedName,
  required String mimeType,
}) {
  if (p.extension(storedName).isNotEmpty) {
    return storedName;
  }
  final String stem = p.basename(storedName);
  return switch (mimeType) {
    'image/jpeg' => '$stem.jpg',
    'image/png' => '$stem.png',
    'image/gif' => '$stem.gif',
    'image/webp' => '$stem.webp',
    'image/bmp' => '$stem.bmp',
    'image/heic' => '$stem.heic',
    _ => stem,
  };
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
