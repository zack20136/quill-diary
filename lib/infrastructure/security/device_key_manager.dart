import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/infrastructure/security/keystore_unlock_policy.dart';
import 'package:quill_diary/shared/app_identifiers.dart';
import 'package:quill_diary/shared/data_versions.dart';

class TrustedDeviceInfo {
  const TrustedDeviceInfo({required this.slotId, required this.platform});

  final DeviceSlotId slotId;
  final String platform;
}

/// 原生 Android 以裝置金鑰包裝位元組後回傳的密文。
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

class RewrapTrustedRecoveryKeyResult {
  const RewrapTrustedRecoveryKeyResult({
    required this.recoveryWrapKey,
    required this.payload,
  });

  final List<int> recoveryWrapKey;
  final DeviceWrappedPayload payload;
}

/// 持久化的可信裝置 Recovery Key 包裝材料副本。
///
/// 儲存於安全儲存區，並以 [formatVersion] 驗證。
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
    final version = json['format_version'] ?? DataVersions.wrappedRecoveryKey;
    if (version is! int || version != DataVersions.wrappedRecoveryKey) {
      throw const DeviceKeyUnsupportedFormatException();
    }
    final slotId = _requiredDeviceString(json['slot_id']);
    final nonce = _requiredDeviceString(json['nonce']);
    final ciphertext = _requiredDeviceString(json['ciphertext']);
    try {
      if (base64Decode(nonce).length != 12 ||
          base64Decode(ciphertext).length < 16) {
        throw const FormatException('裝置金鑰密文長度不正確');
      }
    } on FormatException {
      throw const DeviceKeyUnsupportedFormatException();
    }
    final rawTime = json['wrapped_at'];
    final time = rawTime == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : rawTime is String
        ? DateTime.tryParse(rawTime)
        : null;
    if (time == null ||
        json['platform'] != null && json['platform'] is! String) {
      throw const DeviceKeyUnsupportedFormatException();
    }
    return WrappedRecoveryKeyRecord(
      slotId: slotId,
      nonceBase64: nonce,
      ciphertextBase64: ciphertext,
      wrappedAt: time,
      formatVersion: version,
      platform: json['platform'] as String? ?? '',
    );
  }
}

Map<Object?, Object?> _decodeDeviceRecord(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is! Map) throw const DeviceKeyUnsupportedFormatException();
    return decoded;
  } on FormatException {
    throw const DeviceKeyUnsupportedFormatException();
  }
}

String _requiredDeviceString(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const DeviceKeyUnsupportedFormatException();
  }
  return value;
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

final class DeviceKeyNoDeviceCredentialException extends DeviceKeyException {
  const DeviceKeyNoDeviceCredentialException([
    super.message = '請先在裝置設定中建立螢幕鎖，才能使用此解鎖方式。',
  ]);
}

final class DeviceKeyAuthLockoutException extends DeviceKeyException {
  const DeviceKeyAuthLockoutException([super.message = '驗證失敗次數過多，請稍後再試。']);
}

final class DeviceKeyAuthTimeoutException extends DeviceKeyException {
  const DeviceKeyAuthTimeoutException([super.message = '驗證逾時，請再試一次。']);
}

final class DeviceKeyInvalidatedException extends DeviceKeyException {
  const DeviceKeyInvalidatedException([super.message = '裝置金鑰已失效。']);
}

final class DeviceKeyUnsupportedFormatException extends DeviceKeyException {
  const DeviceKeyUnsupportedFormatException([
    super.message = '可信裝置資料格式不符，請使用復原金鑰重新建立。',
  ]);
}

/// 日記庫復原邏輯與平台保護裝置金鑰之間的橋接層。
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

  /// 以單次裝置驗證將既有包裝金鑰遷移至目標 Keystore 策略。
  Future<RewrapTrustedRecoveryKeyResult> rewrapTrustedRecoveryKey({
    required VaultId vaultId,
    required DeviceSlotId sourceSlotId,
    required String nonceBase64,
    required String ciphertextBase64,
    required KeystoreAuthKind targetAuthKind,
  });

  Future<void> storeWrappedRecoveryKey({
    required VaultId vaultId,
    required WrappedRecoveryKeyRecord record,
  });

  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(VaultId vaultId);

  Future<void> clearTrustedKey(VaultId vaultId);

  Future<void> purgeInactiveDeviceKeys(
    VaultId vaultId, {
    required KeystoreAuthKind activeAuthKind,
  });
}

/// 以 MethodChannel 與 flutter_secure_storage 為後端的 Android 實作。
class AndroidDeviceKeyManager implements DeviceKeyManager {
  AndroidDeviceKeyManager({
    MethodChannel? channel,
    FlutterSecureStorage? storage,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _storage =
           storage ??
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
  Future<void> purgeInactiveDeviceKeys(
    VaultId vaultId, {
    required KeystoreAuthKind activeAuthKind,
  }) async {
    try {
      await _channel.invokeMethod<void>(
        'purgeInactiveDeviceKeys',
        <String, Object?>{
          'vaultId': vaultId,
          'keystoreAuthKind': activeAuthKind.wireValue,
        },
      );
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
  }

  @override
  Future<TrustedDeviceInfo> ensureDeviceKey(
    VaultId vaultId, {
    required KeystoreAuthKind authKind,
  }) async {
    try {
      final Map<Object?, Object?> result =
          await _channel.invokeMapMethod<Object?, Object?>(
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
    final bool platformHasKey =
        await _channel.invokeMethod<bool>('hasKey', <String, Object?>{
          'vaultId': vaultId,
        }) ??
        false;
    if (!platformHasKey) {
      return false;
    }
    return await readWrappedRecoveryKey(vaultId) != null;
  }

  @override
  Future<TrustedDeviceInfo?> readDeviceInfo(VaultId vaultId) async {
    final String? encoded = await _storage.read(
      key: _deviceInfoStorageKey(vaultId),
    );
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = _decodeDeviceRecord(encoded);
    if (decoded['platform'] != null && decoded['platform'] is! String) {
      throw const DeviceKeyUnsupportedFormatException();
    }
    final TrustedDeviceInfo info = TrustedDeviceInfo(
      slotId: _requiredDeviceString(decoded['slot_id']),
      platform: decoded['platform'] as String? ?? '',
    );
    return info;
  }

  @override
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(
    VaultId vaultId,
  ) async {
    final String? encoded = await _storage.read(
      key: _wrappedRecoveryKeyStorageKey(vaultId),
    );
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    return WrappedRecoveryKeyRecord.fromJson(_decodeDeviceRecord(encoded));
  }

  @override
  Future<RewrapTrustedRecoveryKeyResult> rewrapTrustedRecoveryKey({
    required VaultId vaultId,
    required DeviceSlotId sourceSlotId,
    required String nonceBase64,
    required String ciphertextBase64,
    required KeystoreAuthKind targetAuthKind,
  }) async {
    try {
      final Map<Object?, Object?> result =
          await _channel.invokeMapMethod<Object?, Object?>(
            'rewrapTrustedRecoveryKey',
            <String, Object?>{
              'vaultId': vaultId,
              'sourceSlotId': sourceSlotId,
              'nonce': nonceBase64,
              'ciphertext': ciphertextBase64,
              'keystoreAuthKind': targetAuthKind.wireValue,
            },
          ) ??
          <Object?, Object?>{};
      final List<Object?>? recoveryWrapKey =
          result['recoveryWrapKey'] as List<Object?>?;
      if (recoveryWrapKey == null) {
        throw const DeviceKeyInvalidatedException('無法遷移可信裝置金鑰。');
      }
      return RewrapTrustedRecoveryKeyResult(
        recoveryWrapKey: recoveryWrapKey
            .map((Object? item) => item as int)
            .toList(growable: false),
        payload: DeviceWrappedPayload(
          slotId: '${result['slotId'] ?? ''}',
          nonceBase64: '${result['nonce'] ?? ''}',
          ciphertextBase64: '${result['ciphertext'] ?? ''}',
          platform: '${result['platform'] ?? ''}',
        ),
      );
    } on PlatformException catch (error) {
      throw _mapPlatformException(error);
    }
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
      final Map<Object?, Object?> result =
          await _channel.invokeMapMethod<Object?, Object?>(
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
      case 'device_key_auth_timeout':
        return DeviceKeyAuthTimeoutException(error.message ?? '驗證逾時，請再試一次。');
      case 'device_key_auth_lockout':
        return DeviceKeyAuthLockoutException(
          error.message ?? '驗證失敗次數過多，請稍後再試。',
        );
      case 'device_key_no_device_credential':
        return DeviceKeyNoDeviceCredentialException(
          error.message ?? '請先在裝置設定中建立螢幕鎖，才能使用此解鎖方式。',
        );
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
  Future<WrappedRecoveryKeyRecord?> readWrappedRecoveryKey(
    VaultId vaultId,
  ) async => null;

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

  @override
  Future<RewrapTrustedRecoveryKeyResult> rewrapTrustedRecoveryKey({
    required VaultId vaultId,
    required DeviceSlotId sourceSlotId,
    required String nonceBase64,
    required String ciphertextBase64,
    required KeystoreAuthKind targetAuthKind,
  }) async => throw _error;

  @override
  Future<void> purgeInactiveDeviceKeys(
    VaultId vaultId, {
    required KeystoreAuthKind activeAuthKind,
  }) async => throw _error;
}
