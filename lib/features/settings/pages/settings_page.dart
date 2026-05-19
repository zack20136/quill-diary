import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_lock_service.dart';
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
    final ThemeData theme = Theme.of(context);

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
                    description: '目前這個版本僅支援 Android 裝置上的加密保險庫功能。',
                    child: SettingsInfoBanner(
                      icon: Icons.phone_android_rounded,
                      message: kAndroidOnlyMessage,
                    ),
                  ),
                if (isSupportedPlatform) ...<Widget>[
                  sessionAsync.when(
                    data: (AppSessionState sessionState) {
                      return SettingsSectionCard(
                        title: '保險庫狀態',
                        description: '查看 trusted session 狀態，必要時使用 Recovery Key 重新解鎖。',
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
                        ),
                      );
                    },
                    loading: () => const SettingsSectionLoading(),
                    error: (Object error, StackTrace _) => SettingsSectionCard(
                      title: '保險庫狀態',
                      description: '讀取目前 session 狀態時發生錯誤。',
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
                        title: 'Recovery Key',
                        description: 'Recovery Key 用來在 trusted device 失效時重新建立 trusted session，請妥善保存。',
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
                                        title: const Text('請保存 Recovery Key'),
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
                      title: 'Recovery Key',
                      description: '讀取 Recovery Key 設定時發生錯誤。',
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
                    description: '開啟後，之後恢復 trusted session 時會要求裝置驗證。',
                    child: FutureBuilder<bool>(
                      future: appLockService.isBiometricLockEnabled(),
                      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                        return SettingsToggleTile(
                          title: '啟用生物驗證',
                          description: '開啟後，已儲存的 trusted session 需要通過生物驗證才能還原。',
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
                    title: '匯入、匯出與備份',
                    description: 'Markdown 匯出會整理成單篇資料夾結構後再封裝成 zip；匯入支援 zip 或含附件的 Markdown / HTML 資料夾。',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                    Text(
                      '匯入與匯出',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        SettingsActionButton(
                          label: '匯出 Markdown',
                          icon: Icons.file_open_outlined,
                          emphasized: true,
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
                                    _showMessage('已匯出 Markdown zip：$exportPath');
                                  },
                                    progressMessage: '正在匯出 Markdown，整理日記與附件中…',
                                  ),
                        ),
                        SettingsActionButton(
                          label: '匯入 Markdown / HTML / zip',
                          icon: Icons.download_rounded,
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
                    const SizedBox(height: 18),
                    Text(
                      '本機備份與還原',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        SettingsActionButton(
                          label: '建立本機備份',
                          icon: Icons.archive_outlined,
                          emphasized: true,
                          onPressed: _busy
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
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final bool restored = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .restoreBackupFromPicker();
                                    });
                                    if (!restored) {
                                      return;
                                    }
                                    await _resetAppState();
                                    _showMessage('已從本機備份還原。');
                                  }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Google Drive 備份',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        SettingsActionButton(
                          label: '上傳到 Google Drive',
                          icon: Icons.cloud_upload_outlined,
                          onPressed: _busy
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
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final List<DriveBackupFile> backups = await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .listDriveBackups();
                                    });
                                    final DriveBackupFile? backup = await _pickDriveBackup(backups);
                                    if (backup == null) {
                                      return;
                                    }
                                    await ref
                                        .read(appSessionProvider.notifier)
                                        .runSensitiveTask((_) {
                                      return ref
                                          .read(vaultTransferServiceProvider)
                                          .restoreDriveBackup(backup);
                                    });
                                    await _resetAppState();
                                    _showMessage('已從 Google Drive 還原：${backup.name}');
                                  }),
                        ),
                      ],
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
              '如果你剛調整 Google Drive 權限或 OAuth 設定，先重新登入再重試通常就能完成授權。',
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
    AppLockStatus.uninitialized => message ?? '正在準備保險庫狀態。',
    AppLockStatus.unlocking => message ?? '正在嘗試還原 trusted session。',
    AppLockStatus.unlocked => message ?? '已解鎖，trusted session 可用。',
    AppLockStatus.locked => message ?? '目前已鎖定，需要重新驗證。',
    AppLockStatus.recoveryRequired => message ?? 'trusted device 不可用，請使用 Recovery Key 解鎖。',
    AppLockStatus.fatalError => message ?? '初始化失敗，請檢查設定後再試一次。',
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
