enum AiErrorCode {
  privacy,
  configuration,
  settings,
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

  /// 只含錯誤代碼。HTTP 狀態留在 [status]，避免描述帶出回應內容。
  @override
  String toString() => 'AiFailure(${code.name})';
}
