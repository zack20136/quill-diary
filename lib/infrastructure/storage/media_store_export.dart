import 'dart:io';

import 'package:flutter/services.dart';

import 'package:quill_diary/app/app_identifiers.dart';

/// Android MediaStore：Pictures / Download 下的 quill-diary 子資料夾。
abstract final class MediaStoreExport {
  static const MethodChannel _channel = MethodChannel(
    AppIdentifiers.mediaStoreExportChannel,
  );

  /// 若尚不存在，於 Download/quill-diary 建立 marker 檔（scoped storage）。
  static Future<void> ensureDownloadsSubfolder() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('ensureDownloadsSubfolder');
    } on Object {
      // 匯出流程仍可改走 SAF 選資料夾。
    }
  }

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
