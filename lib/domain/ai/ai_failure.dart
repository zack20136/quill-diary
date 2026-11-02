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
