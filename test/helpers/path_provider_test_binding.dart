import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 將 path_provider 暫存目錄導向測試用 [tempDir]。
void installPathProviderTestBinding(Directory tempDir) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async {
      if (call.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      return null;
    },
  );
}

/// 清除 path_provider 測試 mock。
void clearPathProviderTestBinding() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    null,
  );
}
