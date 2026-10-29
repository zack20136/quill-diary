import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ai/ai_connection_settings.dart';
import '../../infrastructure/ai/ai_client.dart';
import '../../infrastructure/ai/ai_connection_settings_store.dart';

final aiConnectionSettingsStoreProvider = Provider<AiConnectionSettingsStore>(
  (ref) => AiConnectionSettingsStore(),
);
final aiClientFactoryProvider =
    Provider<AiClient Function(AiConnectionConfig, String)>(
      (ref) =>
          (connectionConfig, apiKey) => AiClient(connectionConfig, apiKey),
    );
