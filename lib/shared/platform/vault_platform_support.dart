import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 目前只有 Android 原生環境支援完整 vault 能力。
bool get isVaultPlatformSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Vault 相關功能是否可用的單一來源。
final vaultPlatformSupportProvider = Provider<bool>((Ref ref) {
  return isVaultPlatformSupported;
});
