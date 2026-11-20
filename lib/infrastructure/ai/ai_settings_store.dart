import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/ai_stored_settings.dart';
import 'package:quill_diary/domain/persona/persona_reference.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/crypto/crypto_service.dart';
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';
import 'package:quill_diary/infrastructure/storage/vault_repository.dart';
import 'package:quill_diary/shared/app_identifiers.dart';

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

  final VaultPathStrategy? _pathStrategy;
  final CryptoService? _cryptoService;
  final VaultRepository? _repository;
  final FlutterSecureStorage _keys;

  Future<AiStoredSettings> read(UnlockedVaultSession session) =>
      _vault.runVaultMutation(() => _readFile(session));

  Future<void> updateActiveConnection(
    UnlockedVaultSession session,
    AiConnectionConfig next,
  ) {
    final snapshot = AiConnectionConfig.fromStoredJson(
      jsonDecode(jsonEncode(next.toStoredJson())) as Map<String, dynamic>,
    );
    return _vault.runVaultMutation(() async {
      final current = await _readFile(session);
      await _writeFile(
        session,
        current.copyWith(
          connection: AiConnectionSettings(
            activeConnectionId: snapshot.connectionId,
            connections: {
              ...current.connection.connections,
              snapshot.connectionId: snapshot,
            },
          ),
        ),
      );
    });
  }

  Future<void> updateAiEnabled(UnlockedVaultSession session, bool enabled) {
    return _vault.runVaultMutation(() async {
      final current = await _readFile(session);
      await _writeFile(session, current.copyWith(aiEnabled: enabled));
    });
  }

  /// 只更新下一則新聊天的夥伴，保留提示詞覆寫與連線。
  Future<void> updateSelectedPersona(
    UnlockedVaultSession session,
    PersonaReference? persona,
  ) {
    final snapshot = persona == null
        ? null
        : PersonaReference.fromJson(
            jsonDecode(jsonEncode(persona.toJson())) as Map<String, dynamic>,
          );
    return _vault.runVaultMutation(() async {
      final current = await _readFile(session);
      await _writeFile(
        session,
        current.copyWith(
          chatDiaryPrompts: current.chatDiaryPrompts.withSelectedPersona(
            snapshot,
          ),
        ),
      );
    });
  }

  Future<void> save(
    UnlockedVaultSession session,
    AiStoredSettings settings, {
    bool preserveSelectedPersona = false,
  }) {
    final current = settings.copyWith(
      connection: adoptConnectionCatalog(settings.connection).settings,
    );
    final snapshot = AiStoredSettings.fromJson(
      jsonDecode(jsonEncode(current.toJson())) as Map<String, dynamic>,
    );
    return _vault.runVaultMutation(() async {
      await _vault.validateRecoverySession(session);
      final file = await _settingsFile();
      // 一般儲存拒絕覆寫不可讀設定；重建必須經過明確確認與指紋比對。
      await _recover(file, session);
      final selectedPersona = preserveSelectedPersona && file.existsSync()
          ? (await _decode(file, session)).chatDiaryPrompts.selectedPersona
          : snapshot.chatDiaryPrompts.selectedPersona;
      await _writeFile(
        session,
        snapshot.copyWith(
          chatDiaryPrompts: snapshot.chatDiaryPrompts.withSelectedPersona(
            selectedPersona,
          ),
        ),
      );
    });
  }

  Future<AiSettingsInspection> inspect(UnlockedVaultSession session) =>
      _vault.runVaultMutation(() async {
        await _vault.validateRecoverySession(session);
        return _inspectFile(await _settingsFile(), session);
      });

  Future<AiSettingsInspection> _inspectFile(
    File file,
    UnlockedVaultSession session,
  ) async {
    final contents = <String, String?>{};
    File? selected;
    for (final suffix in ['', '.previous', '.tmp']) {
      final candidate = File('${file.path}$suffix');
      final exists = candidate.existsSync();
      contents[suffix] = exists
          ? base64Encode(await candidate.readAsBytes())
          : null;
      if (exists) selected ??= candidate;
    }
    final revision = await hashVaultText(jsonEncode(contents));
    AiStoredSettings? settings;
    var status = AiSettingsStatus.missing;
    if (selected != null) {
      try {
        settings = await _decode(selected, session);
        status = AiSettingsStatus.ready;
      } on Object catch (error) {
        if (!isUnreadableContentError(error)) rethrow;
        status = AiSettingsStatus.unreadable;
      }
    }
    return AiSettingsInspection(
      vaultId: session.vaultId,
      revision: revision,
      status: status,
      settings: settings,
    );
  }

  Future<void> replaceUnreadableWithDefaults(
    UnlockedVaultSession session, {
    required AiSettingsInspection expected,
  }) => _vault.runVaultMutation(() async {
    await _vault.validateRecoverySession(session);
    final file = await _settingsFile();
    final current = await _inspectFile(file, session);
    if (expected.vaultId != session.vaultId ||
        current.revision != expected.revision ||
        current.status != AiSettingsStatus.unreadable) {
      throw const AiFailure(AiErrorCode.settings);
    }
    // 僅此明確確認的入口略過舊格式驗證；替換失敗仍保留選定的原內容。
    await _writeFile(session, const AiStoredSettings());
  });

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

  Future<AiStoredSettings> _decode(
    File file,
    UnlockedVaultSession session,
  ) async => AiStoredSettings.fromJson(
    await readVaultJson(file, _crypto, session, identity: documentId),
  );

  Future<void> _recover(File file, UnlockedVaultSession session) =>
      recoverFileReplacement(
        file,
        validate: (candidate) async {
          try {
            await _decode(candidate, session);
          } on Object catch (error) {
            if (isUnreadableContentError(error)) {
              throw const AiFailure(AiErrorCode.settings);
            }
            rethrow;
          }
        },
      );

  Future<AiStoredSettings> _readFile(UnlockedVaultSession session) async {
    await _vault.validateRecoverySession(session);
    final file = await _settingsFile();
    await _recover(file, session);
    if (!file.existsSync()) return const AiStoredSettings();
    final stored = await _decode(file, session);
    final adopted = adoptConnectionCatalog(stored.connection);
    if (!adopted.writeBack) return stored;
    final next = stored.copyWith(connection: adopted.settings);
    await _writeFile(session, next);
    return next;
  }

  Future<void> _writeFile(
    UnlockedVaultSession session,
    AiStoredSettings settings,
  ) async {
    await _vault.validateRecoverySession(session);
    final RecoveryMetadata metadata =
        await _vault.readRecoveryMetadata() ??
        (throw StateError('找不到 Recovery metadata。'));
    if (metadata.vaultId != session.vaultId) {
      throw StateError('目前 session 與 vault 資料不一致。');
    }
    final DateTime now = DateTime.now();
    await writeEncryptedVaultJson(
      file: await _settingsFile(),
      crypto: _crypto,
      session: session,
      metadata: metadata,
      documentId: documentId,
      plaintextBytes: utf8.encode(jsonEncode(settings.toJson())),
      createdAt: now,
      updatedAt: now,
      validateTemporary: (file) async {
        await _decode(file, session);
      },
    );
  }

  String _apiKeyStorageKey(AiConnectionConfig connectionConfig) =>
      connectionConfig.provider.hasCustomUrl
      ? 'connection_key_${base64Url.encode(utf8.encode(connectionConfig.credentialId))}'
      : 'key_${connectionConfig.provider.name}';
}
