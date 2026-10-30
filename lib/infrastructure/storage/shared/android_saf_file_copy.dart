import 'dart:io';

import 'package:flutter/services.dart';

/// Android SAF：將本機檔案串流複製到使用者授權的資料夾樹。
abstract final class AndroidSafFileCopy {
  static const MethodChannel _channel = MethodChannel(
    'quill_diary/saf_file_copy',
  );

  /// 透過 [DocumentsContract.createDocument] 寫入 [treeUri]，回傳新檔 content URI。
  static Future<String> copyFileToTree({
    required String treeUri,
    required File sourceFile,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final String? result = await _channel.invokeMethod<String>(
        'copyFileToTree',
        <String, String>{
          'treeUri': treeUri,
          'sourcePath': sourceFile.absolute.path,
          'fileName': fileName,
          'mimeType': mimeType,
        },
      );
      if (result == null || result.trim().isEmpty) {
        throw const AndroidSafWriteException();
      }
      return result;
    } on PlatformException catch (error) {
      throw AndroidSafWriteException(code: error.code);
    }
  }
}

String mimeTypeForExportFileName(String fileName) {
  switch (fileName.toLowerCase().split('.').last) {
    case 'zip':
      return 'application/zip';
    case 'html':
    case 'htm':
      return 'text/html';
    default:
      return 'application/octet-stream';
  }
}

final class AndroidSafWriteException implements Exception {
  const AndroidSafWriteException({this.code});
  final String? code;
}
