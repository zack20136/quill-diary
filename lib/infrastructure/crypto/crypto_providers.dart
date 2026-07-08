import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'crypto_service.dart';

final cryptoServiceProvider = Provider<CryptoService>((Ref ref) {
  return LocalCryptoService();
});
