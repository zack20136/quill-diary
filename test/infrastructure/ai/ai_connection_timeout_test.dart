import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';

import '../../helpers/ai/ai_test_helpers.dart';

class _UnresponsiveTransport extends RecordingAiTransport {
  @override
  Future<AiHttpResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    List<int>? body,
  ]) => Completer<AiHttpResponse>().future;
}

void main() {
  testWidgets('連線測試逾時會中止連線並回報，不會無限等待', (tester) async {
    final transport = _UnresponsiveTransport();
    final client = AiClient(
      const AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'https://example.com/v1',
      ),
      '',
      transport: transport,
    );
    AiFailure? failure;
    unawaited(
      client.testConnection().catchError((Object error) {
        failure = error as AiFailure;
      }),
    );
    await tester.pump(const Duration(seconds: 46));
    expect(failure?.code, AiErrorCode.timeout);
    expect(transport.closed, isTrue);
  });
}
