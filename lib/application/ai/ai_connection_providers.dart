import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/session/session_providers.dart';
import 'package:quill_diary/application/session/session_state.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';
import 'package:quill_diary/infrastructure/ai/ai_transport.dart';

final aiSettingsStoreProvider = Provider<AiSettingsStore>(
  (Ref ref) => AiSettingsStore(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    repository: ref.watch(vaultRepositoryProvider),
  ),
);

/// 「啟用 AI 功能」存於加密 AI 設定。解鎖後讀入；鎖定時保留最後已知值，尚未讀入時視為開啟。
final aiEnabledProvider = NotifierProvider<AiEnabledController, bool>(
  AiEnabledController.new,
);

class AiEnabledController extends Notifier<bool> {
  int _revision = 0;
  int _savedRevision = 0;
  bool _savedEnabled = true;

  // 直接讀 appSessionProvider：activeVaultSessionProvider 會在尚未啟動時觸發解鎖流程，
  // 讀取設定就可能把剛開啟的 session 覆蓋成 unlocking。
  @override
  bool build() {
    final revision = ++_revision;
    _savedRevision = revision - 1;
    _savedEnabled = true;
    ref.listen(appSessionProvider, (_, next) {
      final revision = ++_revision;
      final UnlockedVaultSession? session = _unlockedSession(next);
      if (session != null) unawaited(_load(session, revision));
    });
    final UnlockedVaultSession? session = _unlockedSession(
      ref.read(appSessionProvider),
    );
    if (session != null) unawaited(_load(session, revision));
    return true;
  }

  static UnlockedVaultSession? _unlockedSession(AppSessionState sessionState) =>
      sessionState.isUnlocked ? sessionState.session : null;

  bool _isCurrent(UnlockedVaultSession session, int revision) =>
      ref.mounted &&
      revision == _revision &&
      identical(_unlockedSession(ref.read(appSessionProvider)), session);

  void _recordSavedValue(
    UnlockedVaultSession session,
    int revision,
    bool enabled,
  ) {
    if (!ref.mounted ||
        revision < _savedRevision ||
        !identical(_unlockedSession(ref.read(appSessionProvider)), session)) {
      return;
    }
    _savedRevision = revision;
    _savedEnabled = enabled;
  }

  Future<void> _load(UnlockedVaultSession session, int revision) async {
    try {
      final settings = await ref.read(aiSettingsStoreProvider).read(session);
      // 舊讀取仍可提供失敗還原的已提交基準，但不能蓋掉較新的已提交值。
      _recordSavedValue(session, revision, settings.aiEnabled);
      if (!_isCurrent(session, revision)) return;
      state = settings.aiEnabled;
    } on Object {
      // 讀取失敗時維持上一個已知值，AI 設定頁會回報錯誤。
    }
  }

  /// 先更新畫面，寫入失敗時還原。
  Future<void> setEnabled(bool enabled) async {
    final UnlockedVaultSession? session = _unlockedSession(
      ref.read(appSessionProvider),
    );
    if (session == null) throw StateError('尚未解鎖');
    final revision = ++_revision;
    state = enabled;
    try {
      await ref.read(aiSettingsStoreProvider).updateAiEnabled(session, enabled);
      _recordSavedValue(session, revision, enabled);
    } on Object {
      if (_isCurrent(session, revision)) state = _savedEnabled;
      rethrow;
    }
  }
}

/// 設定問題丟 [AiErrorCode.configuration]；端點問題維持 [validateAiEndpoint] 的錯誤。
Future<String> requireAiRequestKey({
  required bool enabled,
  required AiConnectionConfig connection,
  required Future<String> Function() readApiKey,
}) async {
  if (!enabled ||
      !connection.isConfigured ||
      !connection.hasCompleteRequestSnapshot) {
    throw const AiFailure(AiErrorCode.configuration);
  }
  validateAiEndpoint(connection);
  final String key = await readApiKey();
  if (connection.provider.requiresApiKey && key.isEmpty) {
    throw const AiFailure(AiErrorCode.configuration);
  }
  return key;
}

final aiClientFactoryProvider =
    Provider<AiClient Function(AiConnectionConfig, String)>(
      (ref) => (connectionConfig, apiKey) {
        if (!ref.read(aiEnabledProvider)) {
          throw const AiFailure(AiErrorCode.configuration);
        }
        return AiClient(connectionConfig, apiKey);
      },
    );

/// 只檢查本機設定與憑證，不建立客戶端或送出網路請求。
final aiConnectionReadyProvider = FutureProvider.autoDispose
    .family<bool, AiConnectionConfig>((ref, connection) async {
      if (!ref.watch(aiEnabledProvider)) return false;
      final session = await ref.watch(activeVaultSessionProvider.future);
      if (session == null ||
          !connection.isConfigured ||
          !connection.hasCompleteRequestSnapshot) {
        return false;
      }
      try {
        validateAiEndpoint(connection);
      } on AiFailure {
        return false;
      }
      if (!connection.provider.requiresApiKey) return true;
      return (await ref.watch(aiSettingsStoreProvider).readApiKey(connection))
          .trim()
          .isNotEmpty;
    });
