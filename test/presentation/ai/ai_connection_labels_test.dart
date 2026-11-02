import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_catalog.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/presentation/ai/ai_connection_labels.dart';

import '../../helpers/shared/test_l10n.dart';

void main() {
  test('自訂模型標籤省略協定但保留埠號、路徑與模型內的斜線', () {
    for (final (url, expected) in [
      (
        'https://gateway.example:8443/v1/',
        'gateway.example:8443/v1/vendor/model',
      ),
      ('http://127.0.0.1:11434/api', '127.0.0.1:11434/api/vendor/model'),
      ('http://[::1]:11434', '[::1]:11434/vendor/model'),
    ]) {
      final config = AiConnectionConfig(
        provider: AiProvider.custom,
        customConnectionId: 'aic_work',
        displayName: '工作',
        baseUrl: url,
        model: 'vendor/model',
      );
      expect(aiChatModelLabel(testZhL10n, config), expected);
      expect(aiConnectionLabel(testZhL10n, config), '工作');
      expect(aiConnectionModelLabel(testZhL10n, config), '工作/vendor/model');
      expect(config.baseUrl, url);
    }
  });

  test('官方標籤維持原樣，未命名與未設定目的地使用在地化後備名稱', () {
    const official = AiConnectionConfig(
      provider: AiProvider.openai,
      model: 'gpt-model',
    );
    expect(aiChatModelLabel(testZhL10n, official), 'OpenAI/gpt-model');
    const custom = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
    );
    expect(aiConnectionLabel(testZhL10n, custom), testZhL10n.aiProviderCustom);
    expect(
      aiChatModelLabel(testZhL10n, custom),
      '${testZhL10n.aiConnectionNotConfigured}/model',
    );
  });
}
