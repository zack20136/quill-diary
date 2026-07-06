import 'dart:io';

import 'package:flutter/services.dart';

import '../../../config/app_identifiers.dart';

/// Android：將 content:// URI 串流複製到本機暫存路徑。
abstract final class AndroidContentUriImport {
  static const MethodChannel _channel = MethodChannel(
    AppIdentifiers.contentUriImportChannel,
  );

  static Future<void> copyUriToPath({
    required String sourceUri,
    required File destinationFile,
  }) async {
    try {
      await _channel.invokeMethod<void>('copyUriToPath', <String, String>{
        'sourceUri': sourceUri,
        'destinationPath': destinationFile.absolute.path,
      });
    } on PlatformException catch (error) {
      final String message = error.message?.trim() ?? '';
      if (message.isNotEmpty) {
        throw StateError(message);
      }
      throw StateError(error.code);
    }
  }
}
