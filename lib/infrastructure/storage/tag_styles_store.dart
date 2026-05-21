import 'dart:convert';
import 'dart:io';

import 'vault_path_strategy.dart';

/// Persists tag accent colors under [vault/tag_styles.json] so they survive
/// backup/restore (the encrypted index DB is not included in `.jbackup`).
class TagStylesStore {
  TagStylesStore(this._pathStrategy);

  final VaultPathStrategy _pathStrategy;

  static const int schemaVersion = 1;

  Future<String> _filePath() async {
    final Directory vaultRoot = await _pathStrategy.vaultRootDirectory();
    return '${vaultRoot.path}${Platform.pathSeparator}tag_styles.json';
  }

  Future<Map<String, int>> read() async {
    final File file = File(await _filePath());
    if (!file.existsSync()) {
      return <String, int>{};
    }
    try {
      final Object? decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return <String, int>{};
      }
      final Object? accents = decoded['accents'];
      if (accents is! Map<String, Object?>) {
        return <String, int>{};
      }
      final Map<String, int> result = <String, int>{};
      for (final MapEntry<String, Object?> entry in accents.entries) {
        final int? argb = _parseArgb(entry.value);
        if (argb != null) {
          result[entry.key] = argb;
        }
      }
      return result;
    } on Object {
      return <String, int>{};
    }
  }

  Future<void> write(Map<String, int> accents) async {
    final File file = File(await _filePath());
    await file.parent.create(recursive: true);
    final Map<String, Object?> payload = <String, Object?>{
      'version': schemaVersion,
      'accents': <String, int>{
        for (final MapEntry<String, int> entry in accents.entries) entry.key: entry.value,
      },
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  /// Later map entries override earlier keys.
  static Map<String, int> merge(
    Map<String, int> base,
    Map<String, int> overlay,
  ) {
    if (base.isEmpty) {
      return Map<String, int>.from(overlay);
    }
    if (overlay.isEmpty) {
      return Map<String, int>.from(base);
    }
    return <String, int>{...base, ...overlay};
  }

  int? _parseArgb(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
