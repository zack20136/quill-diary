import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/recovery/recovery_metadata.dart';
import '../../domain/security/unlocked_vault_session.dart';
import '../../infrastructure/database/index_database.dart';
import '../../infrastructure/security/app_lock_service.dart';
import '../../infrastructure/storage/vault_repository.dart';
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
    final AsyncValue<List<BackupHistoryRecord>> backupHistoryAsync =
        ref.watch(backupHistoryProvider);
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
                                      ref.read(unlockWithRecoveryKeyUseCaseProvider),
                                    );
                                await refreshEntryIndexCaches(ref);
                                ref.invalidate(backupHistoryProvider);
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
                                final RecoverySetupResult result =
                                    await ref.read(setupRecoveryKeyUseCaseProvider).call();
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
                                    final File file =
                                        await ref.read(createBackupSnapshotUseCaseProvider).call();
                                    ref.invalidate(backupHistoryProvider);
                                    _showMessage('已建立本機備份：${file.path}');
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
                                    final File exportDir = await ref
                                        .read(vaultRepositoryProvider)
                                        .exportMarkdownVault(session);
                                    _showMessage('已匯出 Markdown：${exportDir.path}');
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
                                    final String? remoteId = await ref
                                        .read(vaultRepositoryProvider)
                                        .uploadLatestBackupToDrive();
                                    ref.invalidate(backupHistoryProvider);
                                    _showMessage(
                                      remoteId == null
                                          ? '目前沒有可上傳的本機備份。'
                                          : '已上傳至 Google Drive：$remoteId',
                                    );
                                  }),
                        ),
                        _SettingsActionButton(
                          label: '從 Google Drive 還原',
                          icon: Icons.cloud_download_outlined,
                          onPressed: _busy
                              ? null
                              : () => _runAction(() async {
                                    await ref.read(vaultRepositoryProvider).restoreLatestDriveBackup();
                                    await _resetAppState();
                                    _showMessage('已從 Google Drive 還原最新備份。');
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
                                    final FilePickerResult? picked = await FilePicker.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: const <String>['jbackup'],
                                    );
                                    final String? path = picked?.files.single.path;
                                    if (path == null) {
                                      return;
                                    }
                                    await ref.read(vaultRepositoryProvider).restoreBackup(File(path));
                                    await _resetAppState();
                                    _showMessage('已從本機備份完成還原。');
                                  }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              backupHistoryAsync.when(
                data: (List<BackupHistoryRecord> backups) {
                  return _SettingsSection(
                    title: '備份紀錄',
                    description: '查看最近建立的備份與同步結果。',
                    child: _BackupHistorySection(backups: backups),
                  );
                },
                loading: () => const _SectionLoading(),
                error: (Object error, StackTrace _) => _SettingsSection(
                  title: '備份紀錄',
                  description: '查看最近建立的備份與同步結果。',
                  child: _SettingsInfoBanner(
                    icon: Icons.error_outline_rounded,
                    message: '$error',
                    tone: _BannerTone.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resetAppState() async {
    ref.read(appSessionProvider.notifier).reset();
    ref.invalidate(appStartupProvider);
    ref.invalidate(effectiveAppSessionProvider);
    ref.invalidate(recoveryMetadataProvider);
    ref.invalidate(backupHistoryProvider);
    ref.read(entryIndexRevisionProvider.notifier).bump();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _showMessage('$error');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
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

class _BackupHistorySection extends StatelessWidget {
  const _BackupHistorySection({required this.backups});

  final List<BackupHistoryRecord> backups;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (backups.isEmpty) {
      return const _SettingsInfoBanner(
        icon: Icons.history_toggle_off_rounded,
        message: '目前沒有備份紀錄。',
      );
    }

    return Column(
      children: backups
          .map(
            (BackupHistoryRecord backup) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text('${backup.provider} / ${backup.status}'),
                subtitle: Text(
                  '${backup.createdAt.toLocal()} / ${backup.byteSize ?? 0} bytes',
                ),
                trailing: backup.remoteFileId == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : const Icon(Icons.cloud_done_outlined),
              ),
            ),
          )
          .toList(),
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
        borderRadius: BorderRadius.circular(18),
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
        borderRadius: BorderRadius.circular(18),
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
