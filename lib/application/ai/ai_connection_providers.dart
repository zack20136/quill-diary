import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/vault/vault_providers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/infrastructure/ai/ai_settings_store.dart';

final aiSettingsStoreProvider = Provider<AiSettingsStore>(
  (Ref ref) => AiSettingsStore(
    pathStrategy: ref.watch(vaultPathStrategyProvider),
    cryptoService: ref.watch(cryptoServiceProvider),
    repository: ref.watch(vaultRepositoryProvider),
  ),
);

final aiClientFactoryProvider =
    Provider<AiClient Function(AiConnectionConfig, String)>(
      (ref) =>
          (connectionConfig, apiKey) => AiClient(connectionConfig, apiKey),
    );
