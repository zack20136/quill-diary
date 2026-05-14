import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/shared/value_objects.dart';

class TrustedDeviceInfo {
  const TrustedDeviceInfo({
    required this.slotId,
    required this.platform,
  });

  final DeviceSlotId slotId;
  final String platform;
}

class DeviceWrappedPayload {
  const DeviceWrappedPayload({
    required this.slotId,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.platform,
  });

  final DeviceSlotId slotId;
  final String nonceBase64;
  final String ciphertextBase64;
  final String platform;
}

class WrappedRecoveryKeyRecord {
  const WrappedRecoveryKeyRecord({
    required this.slotId,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.wrappedAt,
    required this.formatVersion,
    required this.platform,
  });

  final DeviceSlotId slotId;
  final String nonceBase64;
  final String ciphertextBase64;
  final DateTime wrappedAt;
  final int formatVersion;
  final String platform;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'slot_id': slotId,
      'nonce': nonceBase64,
      'ciphertext': ciphertextBase64,
      'wrapped_at': wrappedAt.toIso8601String(),
      'format_version': formatVersion,
      'platform': platform,
    };
  }

  factory WrappedRecoveryKeyRecord.fromJson(Map<Object?, Object?> json) {
    return WrappedRecoveryKeyRecord(
      slotId: '${json['slot_id'] ?? ''}',
      nonceBase64: '${json['nonce'] ?? ''}',
      ciphertextBase64: '${json['ciphertext'] ?? ''}',
      wrappedAt: DateTime.tryParse('${json['wrapped_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      formatVersion: int.tryParse('${json['format_version'] ?? 1}') ?? 1,
      platform: '${json['platform'] ?? ''}',
    );
  }
}

abstract class DeviceKeyManager {
  Future<bool> hasTrustedKey(VaultId vaultId);

  Future<TrustedDeviceInfo> ensureDeviceKey(VaultId vaultId);

  Future<TrustedDeviceInfo?> readDeviceInfo(VaultId vaultId);

  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required VaultId vaultId,
    required List<int> plaintextBytes,
  });

  Future<List<int>> unwrapWithDeviceKey({
    required VaultId vaultId,
    required DeviceSlotId slotId,
    required String nonceBase64,
    required String ciphertextBase64,
  });

  Future<void> storeWrappedRecoveryKey({
    required VaultId vaultId,
    required WrappedRecoveryKeyRecord record,
  });

  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(VaultId vaultId);

  Future<void> clearTrustedKey(VaultId vaultId);
}

class AndroidDeviceKeyManager implements DeviceKeyManager {
  AndroidDeviceKeyManager({
    MethodChannel? channel,
    FlutterSecureStorage? storage,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                sharedPreferencesName: 'quill_lock_diary_device',
              ),
            );

  static const String _channelName = 'quill_lock_diary/device_key_bridge';
  final MethodChannel _channel;
  final FlutterSecureStorage _storage;

  @override
  Future<void> clearTrustedKey(VaultId vaultId) async {
    await _channel.invokeMethod<void>('deleteKey', <String, Object?>{
      'vaultId': vaultId,
    });
    await _storage.delete(key: _deviceInfoStorageKey(vaultId));
    await _storage.delete(key: _wrappedRecoveryKeyStorageKey(vaultId));
  }

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(VaultId vaultId) async {
    final Map<Object?, Object?> result = await _channel.invokeMapMethod<Object?, Object?>(
          'ensureKey',
          <String, Object?>{'vaultId': vaultId},
        ) ??
        <Object?, Object?>{};

    final TrustedDeviceInfo info = TrustedDeviceInfo(
      slotId: '${result['slotId'] ?? ''}',
      platform: '${result['platform'] ?? ''}',
    );

    await _storage.write(
      key: _deviceInfoStorageKey(vaultId),
      value: jsonEncode(<String, Object?>{
        'slot_id': info.slotId,
        'platform': info.platform,
      }),
    );
    return info;
  }

  @override
  Future<bool> hasTrustedKey(VaultId vaultId) async {
    final bool platformHasKey = await _channel.invokeMethod<bool>(
          'hasKey',
          <String, Object?>{'vaultId': vaultId},
        ) ??
        false;
    if (!platformHasKey) {
      return false;
    }
    return await readWrappedRecoveryKey(vaultId) != null;
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(VaultId vaultId) async {
    final String? encoded = await _storage.read(key: _deviceInfoStorageKey(vaultId));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final Map<Object?, Object?> decoded = jsonDecode(encoded) as Map<Object?, Object?>;
    final TrustedDeviceInfo info = TrustedDeviceInfo(
      slotId: '${decoded['slot_id'] ?? ''}',
      platform: '${decoded['platform'] ?? ''}',
    );
    if (info.slotId.isEmpty) {
      return null;
    }
    return info;
  }

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(VaultId vaultId) async {
    final String? encoded = await _storage.read(key: _wrappedRecoveryKeyStorageKey(vaultId));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return WrappedRecoveryKeyRecord.fromJson(
      jsonDecode(encoded) as Map<Object?, Object?>,
    );
  }

  @override
  Future<void> storeWrappedRecoveryKey({
    required VaultId vaultId,
    required WrappedRecoveryKeyRecord record,
  }) {
    return _storage.write(
      key: _wrappedRecoveryKeyStorageKey(vaultId),
      value: jsonEncode(record.toJson()),
    );
  }

  @override
  Future<List<int>> unwrapWithDeviceKey({
    required VaultId vaultId,
    required DeviceSlotId slotId,
    required String nonceBase64,
    required String ciphertextBase64,
  }) async {
    final List<Object?>? result = await _channel.invokeListMethod<Object?>(
      'unwrapWithDeviceKey',
      <String, Object?>{
        'vaultId': vaultId,
        'slotId': slotId,
        'nonce': nonceBase64,
        'ciphertext': ciphertextBase64,
      },
    );
    if (result == null) {
      throw StateError('無法使用裝置金鑰解開資料。');
    }
    return result.map((Object? item) => item as int).toList(growable: false);
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required VaultId vaultId,
    required List<int> plaintextBytes,
  }) async {
    final Map<Object?, Object?> result = await _channel.invokeMapMethod<Object?, Object?>(
          'wrapWithDeviceKey',
          <String, Object?>{
            'vaultId': vaultId,
            'plaintext': plaintextBytes,
          },
        ) ??
        <Object?, Object?>{};

    return DeviceWrappedPayload(
      slotId: '${result['slotId'] ?? ''}',
      nonceBase64: '${result['nonce'] ?? ''}',
      ciphertextBase64: '${result['ciphertext'] ?? ''}',
      platform: '${result['platform'] ?? ''}',
    );
  }

  String _deviceInfoStorageKey(VaultId vaultId) => 'vault.$vaultId.device_info';

  String _wrappedRecoveryKeyStorageKey(VaultId vaultId) =>
      'vault.$vaultId.wrapped_recovery_key';
}

class UnsupportedDeviceKeyManager implements DeviceKeyManager {
  const UnsupportedDeviceKeyManager();

  UnsupportedError get _error => UnsupportedError('目前僅支援 Android 裝置。');

  @override
  Future<void> clearTrustedKey(VaultId vaultId) async {}

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(VaultId vaultId) async => throw _error;

  @override
  Future<bool> hasTrustedKey(VaultId vaultId) async => false;

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(VaultId vaultId) async => null;

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(VaultId vaultId) async => null;

  @override
  Future<void> storeWrappedRecoveryKey({
    required VaultId vaultId,
    required WrappedRecoveryKeyRecord record,
  }) async => throw _error;

  @override
  Future<List<int>> unwrapWithDeviceKey({
    required VaultId vaultId,
    required DeviceSlotId slotId,
    required String nonceBase64,
    required String ciphertextBase64,
  }) async => throw _error;

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required VaultId vaultId,
    required List<int> plaintextBytes,
  }) async => throw _error;
}
