import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';

import '../../helpers/ai/ai_test_helpers.dart';

void main() {
  test('收到 HTTP 標頭後本文停滯會逾時並關閉連線', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 2;
      request.response.add([65]);
      await request.response.flush();
    });
    final transport = IoAiTransport();
    addTearDown(() async {
      transport.close();
      await server.close(force: true);
    });
    final readingBody = Completer<void>();
    void Function()? expireBody;
    var deadlines = 0;
    await runZoned(
      () async {
        final checked = expectLater(
          transport.request(
            'GET',
            Uri.parse('http://127.0.0.1:${server.port}'),
            {},
          ),
          throwsA(
            isA<AiFailure>().having(
              (failure) => failure.code,
              '錯誤',
              AiErrorCode.timeout,
            ),
          ),
        );
        await readingBody.future.timeout(const Duration(seconds: 5));
        expireBody!();
        await checked;
      },
      zoneSpecification: ZoneSpecification(
        createTimer: (self, parent, zone, duration, callback) {
          if (duration == const Duration(minutes: 5) && ++deadlines == 2) {
            expireBody = callback;
            readingBody.complete();
          }
          return parent.createTimer(zone, duration, callback);
        },
      ),
    );
    await expectLater(
      transport.request(
        'GET',
        Uri.parse('http://127.0.0.1:${server.port}'),
        {},
      ),
      throwsA(
        isA<AiFailure>().having(
          (failure) => failure.code,
          '錯誤',
          AiErrorCode.network,
        ),
      ),
    );
  });

  Map<String, Object?> result(AiApiProtocol protocol) => switch (protocol) {
    AiApiProtocol.chatCompletions => {
      'choices': [
        {
          'message': {'content': 'OK'},
        },
      ],
    },
    AiApiProtocol.responses => {
      'output': [
        {
          'type': 'message',
          'content': [
            {'type': 'output_text', 'text': 'OK'},
          ],
        },
      ],
    },
    AiApiProtocol.claudeMessages => {
      'content': [
        {'type': 'text', 'text': 'OK'},
      ],
    },
    AiApiProtocol.geminiContent => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': 'OK'},
            ],
          },
        },
      ],
    },
    AiApiProtocol.ollamaChat => {
      'message': {'content': 'OK'},
      'done': true,
    },
  };
  final lines = <AiApiProtocol, List<String>>{
    AiApiProtocol.chatCompletions: [
      'data: {"choices":[{"delta":{"content":"OK"},"finish_reason":"stop"}]}',
      '',
    ],
    AiApiProtocol.responses: [
      'data: {"type":"response.output_text.delta","delta":"OK"}',
      '',
      'data: {"type":"response.completed"}',
      '',
    ],
    AiApiProtocol.claudeMessages: [
      'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"OK"}}',
      '',
      'data: {"type":"message_stop"}',
      '',
    ],
    AiApiProtocol.geminiContent: [
      'data: {"candidates":[{"content":{"parts":[{"text":"OK"}]},"finishReason":"STOP"}]}',
      '',
    ],
    AiApiProtocol.ollamaChat: ['{"message":{"content":"OK"},"done":true}'],
  };
  final suffixes = <AiApiProtocol, String>{
    AiApiProtocol.chatCompletions: '/chat/completions',
    AiApiProtocol.responses: '/responses',
    AiApiProtocol.claudeMessages: '/messages',
    AiApiProtocol.geminiContent: '/models/model:generateContent',
    AiApiProtocol.ollamaChat: '/chat',
  };
  for (final protocol in AiApiProtocol.values) {
    final prefix = protocol == AiApiProtocol.chatCompletions
        ? '/v1'
        : protocol.pathPrefix;
    final connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      customProtocol: protocol,
      baseUrl: 'https://gateway.example/proxy$prefix',
      model: 'model',
    );
    group(protocol.name, () {
      test('連線測試送出非串流原生請求並驗證模型回覆', () async {
        final wire = RecordingAiTransport()..respond(result(protocol));
        final client = AiClient(
          connectionConfig,
          'synthetic-key',
          transport: wire,
        );
        await client.testConnection();
        final request = wire.requests.single;
        expect(request.uri.path, '/proxy$prefix${suffixes[protocol]}');
        expect(request.method, 'POST');
        expect(wire.streams, isEmpty);
        final body = jsonDecode(utf8.decode(request.body!)) as Map;
        if (protocol != AiApiProtocol.geminiContent) {
          expect(body['stream'], false);
        }
        if (protocol == AiApiProtocol.responses) expect(body['store'], false);
        final header = protocol == AiApiProtocol.claudeMessages
            ? 'x-api-key'
            : protocol == AiApiProtocol.geminiContent
            ? 'x-goog-api-key'
            : 'Authorization';
        expect(request.headers[header], contains('synthetic-key'));
        client.close();
      });
      test('自訂網址以正確協定傳圖，不依賴 Files API', () async {
        final wire = RecordingAiTransport()..lines = lines[protocol]!;
        if (protocol == AiApiProtocol.ollamaChat) {
          wire.respond({
            'capabilities': ['vision'],
          });
        }
        final client = AiClient(
          connectionConfig,
          'synthetic-key',
          transport: wire,
        );
        expect(
          await client.reply('系統指令', [
            AiInputMessage(
              isUser: true,
              text: '合成照片',
              images: [
                AiInputImage(
                  id: 'photo',
                  mimeType: 'image/png',
                  bytes: testAiPng,
                ),
              ],
            ),
          ]).join(),
          'OK',
        );
        expect(
          wire.requests.any((r) => r.uri.path.contains('/files')),
          isFalse,
        );
        final body = wire.streams.single.body;
        expect(wire.streams.single.uri.path, startsWith('/proxy$prefix/'));
        expect(wire.streams.single.uri.path, isNot(contains('$prefix$prefix')));
        expect(jsonEncode(body), contains(base64Encode(testAiPng)));
        switch (protocol) {
          case AiApiProtocol.responses:
            expect(body['instructions'], '系統指令');
          case AiApiProtocol.claudeMessages:
            expect(body['system'], '系統指令');
            expect(jsonEncode(body), contains('base64'));
          case AiApiProtocol.geminiContent:
            expect(body.containsKey('systemInstruction'), isTrue);
            expect(jsonEncode(body), contains('inlineData'));
          case AiApiProtocol.chatCompletions || AiApiProtocol.ollamaChat:
            expect((body['messages'] as List).first, {
              'role': 'system',
              'content': '系統指令',
            });
        }
        client.close();
      });
    });
  }
  test('Custom 協定可序列化保存', () {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      customProtocol: AiApiProtocol.claudeMessages,
    );
    expect(
      AiConnectionConfig.fromJson(connectionConfig.toJson()).protocol,
      AiApiProtocol.claudeMessages,
    );
  });
  test('連線測試保留 HTTP 狀態並拒絕空白或錯誤格式的回覆', () async {
    const connectionConfig = AiConnectionConfig(
      provider: AiProvider.custom,
      model: 'model',
      baseUrl: 'https://example.com/v1',
    );
    final wire = RecordingAiTransport()
      ..respond({
        'error': {'message': '合成錯誤'},
      }, status: 503);
    final client = AiClient(connectionConfig, '', transport: wire);
    await expectLater(
      client.testConnection(),
      throwsA(isA<AiFailure>().having((e) => e.status, 'status', 503)),
    );
    wire.respond({'choices': []});
    await expectLater(
      client.testConnection(),
      throwsA(
        isA<AiFailure>().having((e) => e.code, 'code', AiErrorCode.response),
      ),
    );
    client.close();
  });
  test('實際 HTTP 服務錯誤保留狀態，供連線測試診斷', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 503;
      request.response.write('{"error":"synthetic"}');
      try {
        await request.response.close();
      } on Object {
        // 客戶端取得錯誤狀態後會取消讀取回應內容。
      }
    });
    final client = AiClient(
      AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'model',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
      ),
      '',
    );
    addTearDown(client.close);
    await expectLater(
      client.testConnection(),
      throwsA(isA<AiFailure>().having((e) => e.status, 'status', 503)),
    );
  });

  test('實際 HTTP 傳輸可測試連線，驗證網址與非串流內容', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = Completer<({String path, Map body})>();
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      received.complete((path: request.uri.path, body: body));
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'OK'},
            },
          ],
        }),
      );
      await request.response.close();
    });
    final client = AiClient(
      AiConnectionConfig(
        provider: AiProvider.custom,
        model: 'synthetic-model',
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
      ),
      '',
    );
    addTearDown(client.close);
    await client.testConnection();
    final request = await received.future;
    expect(request.path, '/v1/chat/completions');
    expect(request.body['model'], 'synthetic-model');
    expect(request.body['stream'], false);
  });
}
