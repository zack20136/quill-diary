import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_service.dart';
import 'device_key_manager.dart';
import '../../shared/platform/vault_platform_support.dart';

final deviceKeyManagerProvider = Provider<DeviceKeyManager>((Ref ref) {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return const UnsupportedDeviceKeyManager();
  }
  return AndroidDeviceKeyManager();
});

final appLockServiceProvider = Provider<AppLockService>((Ref ref) {
  if (!ref.watch(vaultPlatformSupportProvider)) {
    return const UnsupportedAppLockService();
  }
  return LocalAppLockService();
});
