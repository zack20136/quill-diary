import 'dart:io';

import 'package:flutter/services.dart';

import 'package:quill_diary/shared/app_identifiers.dart';

/// Android MediaStore：儲存相片至 Pictures/quill-diary。
abstract final class MediaStoreExport {
  static const MethodChannel _channel = MethodChannel(
    AppIdentifiers.mediaStoreExportChannel,
  );

  static Future<String> saveImageToPictures({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('僅 Android 支援儲存至 Pictures。');
    }
    try {
      final String? savedName = await _channel.invokeMethod<String>(
        'saveImageToPictures',
        <String, Object>{
          'bytes': bytes,
          'fileName': fileName,
          'mimeType': mimeType,
        },
      );
      if (savedName == null || savedName.trim().isEmpty) {
        throw StateError('無法儲存圖片至相簿。');
      }
      return savedName.trim();
    } on PlatformException catch (error) {
      final String message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        throw StateError(message);
      }
      throw StateError('無法儲存圖片至相簿（${error.code}）。');
    }
  }
}
