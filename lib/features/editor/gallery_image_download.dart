import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../infrastructure/storage/media_store_export.dart';
import '../../shared/providers/core_providers.dart';
import '../session/providers/session_providers.dart';
import '../session/state/app_session_state.dart';
import 'editor_copy.dart';

enum GalleryImageSource { encrypted, local }

/// 全螢幕看圖 gallery 的單一項目。
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
  final String safeStem =
      stem.isEmpty ? 'image' : stem.replaceAll(RegExp(r'[^\w.\-]'), '_');
  return '$safeStem$ext';
}

Future<Uint8List?> loadGalleryImageBytes({
  required WidgetRef ref,
  required GalleryImageItem item,
}) async {
  switch (item.source) {
    case GalleryImageSource.local:
      final File file = File(item.path);
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsBytes();
    case GalleryImageSource.encrypted:
      final AppSessionState sessionState =
          await ref.read(effectiveAppSessionProvider.future);
      if (!sessionState.isUnlocked || sessionState.session == null) {
        return null;
      }
      return ref.read(vaultRepositoryProvider).readDecryptedAssetBytes(
            sessionState.session!,
            item.path,
          );
  }
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

void showGalleryDownloadSnackBar(
  BuildContext scaffoldMessengerContext,
  String message,
) {
  if (!scaffoldMessengerContext.mounted) {
    return;
  }
  final ScaffoldMessengerState messenger =
      ScaffoldMessenger.of(scaffoldMessengerContext);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> downloadGalleryImage({
  required WidgetRef ref,
  required BuildContext scaffoldMessengerContext,
  required GalleryImageItem item,
}) async {
  final Uint8List? bytes = await loadGalleryImageBytes(ref: ref, item: item);
  if (!scaffoldMessengerContext.mounted) {
    return;
  }
  if (bytes == null || bytes.isEmpty) {
    showGalleryDownloadSnackBar(
      scaffoldMessengerContext,
      EditorCopy.galleryDownloadFailed(scaffoldMessengerContext),
    );
    return;
  }
  final String? savedName = await saveGalleryImageToPictures(
    bytes: bytes,
    fileName: item.fileName,
    mimeType: item.mimeType,
  );
  if (!scaffoldMessengerContext.mounted) {
    return;
  }
  if (savedName == null) {
    showGalleryDownloadSnackBar(
      scaffoldMessengerContext,
      EditorCopy.galleryDownloadFailed(scaffoldMessengerContext),
    );
    return;
  }
  showGalleryDownloadSnackBar(
    scaffoldMessengerContext,
    EditorCopy.galleryDownloadSuccess(scaffoldMessengerContext, savedName),
  );
}
