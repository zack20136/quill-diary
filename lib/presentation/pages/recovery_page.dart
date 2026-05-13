import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../app/providers.dart';
import '../../infrastructure/database/index_database.dart';
import '../../infrastructure/security/app_lock_service.dart';

class RecoveryPage extends ConsumerStatefulWidget {
  const RecoveryPage({super.key});

  @override
  ConsumerState<RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends ConsumerState<RecoveryPage> {
  final PageController _pageController = PageController();
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue metadataAsync = ref.watch(recoveryMetadataProvider);
    final AsyncValue<List<BackupHistoryRecord>> backupsAsync =
        ref.watch(backupHistoryProvider);
    final AppLockService appLockService = ref.watch(appLockServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recovery 與備份')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: PageView(
              controller: _pageController,
              children: const [
                _GuideCard(
                  title: '本地優先',
                  body: '資料預設保存在本機加密 vault，不把明文內容送到雲端。',
                ),
                _GuideCard(
                  title: 'Recovery Key',
                  body: '每個加密檔案都保留 recovery slot，讓你在裝置遺失時仍能救援。',
                ),
                _GuideCard(
                  title: '快照備份',
                  body: '`.jbackup` 是快照，不是同步資料夾；Google Drive 只存加密封包。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 3,
              effect: const WormEffect(dotHeight: 8, dotWidth: 8),
            ),
          ),
          const SizedBox(height: 24),
          metadataAsync.when(
            data: (metadata) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata == null ? '尚未建立 Recovery Key' : 'Recovery Key 已建立',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (metadata == null)
                      const Text('建立後會產生 wrapping key、device secret 與 recovery.json。')
                    else ...[
                      Text('Vault: ${metadata.vaultId}'),
                      Text('Hint: ${metadata.recoveryKeyHint}'),
                      Text('KDF: ${metadata.kdfAlgorithm}'),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || metadata != null
                          ? null
                          : () => _runAction(() async {
                                final String key =
                                    await ref.read(setupRecoveryKeyUseCaseProvider).call();
                                ref.invalidate(recoveryMetadataProvider);
                                if (context.mounted) {
                                  await showDialog<void>(
                                    context: context,
                                    builder: (BuildContext context) => AlertDialog(
                                      title: const Text('請妥善保存 Recovery Key'),
                                      content: SelectableText(key),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text('我已記下'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }),
                      icon: const Icon(Icons.key_outlined),
                      label: const Text('建立 Recovery Key'),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Text('讀取 Recovery 狀態失敗：$error'),
          ),
          const SizedBox(height: 16),
          FutureBuilder<bool>(
            future: appLockService.isBiometricLockEnabled(),
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              final bool enabled = snapshot.data ?? false;
              return SwitchListTile.adaptive(
                value: enabled,
                title: const Text('啟用裝置解鎖'),
                subtitle: const Text('使用 biometrics / device credentials 來保護 session。'),
                onChanged: (bool value) => _runAction(() async {
                  await appLockService.setBiometricLockEnabled(value);
                  setState(() {});
                }),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(() async {
                          final File file =
                              await ref.read(createBackupSnapshotUseCaseProvider).call();
                          ref.invalidate(backupHistoryProvider);
                          _showMessage('已建立本地備份：${file.path}');
                        }),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('建立 .jbackup'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(() async {
                          final File exportDir =
                              await ref.read(vaultRepositoryProvider).exportMarkdownVault();
                          _showMessage('已匯出 Markdown：${exportDir.path}');
                        }),
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('匯出 Markdown'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(() async {
                          final String? remoteId = await ref
                              .read(vaultRepositoryProvider)
                              .uploadLatestBackupToDrive();
                          ref.invalidate(backupHistoryProvider);
                          _showMessage(
                            remoteId == null ? 'Google Drive 上傳失敗。' : '已上傳到 Drive：$remoteId',
                          );
                        }),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('上傳到 Drive'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(() async {
                          await ref.read(vaultRepositoryProvider).restoreLatestDriveBackup();
                          ref.invalidate(timelineEntriesProvider);
                          ref.invalidate(monthEntryDatesProvider);
                          _showMessage('已從 Google Drive 還原最新備份。');
                        }),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('從 Drive 還原'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _runAction(() async {
                          final FilePickerResult? picked =
                              await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: const ['jbackup'],
                          );
                          final String? path = picked?.files.single.path;
                          if (path == null) {
                            return;
                          }
                          await ref.read(vaultRepositoryProvider).restoreBackup(File(path));
                          ref.invalidate(timelineEntriesProvider);
                          ref.invalidate(monthEntryDatesProvider);
                          _showMessage('本地備份已還原。');
                        }),
                icon: const Icon(Icons.restore),
                label: const Text('還原本地備份'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('備份歷史', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          backupsAsync.when(
            data: (List<BackupHistoryRecord> backups) {
              if (backups.isEmpty) {
                return const Text('目前還沒有備份紀錄。');
              }
              return Column(
                children: backups
                    .map(
                      (BackupHistoryRecord backup) => Card(
                        child: ListTile(
                          title: Text('${backup.provider} / ${backup.status}'),
                          subtitle: Text(
                            '${backup.createdAt.toLocal()} • ${backup.byteSize ?? 0} bytes',
                          ),
                          trailing: backup.remoteFileId == null
                              ? null
                              : const Icon(Icons.cloud_done_outlined),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Text('讀取備份歷史失敗：$error'),
          ),
        ],
      ),
    );
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

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(body, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
