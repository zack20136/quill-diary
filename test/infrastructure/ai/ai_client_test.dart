import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  test('雲端固定 HTTPS 且區網 HTTP 不接受公網與帳密', () {
    for (final host in [
      'http://127.0.0.1:11434',
      'http://192.168.1.5:11434',
      'http://10.0.0.2:11434',
      'http://[::1]:11434',
      'https://example.com/ollama',
    ]) {
      expect(
        validateAiEndpoint(
          AiConnectionConfig(
            provider: AiProvider.custom,
            customProtocol: AiApiProtocol.ollamaChat,
            baseUrl: host,
          ),
        ).hasAuthority,
        isTrue,
      );
    }
    for (final host in [
      'http://8.8.8.8',
      'http://example.com',
      'https://key@example.com',
      'https://example.com?api_key=secret',
      'file:///tmp/model',
      'http://169.254.169.254',
    ]) {
      expect(
        () => validateAiEndpoint(
          AiConnectionConfig(
            provider: AiProvider.custom,
            customProtocol: AiApiProtocol.ollamaChat,
            baseUrl: host,
          ),
        ),
        throwsA(isA<AiFailure>()),
      );
    }
  });

  for (final provider in AiProvider.values) {
    group(provider.name, () {
      test('原生系統指令與串流解析', () async {
        final wire = RecordingAiTransport();
        final client = AiClient(
          AiConnectionConfig(
            provider: provider,
            model: 'model',
            baseUrl: 'http://127.0.0.1:11434',
          ),
          'test-key',
          transport: wire,
        );
        switch (provider) {
          case AiProvider.openai:
            wire.lines = [
              'data: {"type":"response.output_text.delta","delta":"繁體"}',
              '',
              'data: {"type":"response.completed"}',
              '',
            ];
          case AiProvider.claude:
            wire.lines = [
              'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"繁體"}}',
              '',
              'data: {"type":"message_stop"}',
              '',
            ];
          case AiProvider.gemini:
            wire.lines = [
              'data: {"candidates":[{"content":{"parts":[{"text":"繁體"}]},"finishReason":"STOP"}]}',
              '',
            ];
          case AiProvider.xai:
          case AiProvider.custom:
            wire.lines = [
              'data: {"choices":[{"delta":{"content":"繁體"},"finish_reason":null}]}',
              '',
              'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}',
              '',
              'data: [DONE]',
              '',
            ];
        }
        expect(
          await client.reply('自訂完整提示詞', [
            const AiInputMessage(isUser: true, text: '代號內容'),
          ]).join(),
          '繁體',
        );
        final request = wire.streams.single;
        if (provider == AiProvider.xai) {
          expect(
            request.uri.toString(),
            'https://api.x.ai/v1/chat/completions',
          );
          expect(request.headers['Authorization'], 'Bearer test-key');
        }
        switch (provider) {
          case AiProvider.openai:
            expect(request.body['instructions'], '自訂完整提示詞');
            expect(request.body['store'], false);
          case AiProvider.claude:
            expect(request.body['system'], '自訂完整提示詞');
            expect(request.headers['x-api-key'], 'test-key');
          case AiProvider.gemini:
            expect((request.body['systemInstruction'] as Map)['parts'], [
              {'text': '自訂完整提示詞'},
            ]);
            expect(request.uri.query, isNot(contains('test-key')));
          case AiProvider.xai:
          case AiProvider.custom:
            expect((request.body['messages'] as List).first, {
              'role': 'system',
              'content': '自訂完整提示詞',
            });
        }
        expect(jsonEncode(request.body), isNot(contains('test-key')));
        client.close();
        expect(wire.closed, isTrue);
      });
    });
  }

  test('未完成串流不被當成成功日記', () async {
    final wire = RecordingAiTransport()
      ..lines = [
        'data: {"type":"response.output_text.delta","delta":"只有一半"}',
        '',
      ];
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.openai, model: 'model'),
      'key',
      transport: wire,
    );
    await expectLater(
      client.reply('prompt', []).join(),
      throwsA(isA<AiFailure>()),
    );
  });

  test('圖片檔案參照會重用且可刪除', () async {
    final wire = RecordingAiTransport()
      ..respond({'id': 'file-example'})
      ..respond({'deleted': true});
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.openai, model: 'model'),
      'key',
      transport: wire,
    );
    final image = AiInputImage(
      id: 'local-image',
      mimeType: 'image/png',
      bytes: testAiPng,
    );
    final file = await client.upload(image);
    expect((await client.upload(image)).id, file.id);
    expect(wire.requests, hasLength(1));
    await client.deleteFile(file);
    expect(wire.requests.last.method, 'DELETE');
    expect(
      utf8.decode(wire.requests.first.body!, allowMalformed: true),
      contains('filename="image.png"'),
    );
  });

  test('Gemini 上傳沒有檔案位址時回報回應錯誤', () async {
    final wire = RecordingAiTransport()
      ..respond({
        'file': {'name': 'files/abc'},
      });
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.gemini, model: 'model'),
      'key',
      transport: wire,
    );
    addTearDown(client.close);
    await expectLater(
      client.upload(
        AiInputImage(id: 'photo', mimeType: 'image/png', bytes: testAiPng),
      ),
      throwsA(
        isA<AiFailure>().having(
          (failure) => failure.code,
          '代碼',
          AiErrorCode.response,
        ),
      ),
    );
  });

  test('上傳紀錄寫入失敗會刪除遠端檔案，重試重新上傳而不沿用失效快取', () async {
    final transport = RecordingAiTransport()
      ..respond({'id': 'failed-file'})
      ..respond({'deleted': true})
      ..respond({'id': 'retry-file'});
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.openai, model: 'model'),
      'key',
      transport: transport,
    );
    var records = 0;
    client.onFileUploaded = (_) async {
      records++;
      if (records == 1) throw const AiFailure(AiErrorCode.storage);
    };
    final image = AiInputImage(
      id: 'photo',
      mimeType: 'image/png',
      bytes: testAiPng,
    );
    await expectLater(client.upload(image), throwsA(isA<AiFailure>()));
    expect((await client.upload(image)).id, 'retry-file');
    expect((await client.upload(image)).id, 'retry-file');
    expect(transport.requests.map((request) => request.method), [
      'POST',
      'DELETE',
      'POST',
    ]);
    expect(records, 2);
    client.close();
  });

  test('上傳與刪除檢查 HTTP 狀態，刪除不存在的遠端檔案視為完成', () async {
    final transport = RecordingAiTransport()
      ..respond({'private': '不可曝光的錯誤本文'}, status: 401)
      ..respond({}, status: 503)
      ..respond({}, status: 404);
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.openai, model: 'model'),
      'key',
      transport: transport,
    );
    final image = AiInputImage(
      id: 'photo',
      mimeType: 'image/png',
      bytes: testAiPng,
    );
    await expectLater(
      client.upload(image),
      throwsA(
        isA<AiFailure>().having((failure) => failure.status, 'HTTP 狀態', 401),
      ),
    );
    const file = AiRemoteFile(id: 'file', uri: '');
    await expectLater(
      client.deleteFile(file),
      throwsA(
        isA<AiFailure>().having((failure) => failure.status, 'HTTP 狀態', 503),
      ),
    );
    await client.deleteFile(file);
    client.close();
  });

  test('HTTP 狀態只對應錯誤代碼，不帶回應本文', () {
    const expected = {
      400: AiErrorCode.request,
      401: AiErrorCode.authentication,
      403: AiErrorCode.authentication,
      429: AiErrorCode.quota,
      500: AiErrorCode.unavailable,
    };
    for (final entry in expected.entries) {
      expect(
        () => checkAiStatus(entry.key),
        throwsA(
          isA<AiFailure>()
              .having((error) => error.code, '代碼', entry.value)
              .having((error) => error.status, '狀態', entry.key)
              .having(
                (error) => error.toString(),
                '描述',
                'AiFailure(${entry.value.name})',
              ),
        ),
      );
    }
  });
  test('Ollama 不支援圖片時不送出訊息', () async {
    final wire = RecordingAiTransport()
      ..respond({
        'capabilities': ['completion'],
        'model_info': {
          'general.architecture': 'llama',
          'llama.context_length': 131072,
        },
      });
    final client = AiClient(
      const AiConnectionConfig(
        provider: AiProvider.custom,
        customProtocol: AiApiProtocol.ollamaChat,
        model: 'local-model',
        baseUrl: 'http://127.0.0.1:11434',
      ),
      '',
      transport: wire,
    );
    await expectLater(
      client.reply('prompt', [
        AiInputMessage(
          isUser: true,
          text: '照片',
          images: [
            AiInputImage(id: 'photo', mimeType: 'image/png', bytes: testAiPng),
          ],
        ),
      ]).join(),
      throwsA(
        isA<AiFailure>().having(
          (e) => e.code,
          '圖片能力',
          AiErrorCode.imageUnsupported,
        ),
      ),
    );
    expect(wire.streams, isEmpty);
    expect(wire.requests, hasLength(1));
  });

  test('Claude 最後一筆 SSE 沒有尾端空行仍能辨識結束', () async {
    final wire = RecordingAiTransport()
      ..lines = [
        'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"完整"}}',
        '',
        'data: {"type":"message_stop"}',
      ];
    final client = AiClient(
      const AiConnectionConfig(provider: AiProvider.claude, model: 'example'),
      'key',
      transport: wire,
    );
    expect(await client.reply('prompt', []).join(), '完整');
  });
}
