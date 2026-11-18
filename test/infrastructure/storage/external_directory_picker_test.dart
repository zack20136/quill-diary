import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/shared/external_directory_picker.dart';

void main() {
  late FilePickerPlatform previous;

  setUp(() {
    previous = FilePickerPlatform.instance;
  });

  tearDown(() {
    FilePickerPlatform.instance = previous;
  });

  test('file URI 轉回不含結尾分隔符的資料夾路徑', () async {
    final directory = await Directory.systemTemp.createTemp(
      'external_directory_picker_',
    );
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    FilePickerPlatform.instance = _FixedDirectoryPicker(
      Uri.directory(directory.path),
    );

    final String? picked = await ExternalDirectoryPicker.pickExternalDirectory(
      prompt: '選資料夾',
      initialDirectory: directory.path,
    );

    expect(picked, p.normalize(directory.path));
    expect(picked, isNot(endsWith(p.separator)));
  });

  test('content URI 原樣回傳，取消則為 null', () async {
    const String treeUri =
        'content://com.android.externalstorage.documents/tree/primary%3ADownload';
    FilePickerPlatform.instance = _FixedDirectoryPicker(Uri.parse(treeUri));

    expect(
      await ExternalDirectoryPicker.pickExternalDirectory(prompt: '選資料夾'),
      treeUri,
    );

    FilePickerPlatform.instance = _FixedDirectoryPicker(null);
    expect(
      await ExternalDirectoryPicker.pickExternalDirectory(prompt: '選資料夾'),
      isNull,
    );
  });
}

final class _FixedDirectoryPicker extends FilePickerPlatform {
  _FixedDirectoryPicker(this.directory);

  final Uri? directory;

  @override
  Future<Uri?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return directory;
  }
}
