import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../presentation/state/app_session_state.dart';

abstract class AppLockService {
  Future<AppSessionState> initialize();

  Future<bool> unlock();

  Future<void> lock();

  Future<bool> isBiometricLockEnabled();

  Future<void> setBiometricLockEnabled(bool enabled);

  Future<String> ensureDeviceSecret();

  Future<void> saveRecoveryWrapKey({
    required String vaultId,
    required List<int> keyBytes,
  });

  Future<List<int>?> readRecoveryWrapKey(String vaultId);
}

class LocalAppLockService implements AppLockService {
  LocalAppLockService({
    LocalAuthentication? localAuthentication,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  static const String _biometricEnabledKey = 'app_lock.biometric_enabled';
  static const String _deviceSecretKey = 'vault.device_secret';
  static const String _sessionLockedKey = 'app_lock.session_locked';
  Map<String, String>? _cache;

  @override
  Future<AppSessionState> initialize() async {
    final bool enabled = await isBiometricLockEnabled();
    final bool locked = (await _readValue(_sessionLockedKey)) == 'true';
    if (!enabled) {
      return const AppSessionState(status: AppLockStatus.unlocked);
    }
    return AppSessionState(
      status: locked ? AppLockStatus.locked : AppLockStatus.unlocked,
      message: locked ? '需要生物辨識或裝置驗證。' : null,
    );
  }

  @override
  Future<bool> unlock() async {
    if (!await isBiometricLockEnabled()) {
      await _writeValue(_sessionLockedKey, 'false');
      return true;
    }

    final bool canCheck = await _localAuthentication.canCheckBiometrics ||
        await _localAuthentication.isDeviceSupported();
    if (!canCheck) {
      await _writeValue(_sessionLockedKey, 'false');
      return true;
    }

    final bool authenticated = await _localAuthentication.authenticate(
      localizedReason: '解鎖 QuillLockDiary',
      biometricOnly: false,
      persistAcrossBackgrounding: true,
    );
    await _writeValue(_sessionLockedKey, authenticated ? 'false' : 'true');
    return authenticated;
  }

  @override
  Future<void> lock() {
    return _writeValue(_sessionLockedKey, 'true');
  }

  @override
  Future<bool> isBiometricLockEnabled() async {
    return (await _readValue(_biometricEnabledKey)) == 'true';
  }

  @override
  Future<void> setBiometricLockEnabled(bool enabled) {
    return _writeValue(_biometricEnabledKey, enabled ? 'true' : 'false');
  }

  @override
  Future<String> ensureDeviceSecret() async {
    final String? existing = await _readValue(_deviceSecretKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final Random random = Random.secure();
    final String generated = base64UrlEncode(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    await _writeValue(_deviceSecretKey, generated);
    return generated;
  }

  @override
  Future<void> saveRecoveryWrapKey({
    required String vaultId,
    required List<int> keyBytes,
  }) {
    return _writeValue(_wrapKeyStorageKey(vaultId), base64Encode(keyBytes));
  }

  @override
  Future<List<int>?> readRecoveryWrapKey(String vaultId) async {
    final String? encoded = await _readValue(_wrapKeyStorageKey(vaultId));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return base64Decode(encoded);
  }

  String _wrapKeyStorageKey(String vaultId) => 'vault.$vaultId.recovery_wrap_key';

  Future<String?> _readValue(String key) async {
    final Map<String, String> store = await _loadStore();
    return store[key];
  }

  Future<void> _writeValue(String key, String value) async {
    final Map<String, String> store = await _loadStore();
    store[key] = value;
    await _persistStore(store);
  }

  Future<Map<String, String>> _loadStore() async {
    if (_cache != null) {
      return _cache!;
    }
    final File file = await _storageFile();
    if (!file.existsSync()) {
      _cache = <String, String>{};
      return _cache!;
    }
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, dynamic>) {
      _cache = decoded.map(
        (String key, dynamic value) => MapEntry(key, value.toString()),
      );
    } else {
      _cache = <String, String>{};
    }
    return _cache!;
  }

  Future<void> _persistStore(Map<String, String> store) async {
    final File file = await _storageFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(store), flush: true);
    _cache = Map<String, String>.from(store);
  }

  Future<File> _storageFile() async {
    final Directory supportDir = await getApplicationSupportDirectory();
    return File(p.join(supportDir.path, 'quill_lock_diary', 'app_lock_store.json'));
  }
}
