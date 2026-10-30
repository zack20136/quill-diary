import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:quill_diary/infrastructure/storage/media_store_export.dart';

enum GalleryImageSource { encrypted, local }

class GalleryImageItem {
  const GalleryImageItem.encrypted({
    required this.path,
    required this.fileName,
    required this.mimeType,
  }) : source = GalleryImageSource.encrypted;

  const GalleryImageItem.local({
    required this.path,
    required this.fileName,
    required this.mimeType,
  }) : source = GalleryImageSource.local;

  final GalleryImageSource source;
  final String path;
  final String fileName;
  final String mimeType;
}

String galleryDownloadFileName(String? rawName, String mimeType) {
  final String trimmed = rawName?.trim() ?? '';
  final String baseName = trimmed.isEmpty ? 'image' : p.basename(trimmed);
  if (p.extension(baseName).isNotEmpty) {
    return baseName.replaceAll(RegExp(r'[^\w.\-]'), '_');
  }
  final String ext = switch (mimeType.toLowerCase()) {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'image/bmp' => '.bmp',
    'image/heic' => '.heic',
    _ => '.jpg',
  };
  final String stem = p.basenameWithoutExtension(baseName);
  final String safeStem = stem.isEmpty
      ? 'image'
      : stem.replaceAll(RegExp(r'[^\w.\-]'), '_');
  return '$safeStem$ext';
}

Future<String?> saveGalleryImageToPictures({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  await MediaStoreExport.ensureDownloadsSubfolder();
  final String stampedName =
      '${DateTime.now().microsecondsSinceEpoch}_$fileName';
  try {
    return await MediaStoreExport.saveImageToPictures(
      bytes: bytes,
      fileName: stampedName,
      mimeType: mimeType.trim().isEmpty ? 'image/jpeg' : mimeType,
    );
  } on Object {
    return null;
  }
}
