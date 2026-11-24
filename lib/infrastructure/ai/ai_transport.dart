import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:quill_diary/domain/ai/ai_connection_settings.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';

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
  IoAiTransport({
    this.responseMaxBytes = 16 * 1024 * 1024,
    this.streamMaxBytes = 32 * 1024 * 1024,
    this.lineMaxBytes = 1024 * 1024,
    this.eventMaxBytes = 4 * 1024 * 1024,
    this.idleTimeout = const Duration(seconds: 60),
    this.totalTimeout = const Duration(minutes: 10),
  });

  final int responseMaxBytes, streamMaxBytes, lineMaxBytes, eventMaxBytes;
  final Duration idleTimeout, totalTimeout;
  final Set<HttpClient> _activeClients = {};
  bool _closed = false;

  HttpClient _openClient() {
    if (_closed) throw const AiFailure(AiErrorCode.network);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    _activeClients.add(client);
    return client;
  }

  void _closeClient(HttpClient client) {
    if (_activeClients.remove(client)) client.close(force: true);
  }

  Future<HttpClientResponse> _send(
    HttpClient client,
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? body,
  ) async {
    final request = await client.openUrl(method, uri);
    request.followRedirects = false;
    headers.forEach(request.headers.set);
    if (body != null) {
      request.contentLength = body.length;
      request.add(body);
    }
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        await response.listen(null).cancel();
      } on Object {
        // 保留已收到的 HTTP 錯誤。
      }
      checkAiStatus(response.statusCode);
    }
    return response;
  }

  Stream<List<int>> _boundedChunks(
    HttpClientResponse response, {
    required int maxBytes,
    bool checkLines = false,
  }) async* {
    var total = 0;
    var lineSize = 0;
    await for (final chunk in response.timeout(idleTimeout)) {
      total += chunk.length;
      if (total > maxBytes) throw const AiFailure(AiErrorCode.response);
      if (checkLines) {
        for (final byte in chunk) {
          if (byte == 10 || byte == 13) {
            lineSize = 0;
          } else if (++lineSize > lineMaxBytes) {
            throw const AiFailure(AiErrorCode.response);
          }
        }
      }
      yield chunk;
    }
  }

  Future<AiHttpResponse> _receive(
    HttpClient client,
    String method,
    Uri uri,
    Map<String, String> headers,
    List<int>? body,
  ) async {
    final response = await _send(
      client,
      method,
      uri,
      headers,
      body,
    ).timeout(idleTimeout);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in _boundedChunks(
      response,
      maxBytes: responseMaxBytes,
    )) {
      bytes.add(chunk);
    }
    return AiHttpResponse(response.statusCode, bytes.takeBytes());
  }

  @override
  Future<AiHttpResponse> request(
    String method,
    Uri uri,
    Map<String, String> headers, [
    List<int>? body,
  ]) async {
    final client = _openClient();
    try {
      return await _receive(
        client,
        method,
        uri,
        headers,
        body,
      ).timeout(totalTimeout);
    } on AiFailure {
      rethrow;
    } on TimeoutException {
      throw const AiFailure(AiErrorCode.timeout);
    } on HandshakeException {
      throw const AiFailure(AiErrorCode.tls);
    } on Object {
      throw const AiFailure(AiErrorCode.network);
    } finally {
      _closeClient(client);
    }
  }

  @override
  Stream<String> stream(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
  ) {
    HttpClient? client;
    StreamSubscription<String>? subscription;
    var cancelled = false;
    final output = StreamController<String>(sync: true);
    output.onListen = () {
      subscription =
          _receiveLines(uri, headers, body, (active) {
            client = active;
            if (cancelled) _closeClient(active);
          }).listen(
            output.add,
            onError: output.addError,
            onDone: () {
              unawaited(output.close());
            },
          );
    };
    output.onPause = () => subscription?.pause();
    output.onResume = () => subscription?.resume();
    output.onCancel = () async {
      cancelled = true;
      if (client case final active?) _closeClient(active);
      await subscription?.cancel();
    };
    return output.stream;
  }

  Stream<String> _receiveLines(
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?> body,
    void Function(HttpClient) onClient,
  ) async* {
    final client = _openClient();
    onClient(client);
    var expired = false;
    final deadline = Timer(totalTimeout, () {
      expired = true;
      _closeClient(client);
    });
    try {
      final response = await _send(
        client,
        'POST',
        uri,
        headers,
        utf8.encode(jsonEncode(body)),
      ).timeout(idleTimeout);
      var sse = response.headers.contentType?.mimeType == 'text/event-stream';
      var eventSize = 0;
      final lines = _boundedChunks(
        response,
        maxBytes: streamMaxBytes,
        checkLines: true,
      ).transform(utf8.decoder).transform(const LineSplitter());
      await for (final line in lines) {
        if (expired) throw TimeoutException('AI stream deadline');
        if (line.isEmpty) {
          eventSize = 0;
        } else if (sse || line.startsWith('data:')) {
          sse = true;
          eventSize += utf8.encode(line).length + 1;
          if (eventSize > eventMaxBytes) {
            throw const AiFailure(AiErrorCode.response);
          }
        }
        yield line;
      }
      if (expired) throw TimeoutException('AI stream deadline');
    } on AiFailure {
      if (expired) throw const AiFailure(AiErrorCode.timeout);
      rethrow;
    } on TimeoutException {
      throw const AiFailure(AiErrorCode.timeout);
    } on HandshakeException {
      throw const AiFailure(AiErrorCode.tls);
    } on Object {
      throw AiFailure(expired ? AiErrorCode.timeout : AiErrorCode.network);
    } finally {
      deadline.cancel();
      _closeClient(client);
    }
  }

  @override
  void close() {
    _closed = true;
    for (final client in _activeClients) {
      client.close(force: true);
    }
    _activeClients.clear();
  }
}
