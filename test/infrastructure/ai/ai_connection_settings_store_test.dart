import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/app_identifiers.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_connection_settings_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const first = AiConnectionConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://first.example/v1',
    model: 'model',
  );
  const other = AiConnectionConfig(
    provider: AiProvider.custom,
    baseUrl: 'https://other.example/v1',
    model: 'model',
  );
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Custom 金鑰依目的網址保存，清空只移除該目的地金鑰', () async {
    final store = AiConnectionSettingsStore();
    await store.saveApiKey(first, 'first-synthetic-key');
    expect(await store.readApiKey(other), isEmpty);
    await store.saveApiKey(other, 'other-synthetic-key');
    await store.saveApiKey(first, '  ');
    expect(await store.readApiKey(first), isEmpty);
    expect(await store.readApiKey(other), 'other-synthetic-key');
    expect(
      await store.readApiKey(
        const AiConnectionConfig(
          provider: AiProvider.custom,
          baseUrl: 'https://OTHER.example/v1/',
        ),
      ),
      'other-synthetic-key',
    );
  });

  test('寫入後的連線設定不含 API Key 內容', () async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: AppIdentifiers.aiSecureStorageNamespace,
      ),
    );
    final store = AiConnectionSettingsStore(storage: storage);
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'model',
    );
    await store.save(
      const AiConnectionSettings(
        provider: AiProvider.openai,
        configs: {AiProvider.openai: connectionConfig},
      ),
    );
    await store.saveApiKey(connectionConfig, 'synthetic-secret-key');
    final raw = await storage.read(key: 'settings');
    expect(raw, isNot(contains('synthetic-secret-key')));
    expect(await storage.read(key: 'key_openai'), 'synthetic-secret-key');
  });
}
