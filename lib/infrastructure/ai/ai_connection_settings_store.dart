import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/app_identifiers.dart';
import '../../domain/ai/ai_connection_settings.dart';

class AiConnectionSettingsStore {
  AiConnectionSettingsStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
            ),
          );
  final FlutterSecureStorage _storage;

  String _apiKeyStorageKey(AiConnectionConfig connectionConfig) =>
      connectionConfig.provider.hasCustomUrl
      ? 'connection_key_${base64Url.encode(utf8.encode(connectionConfig.credentialId))}'
      : 'key_${connectionConfig.provider.name}';

  Future<AiConnectionSettings> read() async {
    final value = await _storage.read(key: 'settings');
    return value == null
        ? const AiConnectionSettings()
        : AiConnectionSettings.fromJson(
            (jsonDecode(value) as Map).cast<String, dynamic>(),
          );
  }

  Future<void> save(AiConnectionSettings settings) async {
    await _storage.write(key: 'settings', value: jsonEncode(settings.toJson()));
  }

  Future<String> readApiKey(AiConnectionConfig connectionConfig) async {
    return await _storage.read(key: _apiKeyStorageKey(connectionConfig)) ?? '';
  }

  Future<void> saveApiKey(
    AiConnectionConfig connectionConfig,
    String apiKey,
  ) async {
    if (connectionConfig.provider.hasCustomUrl &&
        connectionConfig.effectiveBaseUrl.isEmpty) {
      if (apiKey.trim().isNotEmpty) {
        throw const FormatException('金鑰缺少服務網址');
      }
      return;
    }
    if (apiKey.trim().isEmpty) {
      await _storage.delete(key: _apiKeyStorageKey(connectionConfig));
    } else {
      await _storage.write(
        key: _apiKeyStorageKey(connectionConfig),
        value: apiKey.trim(),
      );
    }
  }
}
