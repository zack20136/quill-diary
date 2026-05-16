import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../features/editor/providers/editor_providers.dart';
import '../../features/home/providers/home_providers.dart';
import '../../features/session/providers/session_providers.dart';
import '../../features/session/session_messages.dart';
import '../../features/settings/providers/settings_providers.dart';
import '../../infrastructure/drive/drive_backup_service.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../shared/providers/core_providers.dart';
import '../page_style.dart';
import '../state/app_session_state.dart';

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
      appBar: AppBar(title: const Text('設定與備份')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (!isSupportedPlatform)
              const _SettingsSection(
                title: '平台支援',
                description: '目前僅支援 Android 裝置。',
                child: _SettingsInfoBanner(
                  icon: Icons.phone_android_rounded,
                  message: kAndroidOnlyMessage,
                ),
              ),
            if (isSupportedPlatform) ...<Widget>[
              sessionAsync.when(
                data: (AppSessionState sessionState) {
                  return _SettingsSection(
                    title: '安全狀態',
                    description: '查看目前的解鎖狀態，必要時使用 Recovery Key 重新進入日記庫。',
                    child: _SettingsStatusPanel(
                      sessionState: sessionState,
                      busy: _busy,
                      recoveryKeyInputController: _recoveryKeyInputController,
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
                loading: () => const _SectionLoading(),
                error: (Object error, StackTrace _) => _SettingsSection(
                  title: '安全狀態',
                  description: '查看目前的解鎖狀態。',
                  child: _SettingsInfoBanner(
                    icon: Icons.error_outline_rounded,
                    message: '$error',
                    tone: _BannerTone.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              recoveryMetadataAsync.when(
                data: (RecoveryMetadata? metadata) {
                  return _SettingsSection(
                    title: 'Recovery Key',
                    description: 'Recovery Key 用來重新解鎖日記庫，也會在建立時把目前裝置註冊為受信任裝置。',
                    child: _RecoveryKeySectionBody(
                      metadata: metadata,
                      busy: _busy,
                      onCreateRecoveryKey: metadata != null
                          ? null
                          : () => _runAction(() async {
                                final result = await ref
                                    .read(setupRecoveryKeyUseCaseProvider)
                                    .call();
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
                                        child: const Text('我已保存'),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                    ),
                  );
                },
                loading: () => const _SectionLoading(),
                error: (Object error, StackTrace _) => _SettingsSection(
                  title: 'Recovery Key',
                  description: '管理解鎖日記庫所需的 Recovery Key。',
                  child: _SettingsInfoBanner(
                    icon: Icons.error_outline_rounded,
                    message: '$error',
                    tone: _BannerTone.error,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: '裝置驗證',
                description: '控制是否在回到 app 時要求裝置驗證，保護目前的解鎖 session。',
                child: FutureBuilder<bool>(
                  future: appLockService.isBiometricLockEnabled(),
                  builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                    return _SettingsToggleTile(
                      title: '啟用裝置驗證',
                      description: '開啟後，返回 app 時會要求裝置驗證後才能繼續使用。',
                      value: snapshot.data ?? false,
                      onChanged: _busy
                          ? null
                          : (bool value) => _runAction(() async {
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
              _SettingsSection(
                title: '備份與還原',
                description: '將目前資料匯出、建立備份，或從本機與 Google Drive 還原。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '匯出與本機備份',
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
                        _SettingsActionButton(
                          label: '建立本機備份',
                          icon: Icons.archive_outlined,
                          emphasized: true,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final String? savedPath = await ref
                                        .read(vaultTransferServiceProvider)
                                        .createBackupWithPicker();
                                    if (savedPath == null) {
                                      return;
                                    }
                                    _showMessage('已儲存本機備份：$savedPath');
                                  }),
                        ),
                        _SettingsActionButton(
                          label: '匯出 Markdown',
                          icon: Icons.file_open_outlined,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final UnlockedVaultSession? session =
                                        await ref.read(activeVaultSessionProvider.future);
                                    if (session == null) {
                                      throw StateError('請先完成解鎖，才能匯出 Markdown。');
                                    }
                                    final String? exportPath = await ref
                                        .read(vaultTransferServiceProvider)
                                        .exportMarkdownWithPicker(session);
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
                      '雲端備份',
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
                        _SettingsActionButton(
                          label: '上傳到 Google Drive',
                          icon: Icons.cloud_upload_outlined,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    await ref
                                        .read(vaultTransferServiceProvider)
                                        .uploadBackupToDrive();
                                    _showMessage('已上傳新的備份至 Google Drive。');
                                  }),
                        ),
                        _SettingsActionButton(
                          label: '從 Google Drive 還原',
                          icon: Icons.cloud_download_outlined,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final List<DriveBackupFile> backups = await ref
                                        .read(vaultTransferServiceProvider)
                                        .listDriveBackups();
                                    final DriveBackupFile? backup =
                                        await _pickDriveBackup(backups);
                                    if (backup == null) {
                                      return;
                                    }
                                    await ref
                                        .read(vaultTransferServiceProvider)
                                        .restoreDriveBackup(backup);
                                    await _resetAppState();
                                    _showMessage('已從 Google Drive 還原：${backup.name}');
                                  }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '還原操作',
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
                        _SettingsActionButton(
                          label: '從本機備份還原',
                          icon: Icons.restore_rounded,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    final bool restored = await ref
                                        .read(vaultTransferServiceProvider)
                                        .restoreBackupFromPicker();
                                    if (!restored) {
                                      return;
                                    }
                                    await _resetAppState();
                                    _showMessage('已從本機備份完成還原。');
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
      _showMessage('Google Drive 沒有可還原的備份。');
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
    ref.read(appSessionProvider.notifier).reset();
    ref.invalidate(vaultTransferServiceProvider);
    ref.invalidate(vaultArchiveIoProvider);
    ref.invalidate(vaultRepositoryProvider);
    ref.invalidate(indexDatabaseProvider);
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
    ref.invalidate(recoveryMetadataProvider);
    ref.read(entryIndexRevisionProvider.notifier).bump();
  }

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
              '若剛才拒絕或關閉過同意畫面，請先重置這次 Google 連線，再重新開啟登入與 Drive 授權。',
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
                child: const Text('前往同意權限'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldOfferGooglePermissionsHelp(String message) {
    return message.contains('Google 登入') ||
        message.contains('Google 雲端備份') ||
        message.contains('oauth_config.xml') ||
        message.contains('Cloud Console') ||
        message.contains('No credential available') ||
        message.contains('GIDClientID') ||
        message.contains('GIDServerClientID');
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(PageStyle.radiusCard),
        border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsStatusPanel extends StatelessWidget {
  const _SettingsStatusPanel({
    required this.sessionState,
    required this.busy,
    required this.recoveryKeyInputController,
    required this.onUnlockWithRecovery,
  });

  final AppSessionState sessionState;
  final bool busy;
  final TextEditingController recoveryKeyInputController;
  final VoidCallback? onUnlockWithRecovery;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SettingsInfoBanner(
          icon: _sessionIcon(sessionState.status),
          message: _sessionSummary(sessionState),
          tone: _sessionTone(sessionState.status),
        ),
        if (sessionState.status == AppLockStatus.recoveryRequired) ...<Widget>[
          const SizedBox(height: 16),
          TextField(
            controller: recoveryKeyInputController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: '輸入 Recovery Key',
              hintText: 'ABCD-EFGH-IJKL-MNOP-QRST-UVWX',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '請輸入完整的 Recovery Key 來重新註冊目前裝置並解鎖日記庫。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _SettingsActionButton(
            label: '使用 Recovery Key 解鎖',
            icon: Icons.lock_open_rounded,
            emphasized: true,
            onPressed: busy ? null : onUnlockWithRecovery,
          ),
        ],
      ],
    );
  }
}

class _RecoveryKeySectionBody extends StatelessWidget {
  const _RecoveryKeySectionBody({
    required this.metadata,
    required this.busy,
    required this.onCreateRecoveryKey,
  });

  final RecoveryMetadata? metadata;
  final bool busy;
  final VoidCallback? onCreateRecoveryKey;

  @override
  Widget build(BuildContext context) {
    final RecoveryMetadata? currentMetadata = metadata;
    if (currentMetadata == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SettingsInfoBanner(
            icon: Icons.key_off_outlined,
            message: '尚未建立 Recovery Key。建立後才能解鎖日記庫並啟用受信任裝置。',
            tone: _BannerTone.warning,
          ),
          const SizedBox(height: 14),
          _SettingsActionButton(
            label: '建立 Recovery Key',
            icon: Icons.key_outlined,
            emphasized: true,
            onPressed: busy ? null : onCreateRecoveryKey,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SettingsInfoBanner(
          icon: Icons.verified_user_outlined,
          message: 'Recovery Key 已建立，目前裝置可配合受信任裝置機制快速解鎖。',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _SettingsFactChip(label: 'Vault', value: currentMetadata.vaultId),
            _SettingsFactChip(label: '提示碼', value: currentMetadata.recoveryKeyHint),
            _SettingsFactChip(label: 'KDF', value: currentMetadata.kdf.name),
          ],
        ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (emphasized) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(description),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
  }
}

class _SettingsInfoBanner extends StatelessWidget {
  const _SettingsInfoBanner({
    required this.icon,
    required this.message,
    this.tone = _BannerTone.neutral,
  });

  final IconData icon;
  final String message;
  final _BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background = switch (tone) {
      _BannerTone.neutral => theme.colorScheme.surfaceContainerLow,
      _BannerTone.warning => theme.colorScheme.secondaryContainer,
      _BannerTone.error => theme.colorScheme.errorContainer,
    };
    final Color foreground = switch (tone) {
      _BannerTone.neutral => theme.colorScheme.onSurface,
      _BannerTone.warning => theme.colorScheme.onSecondaryContainer,
      _BannerTone.error => theme.colorScheme.onErrorContainer,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsFactChip extends StatelessWidget {
  const _SettingsFactChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label：$value',
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

enum _BannerTone {
  neutral,
  warning,
  error,
}

String _sessionSummary(AppSessionState sessionState) {
  final String? message = sessionState.message;
  return switch (sessionState.status) {
    AppLockStatus.uninitialized => message ?? '正在準備日記庫狀態。',
    AppLockStatus.unlocking => message ?? '正在解鎖日記庫，請稍候。',
    AppLockStatus.unlocked => message ?? '日記庫已解鎖，可以讀取與編輯內容。',
    AppLockStatus.locked => message ?? '目前已鎖定，返回首頁後需要先完成裝置驗證。',
    AppLockStatus.recoveryRequired => message ?? '目前需要 Recovery Key 才能重新解鎖日記庫。',
    AppLockStatus.fatalError => message ?? '發生錯誤，暫時無法讀取日記庫。',
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

_BannerTone _sessionTone(AppLockStatus status) {
  return switch (status) {
    AppLockStatus.uninitialized => _BannerTone.neutral,
    AppLockStatus.unlocking => _BannerTone.neutral,
    AppLockStatus.recoveryRequired => _BannerTone.warning,
    AppLockStatus.fatalError => _BannerTone.error,
    _ => _BannerTone.neutral,
  };
}
