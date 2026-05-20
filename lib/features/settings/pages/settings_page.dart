import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../infrastructure/storage/restore_precheck.dart';
import '../../../infrastructure/storage/vault_archive_io.dart';
import '../../../shared/providers/core_providers.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_sections.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController = TextEditingController();
  bool _busy = false;
  String? _busyMessage;

  @override
  void dispose() {
    _recoveryKeyInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSupportedPlatform = ref.watch(supportedPlatformProvider);
    final AsyncValue<AppSessionState> sessionAsync = ref.watch(effectiveAppSessionProvider);
    final AsyncValue<RecoveryMetadata?> recoveryMetadataAsync = ref.watch(recoveryMetadataProvider);
    final AppLockService appLockService = ref.watch(appLockServiceProvider);
    final AppSessionState? sessionState = sessionAsync.asData?.value;
    final bool canBackupRestore =
        sessionState?.isUnlocked == true && sessionState?.session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                if (!isSupportedPlatform)
                  const SettingsSectionCard(
                    title: '平台限制',
                    description: '此版本僅支援 Android 上的加密日記庫。',
                    child: SettingsInfoBanner(
                      icon: Icons.phone_android_rounded,
                      message: kAndroidOnlyMessage,
                    ),
                  ),
                if (isSupportedPlatform) ...<Widget>[
                  sessionAsync.when(
                    data: (AppSessionState sessionState) {
                      return SettingsSectionCard(
                        title: '安全鎖狀態',
                        description: '查看安全鎖是否已解除，必要時可用復原金鑰重新進入。',
                        child: SettingsStatusPanel(
                          sessionState: sessionState,
                          busy: _busy,
                          recoveryKeyInputController: _recoveryKeyInputController,
                          bannerIcon: _sessionIcon(sessionState.status),
                          bannerMessage: _sessionSummary(sessionState),
                          bannerTone: _sessionTone(sessionState.status),
                          onUnlockWithRecovery: sessionState.status == AppLockStatus.recoveryRequired
                              ? () => _runAction(() async {
                                    await ref.read(appSessionProvider.notifier).unlockWithRecovery(
                                          _recoveryKeyInputController.text.trim(),
                                        );
                                    await refreshEntryIndexCaches(ref);
                                  })
                              : null,
                          onRetryTrustedUnlock:
                              sessionState.status == AppLockStatus.locked
                                  ? () => _runAction(() async {
                                        final bool ok =
                                            await ref.read(appSessionProvider.notifier).unlock();
                                        if (ok) {
                                          await refreshEntryIndexCaches(ref);
                                        }
                                      })
                                  : null,
                        ),
                      );
                    },
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsSectionCard(
                      title: '安全鎖狀態',
                      description: '讀取狀態時發生錯誤。',
                      child: SettingsInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: '$error',
                        tone: SettingsBannerTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  recoveryMetadataAsync.when(
                    data: (RecoveryMetadata? metadata) {
                      return SettingsSectionCard(
                        title: '復原金鑰',
                        description: '裝置無法自動解鎖時的備用金鑰，請妥善保存。',
                        child: RecoveryKeySectionBody(
                          metadata: metadata,
                          busy: _busy,
                          onCreateRecoveryKey: metadata != null
                              ? null
                              : () => _runAction(() async {
                                    final result = await ref.read(vaultRepositoryProvider).setupRecoveryKey();
                                    ref.read(appSessionProvider.notifier).activateSession(
                                          result.session,
                                          message: kRecoverySetupSuccessMessage,
                                        );
                                    ref.invalidate(recoveryMetadataProvider);
                                    await refreshEntryIndexCaches(ref);
                                    if (!context.mounted) {
                                      return;
                                    }
                                    await showDialog<void>(
                                      context: context,
                                      builder: (BuildContext context) => AlertDialog(
                                        title: const Text('請保存復原金鑰'),
                                        content: SelectableText(result.recoveryKey),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('關閉'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                        ),
                      );
                    },
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsSectionCard(
                      title: '復原金鑰',
                      description: '讀取復原金鑰設定失敗。',
                      child: SettingsInfoBanner(
                        icon: Icons.error_outline_rounded,
                        message: '$error',
                        tone: SettingsBannerTone.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: '生物驗證',
                    description: '重新開啟應用程式時，以指紋或臉部驗證解鎖。',
                    child: FutureBuilder<bool>(
                      future: appLockService.isBiometricLockEnabled(),
                      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                        return SettingsToggleTile(
                          title: '啟用生物驗證',
                          description: '開啟後，重新開啟應用程式需通過裝置驗證才能解鎖。',
                          value: snapshot.data ?? false,
                          onChanged: _busy
                              ? null
                              : (bool value) => _runAction(() async {
                                    final UnlockedVaultSession? session =
                                        await ref.read(activeVaultSessionProvider.future);
                                    if (session != null) {
                                      final UnlockedVaultSession refreshed = await ref
                                          .read(vaultRepositoryProvider)
                                          .refreshTrustedSessionProtection(
                                            session,
                                            biometricRequired: value,
                                          );
                                      ref.read(appSessionProvider.notifier).activateSession(refreshed);
                                    }
                                    await appLockService.setBiometricLockEnabled(value);
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.swap_horiz_rounded,
                    title: '匯入與匯出',
                    description: '匯出日記為 Markdown 壓縮檔，或匯入 Markdown、HTML 與 zip 檔。',
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: '匯出日記',
                          icon: Icons.file_open_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy
                              ? null
                              : () => _runAction(
                                    () async {
                                    final String? exportPath = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((UnlockedVaultSession session) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .exportMarkdownWithPicker(session);
                                    });
                                    if (exportPath == null) {
                                      return;
                                    }
                                    _showMessage('已匯出 Markdown 壓縮檔：$exportPath');
                                  },
                                    progressMessage: '正在匯出日記，整理內容與附件中…',
                                  ),
                        ),
                        SettingsActionButton(
                          label: '匯入 Markdown、HTML 或 zip',
                          icon: Icons.download_rounded,
                          fullWidth: true,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final PortableImportResult? result = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((UnlockedVaultSession session) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .importDocumentsWithPicker(session);
                                    });
                                    if (result == null || result.importedEntries == 0) {
                                      return;
                                    }
                                    await refreshEntryIndexCaches(ref);
                                    final String importMessage = result.skippedFiles > 0
                                        ? '已匯入 ${result.importedEntries} 篇日記，略過 ${result.skippedFiles} 個檔案。'
                                        : '已匯入 ${result.importedEntries} 篇日記。';
                                    _showMessage(importMessage);
                                  }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.storage_rounded,
                    title: '本機備份與還原',
                    description: canBackupRestore
                        ? '備份全部日記到本機；還原會覆寫本機資料，必要時需輸入建立備份時保存的復原金鑰。'
                        : kRestoreNeedsUnlockMessage,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: '建立本機備份',
                          icon: Icons.archive_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy || !canBackupRestore
                              ? null
                              : () => _runAction(() async {
                                    final String? savedPath = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .createBackupWithPicker();
                                    });
                                    if (savedPath == null) {
                                      return;
                                    }
                                    _showMessage('已建立本機備份：$savedPath');
                                  }),
                        ),
                        SettingsActionButton(
                          label: '還原本機備份',
                          icon: Icons.restore_rounded,
                          fullWidth: true,
                          onPressed: _busy || !canBackupRestore
                              ? null
                              : () => _runRestoreFromLocalBackup(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.cloud_outlined,
                    title: 'Google Drive 備份與還原',
                    description: canBackupRestore
                        ? '上傳備份到 Google Drive，或從雲端還原（還原後可能需復原金鑰）。'
                        : kRestoreNeedsUnlockMessage,
                    child: SettingsActionGroup(
                      actions: <SettingsActionButton>[
                        SettingsActionButton(
                          label: '上傳到 Google Drive',
                          icon: Icons.cloud_upload_outlined,
                          emphasized: true,
                          fullWidth: true,
                          onPressed: _busy || !canBackupRestore
                              ? null
                              : () => _runAction(() async {
                                    await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .uploadBackupToDrive();
                                    });
                                    _showMessage('已上傳備份到 Google Drive。');
                                  }),
                        ),
                        SettingsActionButton(
                          label: '從 Google Drive 還原',
                          icon: Icons.cloud_download_outlined,
                          fullWidth: true,
                          onPressed: _busy || !canBackupRestore
                              ? null
                              : () => _runRestoreFromGoogleDrive(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_busy)
              SettingsBlockingProgressOverlay(
                message: _busyMessage ?? '處理中，請稍候…',
              ),
          ],
        ),
      ),
    );
  }

  Future<DriveBackupFile?> _pickDriveBackup(List<DriveBackupFile> backups) async {
    if (backups.isEmpty) {
      _showMessage('Google Drive 上沒有可還原的備份。');
      return null;
    }
    if (!mounted) {
      return null;
    }
    return showDialog<DriveBackupFile>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('選擇 Google Drive 備份'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: backups.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final DriveBackupFile backup = backups[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: Text(backup.name),
                  subtitle: Text(_formatDriveBackupTime(backup.createdAt)),
                  onTap: () => Navigator.of(dialogContext).pop(backup),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  String _formatDriveBackupTime(DateTime? value) {
    if (value == null) {
      return '建立時間未知';
    }
    return value.toLocal().toString().replaceFirst('.000', '');
  }

  Future<void> _runRestoreFromLocalBackup() async {
    final File? backupFile =
        await ref.read(vaultTransferServiceProvider).pickLocalBackupFile();
    if (backupFile == null) {
      return;
    }
    await _restoreBackupFileWithFlow(backupFile);
  }

  Future<void> _runRestoreFromGoogleDrive() async {
    await _runAction(() async {
      final List<DriveBackupFile> backups = await ref
          .read(appSessionProvider.notifier)
          .runSensitiveTask((_) {
        return ref.read(vaultTransferServiceProvider).listDriveBackups();
      });
      final DriveBackupFile? backup = await _pickDriveBackup(backups);
      if (backup == null) {
        return;
      }
      final File tempBackup = await ref
          .read(appSessionProvider.notifier)
          .runSensitiveTask((_) {
        return ref.read(vaultTransferServiceProvider).downloadDriveBackupToTempFile(backup);
      });
      try {
        await _restoreBackupFileWithFlow(tempBackup, driveBackupName: backup.name);
      } finally {
        if (tempBackup.existsSync()) {
          await tempBackup.delete();
        }
      }
    });
  }

  Future<void> _restoreBackupFileWithFlow(
    File backupFile, {
    String? driveBackupName,
  }) async {
    try {
      final RestorePrecheck precheck =
          await ref.read(vaultTransferServiceProvider).precheckRestore(backupFile);
      if (!mounted) {
        return;
      }
      final bool confirmed = await _confirmRestore(precheck, driveBackupName: driveBackupName);
      if (!confirmed) {
        return;
      }
      await _runAction(
        () async {
          await ref.read(appSessionProvider.notifier).runSensitiveTask((_) async {
            await ref.read(vaultTransferServiceProvider).restoreFromBackupFile(backupFile);
          });
          await _finishRestoreAfterSuccess();
        },
        progressMessage: kRestoreInProgressMessage,
      );
    } on StateError catch (error) {
      _showMessage(error.message);
    }
  }

  Future<bool> _confirmRestore(
    RestorePrecheck precheck, {
    String? driveBackupName,
  }) async {
    final List<String> bullets = buildRestoreConfirmBulletPoints(precheck);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text(driveBackupName == null ? '還原本機備份？' : '還原 Google Drive 備份？'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (driveBackupName != null) ...<Widget>[
                      Text('檔案：$driveBackupName'),
                      const SizedBox(height: 12),
                    ],
                    for (final String bullet in bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text('• '),
                            Expanded(child: Text(bullet)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('還原'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _finishRestoreAfterSuccess() async {
    await _resetAppState();
    final AppSessionState startupState = await ref.read(appStartupProvider.future);
    if (startupState.isUnlocked && startupState.session != null) {
      await refreshEntryIndexCaches(ref);
    }
    if (mounted) {
      context.go(AppRouter.homeRoute);
      _showMessage(
        snackbarMessageForPostRestore(
          startupState.status,
          sessionMessage: startupState.message,
        ),
      );
    }
  }

  Future<void> _resetAppState() async {
    await ref.read(appSessionProvider.notifier).reset();
    ref.invalidate(vaultTransferServiceProvider);
    ref.invalidate(vaultArchiveIoProvider);
    ref.invalidate(vaultRepositoryProvider);
    ref.invalidate(indexDatabaseManagerProvider);
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
    ref.invalidate(recoveryMetadataProvider);
    ref.read(entryIndexRevisionProvider.notifier).bump();
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String? progressMessage,
  }) async {
    setState(() {
      _busy = true;
      _busyMessage = progressMessage;
    });
    try {
      await action();
    } catch (error) {
      final String text = error is StateError ? error.message : '$error';
      if (_shouldOfferGooglePermissionsHelp(text)) {
        _showGoogleDriveHelpSnackBar(text, action);
      } else {
        _showMessage(text);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryGoogleDriveAfterSignOut(Future<void> Function() action) async {
    await ref.read(vaultTransferServiceProvider).resetGoogleDriveSignInForConsentRetry();
    await _runAction(action);
  }

  void _showGoogleDriveHelpSnackBar(String message, Future<void> Function() action) {
    if (!mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 10),
            const Text(
              '如果你剛調整 Google Drive 權限或授權設定，先重新登入再重試通常就能完成授權。',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  unawaited(_retryGoogleDriveAfterSignOut(action));
                },
                child: const Text('重新登入後重試'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldOfferGooglePermissionsHelp(String message) {
    return message.contains('Google 帳號') ||
        message.contains('Google 雲端硬碟') ||
        message.contains('oauth_config.xml') ||
        message.contains('Cloud Console') ||
        message.contains('No credential available') ||
        message.contains('GIDClientID') ||
        message.contains('GIDServerClientID');
  }
}

String _sessionSummary(AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized => message ?? '正在準備中…',
    AppLockStatus.unlocking => message ?? kTrustedUnlockInProgressMessage,
    AppLockStatus.unlocked => message ?? '安全鎖已解除，可以正常使用。',
    AppLockStatus.locked => message ?? kLockedRetryVerificationMessage,
    AppLockStatus.recoveryRequired =>
        message ?? kRecoveryRequiredAfterRestoreMessage,
    AppLockStatus.fatalError => message ?? '初始化失敗，請稍後再試。',
  };
}

IconData _sessionIcon(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => Icons.hourglass_top_rounded,
    AppLockStatus.unlocking => Icons.sync_rounded,
    AppLockStatus.unlocked => Icons.lock_open_rounded,
    AppLockStatus.locked => Icons.lock_outline_rounded,
    AppLockStatus.recoveryRequired => Icons.key_outlined,
    AppLockStatus.fatalError => Icons.error_outline_rounded,
  };
}

SettingsBannerTone _sessionTone(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => SettingsBannerTone.neutral,
    AppLockStatus.unlocking => SettingsBannerTone.neutral,
    AppLockStatus.recoveryRequired => SettingsBannerTone.warning,
    AppLockStatus.fatalError => SettingsBannerTone.error,
    _ => SettingsBannerTone.neutral,
  };
}
