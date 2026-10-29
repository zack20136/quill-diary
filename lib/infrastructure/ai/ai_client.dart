import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/ai/ai_connection_settings.dart';

enum AiErrorCode {
  configuration,
  endpoint,
  authentication,
  quota,
  request,
  network,
  timeout,
  tls,
  response,
  image,
  imageUnsupported,
  storage,
  unavailable,
  unreadable,
}

class AiFailure implements Exception {
  const AiFailure(this.code, {this.status});
  final AiErrorCode code;
  final int? status;
  @override
  String toString() => 'AiFailure(${code.name})';
}

class AiInputImage {
  const AiInputImage({
    required this.id,
    required this.mimeType,
    required this.bytes,
  });
  final String id;
  final String mimeType;
  final Uint8List bytes;
}

class AiInputMessage {
  const AiInputMessage({
    required this.isUser,
    required this.text,
    this.images = const [],
  });
  final bool isUser;
  final String text;
  final List<AiInputImage> images;
}

/// 目的地在送出憑證之前驗證；HTTP 只允許明確的區網與 loopback IP。
Uri validateAiEndpoint(AiConnectionConfig connectionConfig) {
  final uri = Uri.tryParse(connectionConfig.effectiveBaseUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const AiFailure(AiErrorCode.endpoint);
  }
  if (!connectionConfig.provider.hasCustomUrl) {
    if (uri.origin !=
        Uri.parse(connectionConfig.provider.defaultBaseUrl).origin) {
      throw const AiFailure(AiErrorCode.endpoint);
    }
  }
  if (uri.scheme == 'https') return uri;
  if (uri.scheme != 'http' || !connectionConfig.provider.hasCustomUrl) {
    throw const AiFailure(AiErrorCode.endpoint);
  }
  final ip = InternetAddress.tryParse(uri.host);
  var allowed = ip?.isLoopback ?? false;
  if (ip?.type == InternetAddressType.IPv4) {
    final addressBytes = ip!.rawAddress;
    allowed =
        allowed ||
        addressBytes[0] == 10 ||
        (addressBytes[0] == 172 &&
            addressBytes[1] >= 16 &&
            addressBytes[1] <= 31) ||
        (addressBytes[0] == 192 && addressBytes[1] == 168);
  } else if (ip?.type == InternetAddressType.IPv6) {
    allowed = allowed || (ip!.rawAddress[0] & 0xfe) == 0xfc;
  }
  if (!allowed) throw const AiFailure(AiErrorCode.endpoint);
  return uri;
}

class AiHttpResponse {
  const AiHttpResponse(this.status, this.bytes);
  final int status;
  final List<int> bytes;
  Map<String, dynamic> get json =>
      (jsonDecode(utf8.decode(bytes)) as Map).cast<String, dynamic>();
}

abstract interface class AiTransport {
  Future<AiHttpResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    List<int>? body,
  ]);
  Stream<String> stream(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
  );
  void close();
}

void checkAiStatus(int status) {
  if (status >= 200 && status < 300) return;
  throw AiFailure(switch (status) {
    401 || 403 => AiErrorCode.authentication,
    429 => AiErrorCode.quota,
    >= 500 => AiErrorCode.unavailable,
    _ => AiErrorCode.request,
  }, status: status);
}

void checkAiResponseError(Map<String, dynamic> data) {
  final error = data['error'];
  if (error == null) return;
  if (error is Map) {
    final status = int.tryParse('${error['code'] ?? error['status']}');
    if (status != null && status >= 400 && status < 600) checkAiStatus(status);
  }
  throw const AiFailure(AiErrorCode.response);
}

class IoAiTransport implements AiTransport {
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30);

  Future<HttpClientResponse> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? body,
  ) async {
    final request = await _client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close().timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        await response.listen(null).cancel();
      } on Object {
        // 取消錯誤內容時的連線例外，不應蓋掉已收到的 HTTP 狀態。
      }
      checkAiStatus(response.statusCode);
    }
    return response;
  }

  @override
  Future<AiHttpResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    List<int>? body,
  ]) async {
    try {
      final response = await _send(method, uri, headers, body);
      final bytes = await response
          .timeout(const Duration(minutes: 5))
          .fold<List<int>>([], (buffer, part) => buffer..addAll(part));
      return AiHttpResponse(response.statusCode, bytes);
    } on AiFailure {
      rethrow;
    } on TimeoutException {
      close();
      throw const AiFailure(AiErrorCode.timeout);
    } on HandshakeException {
      throw const AiFailure(AiErrorCode.tls);
    } on Object {
      throw const AiFailure(AiErrorCode.network);
    }
  }

  @override
  Stream<String> stream(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) async* {
    try {
      final response = await _send(
        'POST',
        uri,
        headers,
        utf8.encode(jsonEncode(body)),
      );
      yield* response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(minutes: 5));
    } on AiFailure {
      rethrow;
    } on TimeoutException {
      close();
      throw const AiFailure(AiErrorCode.timeout);
    } on HandshakeException {
      throw const AiFailure(AiErrorCode.tls);
    } on Object {
      throw const AiFailure(AiErrorCode.network);
    }
  }

  @override
  void close() => _client.close(force: true);
}

class AiRemoteFile {
  const AiRemoteFile({required this.id, required this.uri});
  final String id;
  final String uri;
  Map<String, String> toJson() => {'id': id, 'uri': uri};
  factory AiRemoteFile.fromJson(Map<String, dynamic> json) =>
      AiRemoteFile(id: json['id'] as String, uri: json['uri'] as String);
}

abstract class AiClient {
  factory AiClient(
    AiConnectionConfig connectionConfig,
    String apiKey, {
    AiTransport? transport,
  }) => switch (connectionConfig.protocol) {
    AiApiProtocol.responses => OpenAiClient(
      connectionConfig,
      apiKey,
      transport: transport,
    ),
    AiApiProtocol.chatCompletions => OpenAiCompatibleClient(
      connectionConfig,
      apiKey,
      transport: transport,
    ),
    AiApiProtocol.claudeMessages => ClaudeAiClient(
      connectionConfig,
      apiKey,
      transport: transport,
    ),
    AiApiProtocol.geminiContent => GeminiAiClient(
      connectionConfig,
      apiKey,
      transport: transport,
    ),
    AiApiProtocol.ollamaChat => OllamaAiClient(
      connectionConfig,
      apiKey,
      transport: transport,
    ),
  };

  AiClient.base(this.connectionConfig, this.apiKey, {AiTransport? transport})
    : transport = transport ?? IoAiTransport() {
    validateAiEndpoint(connectionConfig);
  }
  final AiConnectionConfig connectionConfig;
  final String apiKey;
  final AiTransport transport;
  final Map<String, AiRemoteFile> _uploadedFilesByImageId = {};
  Future<void> Function(AiRemoteFile file)? onFileUploaded;

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
  };
  Uri endpoint(String path) {
    final base = validateAiEndpoint(connectionConfig);
    final prefix = connectionConfig.protocol.pathPrefix;
    var relative = path;
    if (connectionConfig.provider == AiProvider.custom &&
        prefix.isNotEmpty &&
        path.startsWith('$prefix/')) {
      final hasPrefix = connectionConfig.protocol == AiApiProtocol.ollamaChat
          ? base.path.endsWith('/api')
          : RegExp(r'/v[0-9][A-Za-z0-9.]*$').hasMatch(base.path);
      if (hasPrefix) relative = path.substring(prefix.length);
    }
    return Uri.parse('${connectionConfig.effectiveBaseUrl}$relative');
  }

  Future<List<String>> listModels();
  Stream<String> reply(String systemPrompt, List<AiInputMessage> messages);
  void close() => transport.close();

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await transport.request('GET', endpoint(path), headers);
    checkAiStatus(response.status);
    return response.json;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await transport.request(
      'POST',
      endpoint(path),
      headers,
      utf8.encode(jsonEncode(body)),
    );
    checkAiStatus(response.status);
    final data = response.json;
    checkAiResponseError(data);
    return data;
  }

  Future<void> testConnection() async {
    const prompt = 'Reply with OK.';
    final protocol = connectionConfig.protocol;
    final path = switch (protocol) {
      AiApiProtocol.chatCompletions => '/chat/completions',
      AiApiProtocol.responses => '/v1/responses',
      AiApiProtocol.claudeMessages => '/v1/messages',
      AiApiProtocol.geminiContent =>
        '/v1beta/models/${Uri.encodeComponent(connectionConfig.model.replaceFirst('models/', ''))}:generateContent',
      AiApiProtocol.ollamaChat => '/api/chat',
    };
    final body = <String, Object?>{
      if (protocol != AiApiProtocol.geminiContent)
        'model': connectionConfig.model,
      if (protocol != AiApiProtocol.geminiContent) 'stream': false,
      if (protocol == AiApiProtocol.responses) ...{
        'input': prompt,
        'store': false,
      } else if (protocol == AiApiProtocol.geminiContent)
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ]
      else
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      if (protocol == AiApiProtocol.claudeMessages) 'max_tokens': 64,
    };
    final data = await postJson(path, body).timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        close();
        throw const AiFailure(AiErrorCode.timeout);
      },
    );
    final String text = switch (protocol) {
      AiApiProtocol.chatCompletions =>
        ((data['choices'] as List?)?.firstOrNull
                    as Map?)?['message']?['content']
                as String? ??
            '',
      AiApiProtocol.responses => [
        for (final item in data['output'] as List? ?? [])
          for (final part in (item as Map)['content'] as List? ?? [])
            if ((part as Map)['type'] == 'output_text')
              part['text'] as String? ?? '',
      ].join(),
      AiApiProtocol.claudeMessages => [
        for (final part in data['content'] as List? ?? [])
          if ((part as Map)['type'] == 'text') part['text'] as String? ?? '',
      ].join(),
      AiApiProtocol.geminiContent => [
        for (final candidate in data['candidates'] as List? ?? [])
          for (final part
              in (candidate as Map)['content']?['parts'] as List? ?? [])
            if ((part as Map)['thought'] != true) part['text'] as String? ?? '',
      ].join(),
      AiApiProtocol.ollamaChat =>
        (data['message'] as Map?)?['content'] as String? ?? '',
    };
    if (text.trim().isEmpty) throw const AiFailure(AiErrorCode.response);
  }

  Future<AiRemoteFile> upload(AiInputImage image) async {
    if (connectionConfig.provider == AiProvider.custom) {
      throw const AiFailure(AiErrorCode.imageUnsupported);
    }
    final cached = _uploadedFilesByImageId[image.id];
    if (cached != null) return cached;
    final boundary = 'quill${DateTime.now().microsecondsSinceEpoch}';
    final builder = BytesBuilder(copy: false);
    if (connectionConfig.provider == AiProvider.openai) {
      builder.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="purpose"\r\n\r\nvision\r\n',
        ),
      );
    }
    if (connectionConfig.provider == AiProvider.gemini) {
      builder.add(
        utf8.encode(
          '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n{"file":{"display_name":"image"}}\r\n--$boundary\r\nContent-Type: ${image.mimeType}\r\n\r\n',
        ),
      );
    } else {
      builder.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="image.${image.mimeType.split('/').last}"\r\nContent-Type: ${image.mimeType}\r\n\r\n',
        ),
      );
    }
    builder.add(image.bytes);
    builder.add(utf8.encode('\r\n--$boundary--\r\n'));
    final path = connectionConfig.provider == AiProvider.gemini
        ? '/upload/v1beta/files?uploadType=multipart'
        : '/v1/files';
    final extra = <String, String>{
      ...headers,
      'Content-Type':
          '${connectionConfig.provider == AiProvider.gemini ? 'multipart/related' : 'multipart/form-data'}; boundary=$boundary',
      if (connectionConfig.provider == AiProvider.claude)
        'anthropic-beta': 'files-api-2025-04-14',
    };
    final response = await transport.request(
      'POST',
      endpoint(path),
      extra,
      builder.takeBytes(),
    );
    checkAiStatus(response.status);
    final responseBody = response.json;
    checkAiResponseError(responseBody);
    final file = connectionConfig.provider == AiProvider.gemini
        ? (responseBody['file'] as Map).cast<String, dynamic>()
        : responseBody;
    final uri = file['uri'] as String? ?? '';
    if (connectionConfig.provider == AiProvider.gemini && uri.isEmpty) {
      throw const AiFailure(AiErrorCode.response);
    }
    final remote = AiRemoteFile(
      id: (file['name'] ?? file['id']) as String,
      uri: uri,
    );
    if (onFileUploaded != null) {
      try {
        await onFileUploaded!(remote);
      } catch (_) {
        try {
          await deleteFile(remote);
        } on Object {
          // 清理失敗時仍回報原本的紀錄寫入錯誤。
        }
        rethrow;
      }
    }
    _uploadedFilesByImageId[image.id] = remote;
    return remote;
  }

  Future<void> deleteFile(AiRemoteFile file) async {
    if (connectionConfig.provider == AiProvider.custom) {
      return;
    }
    if (connectionConfig.provider == AiProvider.gemini &&
        !RegExp(r'^files/[A-Za-z0-9_-]+$').hasMatch(file.id)) {
      throw const AiFailure(AiErrorCode.response);
    }
    final path = connectionConfig.provider == AiProvider.gemini
        ? '/v1beta/${file.id}'
        : '/v1/files/${Uri.encodeComponent(file.id)}';
    try {
      final response = await transport.request('DELETE', endpoint(path), {
        ...headers,
        if (connectionConfig.provider == AiProvider.claude)
          'anthropic-beta': 'files-api-2025-04-14',
      });
      checkAiStatus(response.status);
    } on AiFailure catch (error) {
      if (error.status != 404) rethrow;
    }
  }

  Stream<Map<String, dynamic>> events(
    String path,
    Map<String, Object?> body, {
    bool ndjson = false,
    Map<String, String>? requestHeaders,
  }) async* {
    final data = <String>[];
    await for (final line in transport.stream(
      endpoint(path),
      requestHeaders ?? headers,
      body,
    )) {
      if (ndjson) {
        if (line.trim().isNotEmpty) {
          yield (jsonDecode(line) as Map).cast<String, dynamic>();
        }
      } else if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      } else if (line.isEmpty && data.isNotEmpty) {
        final value = data.join('\n');
        data.clear();
        if (value != '[DONE]') {
          yield (jsonDecode(value) as Map).cast<String, dynamic>();
        }
      }
    }
    if (data.isNotEmpty && data.join('\n') != '[DONE]') {
      yield (jsonDecode(data.join('\n')) as Map).cast<String, dynamic>();
    }
  }
}

/// Chat Completions 相容格式；Base URL 包含服務要求的 API 路徑前綴。
class OpenAiCompatibleClient extends AiClient {
  OpenAiCompatibleClient(
    super.connectionConfig,
    super.apiKey, {
    super.transport,
  }) : super.base();
  @override
  Future<List<String>> listModels() async => [
    for (final item in (await getJson('/models'))['data'] as List)
      (item as Map)['id'] as String,
  ];
  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    var complete = false;
    await for (final event in events('/chat/completions', {
      'model': connectionConfig.model,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        for (final message in messages)
          {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.images.isEmpty
                ? message.text
                : [
                    if (message.text.isNotEmpty)
                      {'type': 'text', 'text': message.text},
                    for (final image in message.images)
                      {
                        'type': 'image_url',
                        'image_url': {
                          'url':
                              'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
                        },
                      },
                  ],
          },
      ],
    })) {
      checkAiResponseError(event);
      for (final choice in event['choices'] as List? ?? []) {
        final item = choice as Map;
        final text = (item['delta'] as Map?)?['content'];
        if (text is String) {
          yield text;
        }
        final reason = item['finish_reason'];
        if (reason == 'stop') {
          complete = true;
        } else if (reason != null) {
          throw const AiFailure(AiErrorCode.response);
        }
      }
    }
    if (!complete) {
      throw const AiFailure(AiErrorCode.response);
    }
  }
}

class OpenAiClient extends AiClient {
  OpenAiClient(super.connectionConfig, super.apiKey, {super.transport})
    : super.base();
  @override
  Future<List<String>> listModels() async => [
    for (final model in (await getJson('/v1/models'))['data'] as List)
      (model as Map)['id'] as String,
  ];
  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    final input = <Map<String, Object?>>[];
    for (final message in messages) {
      final content = <Map<String, Object?>>[
        if (message.text.isNotEmpty)
          {
            'type': message.isUser ? 'input_text' : 'output_text',
            'text': message.text,
          },
      ];
      for (final image in message.images) {
        if (connectionConfig.provider == AiProvider.custom) {
          content.add({
            'type': 'input_image',
            'image_url':
                'data:${image.mimeType};base64,${base64Encode(image.bytes)}',
          });
        } else {
          final file = await upload(image);
          content.add({'type': 'input_image', 'file_id': file.id});
        }
      }
      input.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': content,
      });
    }
    var complete = false;
    await for (final event in events('/v1/responses', {
      'model': connectionConfig.model,
      'instructions': systemPrompt,
      'input': input,
      'store': false,
      'stream': true,
    })) {
      if (event['type'] == 'response.output_text.delta') {
        yield event['delta'] as String;
      }
      if (event['type'] == 'response.completed') complete = true;
      if (event['type'] == 'error' ||
          event['type'] == 'response.failed' ||
          event['type'] == 'response.incomplete') {
        throw const AiFailure(AiErrorCode.response);
      }
    }
    if (!complete) throw const AiFailure(AiErrorCode.response);
  }
}

class ClaudeAiClient extends AiClient {
  ClaudeAiClient(super.connectionConfig, super.apiKey, {super.transport})
    : super.base();
  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty) 'x-api-key': apiKey,
    'anthropic-version': '2023-06-01',
    if (connectionConfig.workspaceId.isNotEmpty)
      'anthropic-workspace-id': connectionConfig.workspaceId,
  };
  @override
  Future<List<String>> listModels() async {
    final result = <String>[];
    String? after;
    do {
      final page = await getJson(
        '/v1/models?limit=100${after == null ? '' : '&after_id=${Uri.encodeComponent(after)}'}',
      );
      result.addAll([
        for (final model in page['data'] as List)
          (model as Map)['id'] as String,
      ]);
      after = page['has_more'] == true ? page['last_id'] as String? : null;
    } while (after != null);
    return result;
  }

  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    final input = <Map<String, Object?>>[];
    for (final message in messages) {
      final content = <Map<String, Object?>>[
        if (message.text.isNotEmpty) {'type': 'text', 'text': message.text},
      ];
      for (final image in message.images) {
        if (connectionConfig.provider == AiProvider.custom) {
          content.add({
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          });
        } else {
          final file = await upload(image);
          content.add({
            'type': 'image',
            'source': {'type': 'file', 'file_id': file.id},
          });
        }
      }
      input.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': content,
      });
    }
    var complete = false;
    var truncated = false;
    final streamHeaders = <String, String>{
      ...headers,
      if (connectionConfig.provider != AiProvider.custom)
        'anthropic-beta': 'files-api-2025-04-14',
    };
    await for (final event in events('/v1/messages', {
      'model': connectionConfig.model,
      'system': systemPrompt,
      'messages': input,
      'max_tokens': 8192,
      'stream': true,
    }, requestHeaders: streamHeaders)) {
      if (event['type'] == 'content_block_delta' &&
          (event['delta'] as Map)['type'] == 'text_delta') {
        yield (event['delta'] as Map)['text'] as String;
      }
      if (event['type'] == 'message_delta') {
        truncated = (event['delta'] as Map)['stop_reason'] == 'max_tokens';
      }
      if (event['type'] == 'message_stop') complete = true;
      if (event['type'] == 'error') throw const AiFailure(AiErrorCode.response);
    }
    if (!complete || truncated) throw const AiFailure(AiErrorCode.response);
  }
}

class GeminiAiClient extends AiClient {
  GeminiAiClient(super.connectionConfig, super.apiKey, {super.transport})
    : super.base();
  @override
  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
  };
  @override
  Future<List<String>> listModels() async {
    final result = <String>[];
    String? token;
    do {
      final page = await getJson(
        '/v1beta/models?pageSize=100${token == null ? '' : '&pageToken=${Uri.encodeComponent(token)}'}',
      );
      for (final model in page['models'] as List? ?? []) {
        if (((model as Map)['supportedGenerationMethods'] as List? ?? [])
            .contains('generateContent')) {
          result.add((model['name'] as String).replaceFirst('models/', ''));
        }
      }
      token = page['nextPageToken'] as String?;
    } while (token != null && token.isNotEmpty);
    return result;
  }

  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    final contents = <Map<String, Object?>>[];
    for (final message in messages) {
      final parts = <Map<String, Object?>>[
        if (message.text.isNotEmpty) {'text': message.text},
      ];
      for (final image in message.images) {
        if (connectionConfig.provider == AiProvider.custom) {
          parts.add({
            'inlineData': {
              'mimeType': image.mimeType,
              'data': base64Encode(image.bytes),
            },
          });
        } else {
          final file = await upload(image);
          parts.add({
            'fileData': {'mimeType': image.mimeType, 'fileUri': file.uri},
          });
        }
      }
      contents.add({'role': message.isUser ? 'user' : 'model', 'parts': parts});
    }
    var complete = false;
    final model = connectionConfig.model.replaceFirst('models/', '');
    await for (final event in events(
      '/v1beta/models/${Uri.encodeComponent(model)}:streamGenerateContent?alt=sse',
      {
        'systemInstruction': {
          'parts': [
            {'text': systemPrompt},
          ],
        },
        'contents': contents,
      },
    )) {
      for (final candidate in event['candidates'] as List? ?? []) {
        final candidateData = candidate as Map;
        for (final part
            in (candidateData['content'] as Map?)?['parts'] as List? ?? []) {
          if ((part as Map)['thought'] != true && part['text'] is String) {
            yield part['text'] as String;
          }
        }
        if (candidateData['finishReason'] == 'STOP') complete = true;
        if (candidateData['finishReason'] != null &&
            candidateData['finishReason'] != 'STOP') {
          throw const AiFailure(AiErrorCode.response);
        }
      }
    }
    if (!complete) throw const AiFailure(AiErrorCode.response);
  }
}

class OllamaAiClient extends AiClient {
  OllamaAiClient(super.connectionConfig, super.apiKey, {super.transport})
    : super.base();
  Future<Map<String, dynamic>>? _modelDetailsRequest;
  @override
  Future<List<String>> listModels() async => [
    for (final model in (await getJson('/api/tags'))['models'] as List)
      (model as Map)['name'] as String,
  ];
  Future<bool?> _supportsImages() async {
    final request = _modelDetailsRequest ??= postJson('/api/show', {
      'model': connectionConfig.model,
    });
    try {
      final modelDetails = await request;
      return (modelDetails['capabilities'] as List?)?.contains('vision');
    } on Object {
      if (_modelDetailsRequest == request) _modelDetailsRequest = null;
      rethrow;
    }
  }

  @override
  Stream<String> reply(
    String systemPrompt,
    List<AiInputMessage> messages,
  ) async* {
    if (messages.any((message) => message.images.isNotEmpty) &&
        await _supportsImages() == false) {
      throw const AiFailure(AiErrorCode.imageUnsupported);
    }
    var complete = false;
    await for (final event in events('/api/chat', {
      'model': connectionConfig.model,
      'stream': true,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        for (final message in messages)
          {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.text,
            if (message.images.isNotEmpty)
              'images': [
                for (final image in message.images) base64Encode(image.bytes),
              ],
          },
      ],
    }, ndjson: true)) {
      if (event['error'] != null) throw const AiFailure(AiErrorCode.request);
      final text = (event['message'] as Map?)?['content'];
      if (text is String) yield text;
      if (event['done'] == true) complete = event['done_reason'] != 'length';
    }
    if (!complete) throw const AiFailure(AiErrorCode.response);
  }
}
