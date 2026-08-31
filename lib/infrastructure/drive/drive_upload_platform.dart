import 'dart:io';

import 'package:flutter/services.dart';

import 'package:quill_diary/app/app_identifiers.dart';
import 'package:quill_diary/infrastructure/drive/drive_upload_job.dart';

/// 與 Android 原生 Drive 背景上傳服務通訊。
class DriveUploadPlatform {
  DriveUploadPlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methods =
           methodChannel ??
           const MethodChannel(AppIdentifiers.driveUploadChannel),
       _events =
           eventChannel ??
           const EventChannel(AppIdentifiers.driveUploadEventsChannel);

  final MethodChannel _methods;
  final EventChannel _events;

  bool get isSupported => Platform.isAndroid;

  Stream<DriveUploadState> watchState() {
    if (!isSupported) {
      return const Stream<DriveUploadState>.empty();
    }
    return _events.receiveBroadcastStream().map(_decodeState);
  }

  Future<DriveUploadState> getState() async {
    if (!isSupported) {
      return const DriveUploadState();
    }
    final Object? raw = await _methods.invokeMethod<Object?>('getState');
    return _decodeState(raw);
  }

  Future<String> prepareStagingPath({required String fileName}) async {
    _ensureAndroid();
    final Object? raw = await _methods.invokeMethod<Object?>(
      'prepareStagingPath',
      <String, Object?>{'fileName': fileName},
    );
    final String path = '$raw'.trim();
    if (path.isEmpty) {
      throw StateError('無法準備 Google Drive 上傳暫存路徑。');
    }
    return path;
  }

  Future<DriveUploadJobSnapshot> startUpload({
    required String stagingPath,
    required String fileName,
    required int sizeBytes,
  }) async {
    _ensureAndroid();
    final Object? raw = await _methods.invokeMethod<Object?>(
      'startUpload',
      <String, Object?>{
        'stagingPath': stagingPath,
        'fileName': fileName,
        'sizeBytes': sizeBytes,
      },
    );
    final DriveUploadState decoded = _decodeState(raw);
    final DriveUploadJobSnapshot? job = decoded.job;
    if (job == null) {
      throw StateError('無法建立 Google Drive 背景上傳工作。');
    }
    return job;
  }

  Future<void> cancelUpload() async {
    if (!isSupported) {
      return;
    }
    await _methods.invokeMethod<Object?>('cancelUpload');
  }

  Future<DriveUploadState> abandonCancelCleanup(String jobId) async {
    if (!isSupported) {
      return const DriveUploadState();
    }
    final Object? raw = await _methods.invokeMethod<Object?>(
      'abandonCancelCleanup',
      <String, Object?>{'jobId': jobId},
    );
    return _decodeState(raw);
  }

  Future<void> ackFailure(String jobId) async {
    if (!isSupported) {
      return;
    }
    await _methods.invokeMethod<Object?>(
      'ackFailure',
      <String, Object?>{'jobId': jobId},
    );
  }

  /// 原生成功回 job map（或舊版 envelope）；CAS 失敗回 `null`。
  Future<DriveUploadJobSnapshot?> markStatusRecorded(String jobId) async {
    if (!isSupported) {
      return null;
    }
    final Object? raw = await _methods.invokeMethod<Object?>(
      'markStatusRecorded',
      <String, Object?>{'jobId': jobId},
    );
    if (raw == null) {
      return null;
    }
    return _decodeState(raw).job;
  }

  Future<void> finalizeCommitted(String jobId) async {
    if (!isSupported) {
      return;
    }
    await _methods.invokeMethod<Object?>(
      'finalizeCommitted',
      <String, Object?>{'jobId': jobId},
    );
  }

  Future<bool> notificationsAuthorized() async {
    if (!isSupported) {
      return true;
    }
    final Object? raw = await _methods.invokeMethod<Object?>(
      'notificationsAuthorized',
    );
    return raw == true;
  }

  Future<bool> requestNotificationPermission() async {
    if (!isSupported) {
      return true;
    }
    final Object? raw = await _methods.invokeMethod<Object?>(
      'requestNotificationPermission',
    );
    return raw == true;
  }

  Future<bool> consumeOpenDriveBackup() async {
    if (!isSupported) {
      return false;
    }
    final Object? raw = await _methods.invokeMethod<Object?>(
      'consumeOpenDriveBackup',
    );
    return raw == true;
  }

  void _ensureAndroid() {
    if (!isSupported) {
      throw UnsupportedError('Google Drive 背景上傳僅支援 Android。');
    }
  }

  DriveUploadState _decodeState(Object? raw) {
    if (raw == null) {
      return const DriveUploadState();
    }
    if (raw is! Map) {
      return const DriveUploadState();
    }
    final Map<Object?, Object?> map = Map<Object?, Object?>.from(raw);
    // 相容：直接回傳 job map。
    if (map.containsKey('jobId') && map.containsKey('phase')) {
      return DriveUploadState(job: DriveUploadJobSnapshot.fromMap(map));
    }
    return DriveUploadState.fromMap(map);
  }
}
