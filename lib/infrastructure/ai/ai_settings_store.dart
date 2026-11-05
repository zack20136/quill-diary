import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_model_thinking_override.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/app_identifiers.dart';
import 'package:quill_diary/shared/data_versions.dart';

/// 加密 AI 設定（`vault/ai_settings.json.enc`）與裝置上的 API 金鑰。
class AiSettingsStore {
  AiSettingsStore({
    required VaultPathStrategy pathStrategy,
    required CryptoService cryptoService,
    required VaultRepository repository,
    FlutterSecureStorage? keyStorage,
  }) : this._(pathStrategy, cryptoService, repository, keyStorage);

  /// 只供未接上日記庫的測試使用，例如金鑰往返與記憶體假 store。
  @visibleForTesting
  AiSettingsStore.detached({FlutterSecureStorage? keyStorage})
    : this._(null, null, null, keyStorage);

  AiSettingsStore._(
    this._pathStrategy,
    this._cryptoService,
    this._repository,
    FlutterSecureStorage? keyStorage,
  ) : _keys =
          keyStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
            ),
          );

  static const String documentId = 'ai_settings';
  static const String _legacyConnectionKey = 'settings';
  static const String _legacyChatKey = 'chat_diary_settings';

  final VaultPathStrategy? _pathStrategy;
  final CryptoService? _cryptoService;
  final VaultRepository? _repository;
  final FlutterSecureStorage _keys;
  bool _legacySettled = false;

  Future<AiStoredSettings> read(UnlockedVaultSession session) {
    return _vault.runVaultMutation(() async {
      await ensureStored(session);
      return _readFile(session);
    });
  }

  /// 只更新有效連線與模型。提示詞與人物隱藏沿用日記庫裡已存的值。
  Future<void> updateActiveConnection(
    UnlockedVaultSession session,
    AiConnectionConfig next,
  ) async {
    final AiStoredSettings current = await read(session);
    await save(
      session,
      current.copyWith(
        connection: AiConnectionSettings(
          activeConnectionId: next.connectionId,
          connections: {
            ...current.connection.connections,
            next.connectionId: next,
          },
        ),
      ),
    );
  }

  Future<void> save(UnlockedVaultSession session, AiStoredSettings settings) {
    return _vault.runVaultMutation(() async {
      await _writeFile(session, settings);
      await _deleteLegacySettings();
    });
  }

  /// 把升級前放在安全儲存的設定搬進 vault。檔案已存在時以檔案為準。
  ///
  /// 呼叫端若已持有 vault 修改序列，不要再包一層 [VaultRepository.runVaultMutation]。
  Future<void> ensureStored(UnlockedVaultSession session) async {
    final File file = await _settingsFile();
    await recoverFileReplacement(file);
    if (file.existsSync()) {
      await _deleteLegacySettings();
      return;
    }
    if (_legacySettled) return;
    final String? legacyConnection = await _keys.read(
      key: _legacyConnectionKey,
    );
    final String? legacyChat = await _keys.read(key: _legacyChatKey);
    if (legacyConnection == null && legacyChat == null) {
      _legacySettled = true;
      return;
    }
    final legacy = _parseLegacyChat(legacyChat);
    await _writeFile(
      session,
      AiStoredSettings(
        connection: _parseConnection(legacyConnection),
        hidePersonNames: legacy.hidePersonNames,
        chatDiaryPrompts: legacy.prompts,
      ),
    );
    await _deleteLegacySettings();
  }

  Future<String> readApiKey(AiConnectionConfig connectionConfig) async {
    return await _keys.read(key: _apiKeyStorageKey(connectionConfig)) ?? '';
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
    final String storageKey = _apiKeyStorageKey(connectionConfig);
    if (apiKey.trim().isEmpty) {
      await _keys.delete(key: storageKey);
    } else {
      await _keys.write(key: storageKey, value: apiKey.trim());
    }
  }

  VaultRepository get _vault =>
      _repository ?? (throw StateError('AI 設定儲存尚未接上日記庫。'));

  Future<File> _settingsFile() async {
    final VaultPathStrategy? paths = _pathStrategy;
    if (paths == null) {
      throw StateError('AI 設定儲存尚未接上日記庫。');
    }
    return File(await paths.aiSettingsPath());
  }

  CryptoService get _crypto =>
      _cryptoService ?? (throw StateError('AI 設定儲存尚未接上日記庫。'));

  Future<void> _deleteLegacySettings() async {
    if (_legacySettled) return;
    await _keys.delete(key: _legacyConnectionKey);
    await _keys.delete(key: _legacyChatKey);
    _legacySettled = true;
  }

  Future<AiStoredSettings> _readFile(UnlockedVaultSession session) async {
    final File file = await _settingsFile();
    await recoverFileReplacement(file);
    if (!file.existsSync()) return const AiStoredSettings();
    final ParsedEncryptedDocument parsed = _crypto.parseFileBytes(
      await file.readAsBytes(),
    );
    if (parsed.header.vaultId != session.vaultId) {
      throw const FormatException('AI 設定不屬於目前的日記庫。');
    }
    final List<int> plain = await _crypto.decryptBytes(
      headerBytes: parsed.headerBytes,
      ciphertextBytes: parsed.ciphertextBytes,
      context: vaultDecryptionContext(session),
    );
    final Object? decoded = jsonDecode(utf8.decode(plain));
    if (decoded is! Map) {
      throw const FormatException('AI 設定格式不正確。');
    }
    final Object? version = decoded['version'];
    // 提示詞覆寫與頂層人物隱藏都是第 1 版的可選形狀；舊檔把開關留在
    // chat_diary，缺少整理覆寫代表使用內建。讀取都不因此改寫。
    if (version is! int || version != DataVersions.aiSettings) {
      throw const FormatException('AI 設定版本不支援。');
    }
    const requiredKeys = <String>{'version', 'connection'};
    const allowedKeys = <String>{
      'version',
      'connection',
      'hide_people',
      'chat_diary',
      'diary_organization',
    };
    if (decoded.length < requiredKeys.length ||
        !requiredKeys.every(decoded.containsKey) ||
        !decoded.keys.every(allowedKeys.contains)) {
      throw const FormatException('AI 設定欄位不正確。');
    }
    final Object? connection = decoded['connection'];
    final Object? chatDiary = decoded['chat_diary'];
    final Object? organization = decoded['diary_organization'];
    if (connection is! Map ||
        (decoded.containsKey('chat_diary') && chatDiary is! Map) ||
        (decoded.containsKey('diary_organization') && organization is! Map)) {
      throw const FormatException('AI 設定格式不正確。');
    }
    final AiConnectionSettings raw = AiConnectionSettings.fromJson(
      connection.cast<String, dynamic>(),
      adoptCatalog: false,
    );
    final ({AiConnectionSettings settings, bool writeBack}) adopted =
        adoptConnectionCatalog(raw);
    final Map<String, dynamic>? chat = chatDiary is Map
        ? chatDiary.cast<String, dynamic>()
        : null;
    final AiStoredSettings stored = AiStoredSettings(
      connection: adopted.settings,
      hidePersonNames: _hidePersonNames(decoded, chat),
      chatDiaryPrompts: chat == null
          ? const AiPromptOverrides()
          : _promptsFromJson(chat),
      organizationPrompts: organization is Map
          ? _promptsFromJson(organization.cast<String, dynamic>())
          : const AiPromptOverrides(),
    );
    if (!adopted.writeBack &&
        aiJsonEquals(connection, adopted.settings.toJson())) {
      return stored;
    }
    await _writeFile(session, stored);
    return stored;
  }

  Future<void> _writeFile(
    UnlockedVaultSession session,
    AiStoredSettings settings,
  ) async {
    final RecoveryMetadata metadata =
        await _vault.readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    if (metadata.vaultId != session.vaultId) {
      throw StateError('目前 session 與 vault 資料不一致。');
    }
    final DateTime now = DateTime.now();
    final Map<String, Object?>? chatPrompts = _promptJson(
      settings.chatDiaryPrompts,
    );
    final Map<String, Object?>? organizationPrompts = _promptJson(
      settings.organizationPrompts,
    );
    final Uint8List plainBytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'version': DataVersions.aiSettings,
          'connection': settings.connection.toJson(),
          'hide_people': settings.hidePersonNames,
          'chat_diary': ?chatPrompts,
          'diary_organization': ?organizationPrompts,
        }),
      ),
    );
    final EncryptionResult encrypted = await _crypto.encryptBytes(
      documentId: documentId,
      vaultId: metadata.vaultId,
      plaintextBytes: plainBytes,
      contentType: 'application/json',
      recoveryWrapKey: requireRecoveryWrapKey(session),
      recoverySlotKdf: metadata.kdf,
      createdAt: now,
      updatedAt: now,
    );
    await replaceFileBytesRecoverably(
      await _settingsFile(),
      encrypted.toFileBytes(),
    );
  }

  String _apiKeyStorageKey(AiConnectionConfig connectionConfig) =>
      connectionConfig.provider.hasCustomUrl
      ? 'connection_key_${base64Url.encode(utf8.encode(connectionConfig.credentialId))}'
      : 'key_${connectionConfig.provider.name}';

  AiConnectionSettings _parseConnection(String? raw) {
    if (raw == null) return const AiConnectionSettings();
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return const AiConnectionSettings();
      return AiConnectionSettings.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      return const AiConnectionSettings();
    }
  }

  ({bool hidePersonNames, AiPromptOverrides prompts}) _parseLegacyChat(
    String? raw,
  ) {
    const empty = (hidePersonNames: true, prompts: AiPromptOverrides());
    if (raw == null) return empty;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return empty;
      return _chatFields(decoded.cast<String, dynamic>());
    } on Object {
      return empty;
    }
  }

  ({bool hidePersonNames, AiPromptOverrides prompts}) _chatFields(
    Map<String, dynamic> json,
  ) => (
    hidePersonNames: json['hide_people'] as bool? ?? true,
    prompts: _promptsFromJson(json),
  );

  bool _hidePersonNames(
    Map<dynamic, dynamic> json,
    Map<String, dynamic>? chat,
  ) {
    final Object? top = json['hide_people'];
    if (top is bool) return top;
    if (top != null) throw const FormatException('AI 設定格式不正確。');
    final Object? nested = chat?['hide_people'];
    if (nested is bool) return nested;
    if (nested != null) throw const FormatException('AI 設定格式不正確。');
    return true;
  }

  AiPromptOverrides _promptsFromJson(Map<String, dynamic> json) =>
      AiPromptOverrides(
        conversationOverride: json['conversation_prompt_override'] as String?,
        generationOverride: json['generation_prompt_override'] as String?,
      );

  Map<String, Object?>? _promptJson(AiPromptOverrides prompts) {
    final Map<String, Object?> json = {
      if (prompts.conversationOverride != null)
        'conversation_prompt_override': prompts.conversationOverride,
      if (prompts.generationOverride != null)
        'generation_prompt_override': prompts.generationOverride,
    };
    return json.isEmpty ? null : json;
  }
}
