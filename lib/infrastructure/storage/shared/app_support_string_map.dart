import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

/// App Support 裡的字串 map。寫入使用可復原取代，避免中斷時留下半份檔案。
class AppSupportStringMap {
  AppSupportStringMap({required this.fileName, File? storageFile})
    : _storageFileOverride = storageFile;

  final String fileName;
  final File? _storageFileOverride;
  Map<String, String>? _cache;
  Future<void> _pending = Future.value();

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, String>> load() => _run(_load);

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    final File file = await _storageFile();
    Map<String, String> values = const {};
    await recoverFileReplacement(
      file,
      validate: (candidate) async {
        final Object? decoded = jsonDecode(await candidate.readAsString());
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('偏好設定必須是 JSON 物件');
        }
        values = Map.unmodifiable(
          decoded.map(
            (String key, dynamic value) => MapEntry(key, value.toString()),
          ),
        );
      },
    );
    _cache = values;
    return _cache!;
  }

  Future<void> update(Map<String, String> values) {
    final snapshot = Map<String, String>.of(values);
    return _run(() async {
      final next = {...await _load(), ...snapshot};
      await atomicWriteString(
        await _storageFile(),
        const JsonEncoder.withIndent('  ').convert(next),
      );
      _cache = Map.unmodifiable(next);
    });
  }

  Future<File> _storageFile() async {
    final File? override = _storageFileOverride;
    if (override != null) return override;
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(
      p.join(supportDir.path, AppIdentifiers.appStorageDirectory, fileName),
    );
  }
}
