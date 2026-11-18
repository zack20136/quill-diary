import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
