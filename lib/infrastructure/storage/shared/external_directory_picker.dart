import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

/// 跨平台選擇外部資料夾；Android 走原生 SAF tree picker。
abstract final class ExternalDirectoryPicker {
  static const MethodChannel _androidChannel = MethodChannel(
    'quill_diary/directory_picker',
  );

  /// 回傳資料夾路徑或 SAF tree URI（`content://…`），取消則為 `null`。
  ///
  /// [writableOnAndroid] 為 `true` 時 Android 走原生 SAF（供寫入交付）；
  /// 為 `false` 時與桌面相同走 [FilePicker]（供匯入讀取檔案路徑）。
  static Future<String?> pickExternalDirectory({
    required String prompt,
    String? initialDirectory,
    bool writableOnAndroid = false,
  }) async {
    if (Platform.isAndroid && writableOnAndroid) {
      return _pickOnAndroid(prompt: prompt);
    }
    return FilePicker.getDirectoryPath(
      dialogTitle: prompt,
      initialDirectory: initialDirectory,
    );
  }

  static Future<String?> _pickOnAndroid({required String prompt}) async {
    try {
      final String? result = await _androidChannel.invokeMethod<String?>(
        'pickWritableDirectoryTree',
        <String, String>{'prompt': prompt},
      );
      if (result == null || result.trim().isEmpty) {
        return null;
      }
      return result.trim();
    } on PlatformException catch (error) {
      final String message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        throw StateError(message);
      }
      throw StateError('無法開啟資料夾選擇器。');
    }
  }
}
