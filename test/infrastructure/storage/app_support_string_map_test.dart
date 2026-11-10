import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/security/app_unlock_mode.dart';
import 'package:quill_diary/infrastructure/storage/shared/app_support_string_map.dart';

void main() {
  late Directory directory;
  late File file;
  late AppSupportStringMap store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'quill_preferences_test_',
    );
    file = File('${directory.path}/preferences.json');
    store = AppSupportStringMap(
      fileName: 'preferences.json',
      storageFile: file,
    );
  });
  tearDown(() => directory.delete(recursive: true));

  for (final previous in [false, true]) {
    test('主檔缺失時復原${previous ? '舊副本並忽略未提交暫存' : '唯一暫存'}，保留鎖定模式與其他偏好', () async {
      final expected = {
        'app_lock.unlock_mode': AppUnlockMode.biometric.storageValue,
        'other': '原本的設定',
      };
      await File('${file.path}${previous ? '.previous' : '.tmp'}')
          .writeAsString(jsonEncode(expected));
      if (previous) await File('${file.path}.tmp').writeAsString('{未完成');
      final loaded = await store.load();
      expect(loaded, expected);
      expect(
        AppUnlockModeStorage.fromStorage(loaded['app_lock.unlock_mode']),
        AppUnlockMode.biometric,
      );
      await store.update({'other': '更新的設定'});
      final reopened = AppSupportStringMap(
        fileName: 'preferences.json',
        storageFile: file,
      );
      expect(await reopened.load(), {...expected, 'other': '更新的設定'});
      expect(File('${file.path}.previous').existsSync(), isFalse);
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });
  }

  for (final invalid in ['{損毀', '[]']) {
    test('主檔內容為 $invalid 時拒絕讀寫，不採用或刪除舊副本', () async {
      await file.writeAsString(invalid);
      final backup = File('${file.path}.previous');
      const previous = '{"app_lock.unlock_mode":"biometric"}';
      await backup.writeAsString(previous);
      await expectLater(store.load(), throwsFormatException);
      await expectLater(store.update({'theme': '新值'}), throwsFormatException);
      expect(await file.readAsString(), invalid);
      expect(await backup.readAsString(), previous);
    });
  }

  test('寫入失敗不污染快取，後續更新仍保留原設定並能繼續保存', () async {
    await store.update({'theme': '原值'});
    final before = await store.load();
    expect(() => before['theme'] = '外部修改', throwsUnsupportedError);
    final blocked = Directory('${file.path}.tmp');
    await blocked.create();
    await expectLater(
      store.update({'theme': '失敗的新值'}),
      throwsA(isA<FileSystemException>()),
    );
    expect(await store.load(), before);
    await blocked.delete();
    await store.update({'locale': '新語系'});
    expect(await store.load(), {'theme': '原值', 'locale': '新語系'});
    expect(jsonDecode(await file.readAsString()), await store.load());
  });
}
