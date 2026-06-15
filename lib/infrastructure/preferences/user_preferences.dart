import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../config/app_identifiers.dart';

/// 編輯器選圖時的圖片壓縮預設。
enum ImageCompressPreset {
  original,
  standard,
  high;

  String get storageValue => name;

  int? get quality => switch (this) {
        ImageCompressPreset.original => null,
        ImageCompressPreset.standard => 70,
        ImageCompressPreset.high => 85,
      };

  int? get minWidth => switch (this) {
        ImageCompressPreset.original => null,
        ImageCompressPreset.standard => 1280,
        ImageCompressPreset.high => 1920,
      };

  int? get minHeight => switch (this) {
        ImageCompressPreset.original => null,
        ImageCompressPreset.standard => 1280,
        ImageCompressPreset.high => 1920,
      };

  static ImageCompressPreset fromStorage(String? raw) {
    return switch (raw?.trim()) {
      'original' => ImageCompressPreset.original,
      'high' => ImageCompressPreset.high,
      'standard' || null || '' => ImageCompressPreset.standard,
      _ => ImageCompressPreset.standard,
    };
  }
}

/// 在 vault 外持久化使用者偏好（設定頁可擴充更多 key）。
class UserPreferences {
  UserPreferences({File? storageFile}) : _storageFileOverride = storageFile;

  static const String _imageCompressPresetKey = 'image_compress_preset';

  final File? _storageFileOverride;
  Map<String, String>? _cache;

  Future<ImageCompressPreset> get imageCompressPreset async {
    final String? raw = await _readValue(_imageCompressPresetKey);
    return ImageCompressPreset.fromStorage(raw);
  }

  Future<void> setImageCompressPreset(ImageCompressPreset value) async {
    await _writeValue(_imageCompressPresetKey, value.storageValue);
  }

  Future<String?> _readValue(String key) async {
    final Map<String, String> store = await _loadStore();
    return store[key];
  }

  Future<void> _writeValue(String key, String value) async {
    final Map<String, String> store = await _loadStore();
    store[key] = value;
    await _persistStore(store);
  }

  Future<Map<String, String>> _loadStore() async {
    if (_cache != null) {
      return _cache!;
    }

    final File file = await _storageFile();
    if (!file.existsSync()) {
      _cache = <String, String>{};
      return _cache!;
    }

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      _cache = decoded.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      );
    } else {
      _cache = <String, String>{};
    }
    return _cache!;
  }

  Future<void> _persistStore(Map<String, String> store) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(store),
      flush: true,
    );
    _cache = Map<String, String>.from(store);
  }

  Future<File> _storageFile() async {
    final File? override = _storageFileOverride;
    if (override != null) {
      return override;
    }
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(
      p.join(
        supportDir.path,
        AppIdentifiers.appStorageDirectory,
        'app_preferences.json',
      ),
    );
  }
}
