import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/app_identifiers.dart';
import '../../domain/chat_diary/chat_diary_settings.dart';

class ChatDiarySettingsStore {
  ChatDiarySettingsStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
            ),
          );
  final FlutterSecureStorage _storage;
  Future<ChatDiarySettings> read() async {
    final value = await _storage.read(key: 'chat_diary_settings');
    return value == null
        ? const ChatDiarySettings()
        : ChatDiarySettings.fromJson(
            (jsonDecode(value) as Map).cast<String, dynamic>(),
          );
  }

  Future<void> save(ChatDiarySettings settings) => _storage.write(
    key: 'chat_diary_settings',
    value: jsonEncode(settings.toJson()),
  );
}
