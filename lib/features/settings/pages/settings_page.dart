import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/recovery/recovery_metadata.dart';
import '../../../domain/security/unlocked_vault_session.dart';
import '../../../infrastructure/drive/drive_backup_service.dart';
import '../../../infrastructure/security/app_lock_service.dart';
import '../../../shared/providers/core_providers.dart';
import '../../editor/providers/editor_providers.dart';
import '../../home/providers/home_providers.dart';
import '../../session/providers/session_providers.dart';
import '../../session/session_messages.dart';
import '../../session/state/app_session_state.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_sections.dart';

/// 設定頁負責管理 trusted session、Recovery Key、裝置驗證與備份流程。
///
/// 這裡只保留流程協調與互動事件，純展示元件全部下放到 `widgets/`，
/// 避免單一頁面同時承擔過多的樣式與商業流程責任。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _recoveryKeyInputController = TextEditingController();
  bool _busy = false;

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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (!isSupportedPlatform)
              const SettingsSectionCard(
                title: '平台限制',
                description: '目前完整功能僅支援 Android 裝置。',
                child: SettingsInfoBanner(
                  icon: Icons.phone_android_rounded,
                  message: kAndroidOnlyMessage,
                ),
              ),
            if (isSupportedPlatform) ...<Widget>[
              sessionAsync.when(
                data: (AppSessionState sessionState) {
                  return SettingsSectionCard(
                    title: '目前狀態',
                    description: '顯示目前的解鎖狀態。若 trusted session 已失效，可改用 Recovery Key 重新進入保險庫。',
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
                  title: '目前狀態',
                  description: '無法讀取目前的 session 狀態。',
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
                    description: 'Recovery Key 用來在 trusted device 失效時重新解鎖保險庫。建立後請離線保存，這把金鑰只會顯示一次。',
                    child: RecoveryKeySectionBody(
                      metadata: metadata,
                      busy: _busy,
                      onCreateRecoveryKey: metadata != null
                          ? null
                          : () => _runAction(() async {
                                final result = await ref
                                    .read(vaultRepositoryProvider)
                                    .setupRecoveryKey();
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
                                    title: const Text('請妥善保存 Recovery Key'),
                                    content: SelectableText(result.recoveryKey),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('我已抄下'),
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
                title: '裝置驗證',
                description: '預設不啟用生物驗證。只有在你手動開啟後，後續恢復 trusted session 才會要求裝置驗證。',
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
                title: '備份與匯出',
                description: '提供本機備份、Markdown 匯出，以及 Google Drive 的備份與還原。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '本機備份與匯出',
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
                                    _showMessage('已儲存本機備份：$savedPath');
                                  }),
                        ),
                        SettingsActionButton(
                          label: '匯出 Markdown',
                          icon: Icons.file_open_outlined,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
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
                                    _showMessage('已匯出 Markdown：$exportPath');
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
                                    _showMessage('已上傳新的備份到 Google Drive。');
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
                    const SizedBox(height: 18),
                    Text(
                      '從備份還原',
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
                          label: '從本機備份還原',
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
                                    _showMessage('已完成本機備份還原。');
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
      ),
    );
  }

  Future<DriveBackupFile?> _pickDriveBackup(List<DriveBackupFile> backups) async {
    if (backups.isEmpty) {
      _showMessage('Google Drive 目前沒有可還原的備份。');
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

  /// 所有高權限操作都經過統一包裝，確保 busy 狀態與錯誤提示一致。
  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
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
        setState(() => _busy = false);
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
              '如果你剛調整過 Google Drive 權限、OAuth 設定或測試帳號，可以先重新登出 Google 再重試一次，讓應用程式重新請求授權。',
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
    return message.contains('Google 權限') ||
        message.contains('Google 雲端備份') ||
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
    AppLockStatus.uninitialized => message ?? '正在初始化保險庫狀態。',
    AppLockStatus.unlocking => message ?? '正在嘗試還原 trusted session。',
    AppLockStatus.unlocked => message ?? '保險庫已解鎖，敏感資料目前可使用。',
    AppLockStatus.locked => message ?? '目前處於鎖定狀態，需要重新解鎖。',
    AppLockStatus.recoveryRequired => message ?? '目前需要輸入 Recovery Key 才能重新進入保險庫。',
    AppLockStatus.fatalError => message ?? '啟動流程發生未預期錯誤，請檢查設定與資料狀態。',
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
