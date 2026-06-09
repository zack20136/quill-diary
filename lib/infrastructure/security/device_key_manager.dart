import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_identifiers.dart';
import '../../domain/shared/value_objects.dart';
import 'keystore_unlock_policy.dart';

/// Public metadata for a trusted-device key slot.
class TrustedDeviceInfo {
  const TrustedDeviceInfo({
    required this.slotId,
    required this.platform,
  });

  final DeviceSlotId slotId;
  final String platform;
}

/// Ciphertext returned by native Android after wrapping bytes with a device key.
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

/// Persisted trusted-device copy of Recovery Key wrapping material.
///
/// Stored in secure storage and validated with [formatVersion] so unsupported
/// legacy records can be discarded instead of misread.
class WrappedRecoveryKeyRecord {
  const WrappedRecoveryKeyRecord({
    required this.slotId,
    required this.nonceBase64,
    required this.ciphertextBase64,
    required this.wrappedAt,
    required this.formatVersion,
    required this.platform,
  });

  static const int kWrappedRecoveryKeyFormatVersion = 1;

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
    final int formatVersion =
        int.tryParse('${json['format_version'] ?? kWrappedRecoveryKeyFormatVersion}') ??
            kWrappedRecoveryKeyFormatVersion;
    if (formatVersion != kWrappedRecoveryKeyFormatVersion) {
      throw DeviceKeyLegacyStateException(
        '不支援的受信任裝置金鑰格式版本：$formatVersion。',
      );
    }
    return WrappedRecoveryKeyRecord(
      slotId: '${json['slot_id'] ?? ''}',
      nonceBase64: '${json['nonce'] ?? ''}',
      ciphertextBase64: '${json['ciphertext'] ?? ''}',
      wrappedAt: DateTime.tryParse('${json['wrapped_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      formatVersion: formatVersion,
      platform: '${json['platform'] ?? ''}',
    );
  }
}

sealed class DeviceKeyException implements Exception {
  const DeviceKeyException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DeviceKeyUserCancelledException extends DeviceKeyException {
  const DeviceKeyUserCancelledException() : super('使用者已取消裝置驗證。');
}

final class DeviceKeyAuthFailedException extends DeviceKeyException {
  const DeviceKeyAuthFailedException([super.message = '裝置驗證失敗。']);
}

final class DeviceKeyBiometricNotEnrolledException extends DeviceKeyException {
  const DeviceKeyBiometricNotEnrolledException()
      : super('啟用生物驗證前，請先到裝置設定新增至少一種生物辨識。');
}

final class DeviceKeyInvalidatedException extends DeviceKeyException {
  const DeviceKeyInvalidatedException([super.message = '裝置金鑰已失效。']);
}

final class DeviceKeyLegacyStateException extends DeviceKeyException {
  const DeviceKeyLegacyStateException([
    super.message = '受信任裝置資料屬於舊版格式，請使用復原金鑰重新建立。',
  ]);
}

/// Bridge between vault recovery logic and platform-protected device keys.
abstract class DeviceKeyManager {
  Future<bool> hasTrustedKey(VaultId vaultId);

  Future<TrustedDeviceInfo> ensureDeviceKey(
    VaultId vaultId, {
    required KeystoreAuthKind authKind,
  });

  Future<TrustedDeviceInfo?> readDeviceInfo(VaultId vaultId);

  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required VaultId vaultId,
    required List<int> plaintextBytes,
    required KeystoreAuthKind authKind,
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

/// Android implementation backed by MethodChannel plus flutter_secure_storage.
class AndroidDeviceKeyManager implements DeviceKeyManager {
  AndroidDeviceKeyManager({
    MethodChannel? channel,
    FlutterSecureStorage? storage,
  })  : _channel = channel ?? const MethodChannel(_channelName),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                storageNamespace: AppIdentifiers.secureStorageNamespace,
              ),
            );

  static const String _channelName = AppIdentifiers.deviceKeyChannel;
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
  Future<TrustedDeviceInfo> ensureDeviceKey(
    VaultId vaultId, {
    required KeystoreAuthKind authKind,
  }) async {
    try {
      final Map<Object?, Object?> result = await _channel.invokeMapMethod<Object?, Object?>(
            'ensureKey',
            <String, Object?>{
              'vaultId': vaultId,
              'keystoreAuthKind': authKind.wireValue,
            },
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
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
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
    try {
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
        throw const DeviceKeyInvalidatedException('無法使用裝置金鑰解開資料。');
      }
      return result.map((Object? item) => item as int).toList(growable: false);
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  @override
  Future<DeviceWrappedPayload> wrapWithDeviceKey({
    required VaultId vaultId,
    required List<int> plaintextBytes,
    required KeystoreAuthKind authKind,
  }) async {
    try {
      final Map<Object?, Object?> result = await _channel.invokeMapMethod<Object?, Object?>(
            'wrapWithDeviceKey',
            <String, Object?>{
              'vaultId': vaultId,
              'plaintext': plaintextBytes,
              'keystoreAuthKind': authKind.wireValue,
            },
          ) ??
          <Object?, Object?>{};

      return DeviceWrappedPayload(
        slotId: '${result['slotId'] ?? ''}',
        nonceBase64: '${result['nonce'] ?? ''}',
        ciphertextBase64: '${result['ciphertext'] ?? ''}',
        platform: '${result['platform'] ?? ''}',
      );
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  String _deviceInfoStorageKey(VaultId vaultId) => 'vault.$vaultId.device_info';

  String _wrappedRecoveryKeyStorageKey(VaultId vaultId) =>
      'vault.$vaultId.wrapped_recovery_key';

  DeviceKeyException _mapPlatformException(PlatformException error) {
    if (_isBiometricEnrollmentMissing(error)) {
      return const DeviceKeyBiometricNotEnrolledException();
    }

    switch (error.code) {
      case 'device_key_auth_cancelled':
        return const DeviceKeyUserCancelledException();
      case 'device_key_auth_failed':
        return DeviceKeyAuthFailedException(error.message ?? '裝置驗證失敗。');
      case 'device_key_invalidated':
        return DeviceKeyInvalidatedException(error.message ?? '裝置金鑰已失效。');
      default:
        return DeviceKeyInvalidatedException(error.message ?? '未知的裝置金鑰錯誤。');
    }
  }

  bool _isBiometricEnrollmentMissing(PlatformException error) {
    if (error.code == 'device_key_biometric_not_enrolled') {
      return true;
    }

    final String message = error.message?.toLowerCase() ?? '';
    return message.contains('at least one biometric must be enrolled');
  }
}

class UnsupportedDeviceKeyManager implements DeviceKeyManager {
  const UnsupportedDeviceKeyManager();

  UnsupportedError get _error => UnsupportedError('目前僅支援 Android 裝置。');

  @override
  Future<void> clearTrustedKey(VaultId vaultId) async {}

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(
    VaultId vaultId, {
    required KeystoreAuthKind authKind,
  }) async => throw _error;

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
    required KeystoreAuthKind authKind,
  }) async => throw _error;
}
