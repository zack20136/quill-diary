import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/features/restore/restore_backup_flow.dart';
import 'package:quill_diary/features/restore/restore_prepared_context.dart';
import 'package:quill_diary/features/session/providers/session_providers.dart';
import 'package:quill_diary/features/session/state/app_session_state.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/providers/core_providers.dart';

import '../../helpers/fake_app_lock_service.dart';
import '../../helpers/fake_session_vault_repository.dart';
import '../../helpers/recording_vault_transfer_service.dart';
import '../../helpers/test_l10n.dart';

void main() {
  final RecoveryMetadata backupMetadata = RecoveryMetadata(
    vaultId: 'vlt_backup',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );

  final UnlockedVaultSession sampleSession = UnlockedVaultSession(
    vaultId: backupMetadata.vaultId,
    trustedDevice: true,
    recoveryWrapKey: List<int>.filled(32, 9),
  );

  late File backupFile;
  late RecordingVaultTransferService transferService;
  late FakeSessionVaultRepository repository;

  setUp(() async {
    final Directory tempDir = await Directory.systemTemp.createTemp(
      'restore_flow_test_',
    );
    backupFile = File('${tempDir.path}/backup.zip')
      ..writeAsStringSync('backup');
    transferService = RecordingVaultTransferService();
    repository = FakeSessionVaultRepository();
  });

  RestorePrecheck trustedPrecheck() {
    return RestorePrecheck(
      preview: BackupRecoveryPreview(
        hasRecovery: true,
        metadata: backupMetadata,
      ),
      localVaultId: backupMetadata.vaultId,
      localRecoverySaltBase64: backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );
  }

  RestorePrecheck recoveryKeyPrecheck() {
    return RestorePrecheck(
      preview: BackupRecoveryPreview(
        hasRecovery: true,
        metadata: backupMetadata,
      ),
      localVaultId: 'vlt_other',
      localRecoverySaltBase64: backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: true,
    );
  }

  Future<void> pumpFlowHost(
    WidgetTester tester, {
    required Future<bool> Function(
      RestorePrecheck precheck, {
      String? driveBackupName,
    })
    confirm,
    required Future<void> Function({
      String? backupRecoveryKey,
      required RestorePrecheck precheck,
    })
    onComplete,
    bool activateSession = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportedPlatformProvider.overrideWithValue(true),
          vaultTransferServiceProvider.overrideWithValue(transferService),
          vaultRepositoryProvider.overrideWithValue(repository),
          appLockServiceProvider.overrideWithValue(FakeAppLockService()),
        ],
        child: MaterialApp(
          locale: appZhTwLocale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: _RestoreFlowHost(
            backupFile: backupFile,
            confirm: confirm,
            onComplete: onComplete,
          ),
        ),
      ),
    );
    if (activateSession) {
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(_RestoreFlowHost)),
      );
      container
          .read(appSessionProvider.notifier)
          .activateSession(sampleSession);
    }
    await tester.pump();
  }

  testWidgets('confirm 取消時不執行還原', (WidgetTester tester) async {
    transferService.nextPrecheck = trustedPrecheck();
    bool completed = false;

    await pumpFlowHost(
      tester,
      confirm: (_, {String? driveBackupName}) async => false,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completed = true;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(transferService.precheckCalls, 1);
    expect(transferService.restoreCalls, 0);
    expect(completed, isFalse);
  });

  testWidgets('trusted 還原跳過金鑰收集並保留 trusted', (WidgetTester tester) async {
    transferService.nextPrecheck = trustedPrecheck();
    RestorePrecheck? completedPrecheck;

    await pumpFlowHost(
      tester,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completedPrecheck = precheck;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(transferService.verifyCalls, 0);
    expect(transferService.restoreCalls, 1);
    expect(transferService.lastPreserveTrusted, isTrue);
    expect(completedPrecheck?.expectsTrustedUnlockAfterRestore, isTrue);
  });

  testWidgets('prepare 時取得的舊 session 若在還原前失效，不會被拿來 resume', (
    WidgetTester tester,
  ) async {
    transferService.nextPrecheck = trustedPrecheck();
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportedPlatformProvider.overrideWithValue(true),
          vaultTransferServiceProvider.overrideWithValue(transferService),
          vaultRepositoryProvider.overrideWithValue(repository),
          appLockServiceProvider.overrideWithValue(FakeAppLockService()),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            capturedRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    container.read(appSessionProvider.notifier).activateSession(sampleSession);

    final RestorePreparedContext prepared = RestorePreparedContext(
      precheck: trustedPrecheck(),
    );
    await container.read(appSessionProvider.notifier).expireFromInactivity();

    final RestoreBackupFlow flow = RestoreBackupFlow(capturedRef);
    final AppSessionState state = await flow.executeRestoreAndFinishSession(
      backupFile: backupFile,
      prepared: prepared,
    );

    expect(transferService.restoreCalls, 1);
    expect(repository.resumeUnlockedSessionAfterRestoreCalls, 0);
    expect(state.status, AppLockStatus.recoveryRequired);
    expect(state.session, isNull);
  });

  testWidgets('需要金鑰時取消對話框不還原', (WidgetTester tester) async {
    transferService.nextPrecheck = recoveryKeyPrecheck();
    bool completed = false;

    await pumpFlowHost(
      tester,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completed = true;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text(testL10n.commonActionCancel), findsOneWidget);

    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();

    expect(transferService.restoreCalls, 0);
    expect(completed, isFalse);
  });

  testWidgets('金鑰驗證失敗後重試成功才還原', (WidgetTester tester) async {
    transferService.nextPrecheck = recoveryKeyPrecheck();
    transferService.verifyError = StateError('復原金鑰錯誤');
    String? completedKey;

    await pumpFlowHost(
      tester,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completedKey = backupRecoveryKey;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'BAD-KEY');
    await tester.tap(find.text(testL10n.settingsActionVerifyAndRestore));
    await tester.pumpAndSettle();

    expect(transferService.verifyCalls, 1);
    expect(transferService.restoreCalls, 0);

    transferService.verifyError = null;
    await tester.enterText(find.byType(TextField), 'GOOD-KEY');
    await tester.tap(find.text(testL10n.settingsActionVerifyAndRestore));
    await tester.pumpAndSettle();

    expect(transferService.verifyCalls, 2);
    expect(transferService.restoreCalls, 1);
    expect(transferService.lastPreserveTrusted, isFalse);
    expect(completedKey, 'GOOD-KEY');
  });

  testWidgets('無解鎖 session 且無本機復原金鑰時仍可還原', (WidgetTester tester) async {
    transferService.nextPrecheck = trustedPrecheck();
    bool completed = false;

    await pumpFlowHost(
      tester,
      activateSession: false,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completed = true;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(transferService.restoreCalls, 1);
    expect(completed, isTrue);
  });

  testWidgets('locked 且已有本機復原金鑰時拒絕還原', (WidgetTester tester) async {
    repository = FakeSessionVaultRepository(metadata: backupMetadata);
    transferService.nextPrecheck = trustedPrecheck();
    bool completed = false;

    await pumpFlowHost(
      tester,
      activateSession: false,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completed = true;
          },
    );

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(_RestoreFlowHost)),
    );
    await container.read(appSessionProvider.notifier).lock();
    await tester.pump();

    Object? caughtError;
    await runZonedGuarded(
      () async {
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
      },
      (Object error, StackTrace stackTrace) {
        caughtError = error;
      },
    );

    expect(caughtError, isA<StateError>());
    expect(transferService.restoreCalls, 0);
    expect(completed, isFalse);
  });

  testWidgets('啟動狀態為 recoveryRequired 時仍可直接還原', (WidgetTester tester) async {
    repository = FakeSessionVaultRepository(
      metadata: backupMetadata,
      hasTrustedDevice: false,
    );
    transferService.nextPrecheck = trustedPrecheck();
    bool completed = false;

    await pumpFlowHost(
      tester,
      activateSession: false,
      confirm: (_, {String? driveBackupName}) async => true,
      onComplete:
          ({
            String? backupRecoveryKey,
            required RestorePrecheck precheck,
          }) async {
            completed = true;
          },
    );

    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(transferService.restoreCalls, 1);
    expect(completed, isTrue);
  });
}

class _RestoreFlowHost extends ConsumerWidget {
  const _RestoreFlowHost({
    required this.backupFile,
    required this.confirm,
    required this.onComplete,
  });

  final File backupFile;
  final Future<bool> Function(
    RestorePrecheck precheck, {
    String? driveBackupName,
  })
  confirm;
  final Future<void> Function({
    String? backupRecoveryKey,
    required RestorePrecheck precheck,
  })
  onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () async {
          final RestorePrecheck precheck = await ref
              .read(vaultTransferServiceProvider)
              .precheckRestore(backupFile);
          if (!context.mounted) {
            return;
          }
          final RestoreBackupFlow flow = RestoreBackupFlow(ref);
          final RestorePreparedContext? prepared = await flow.prepare(
            context: context,
            backupFile: backupFile,
            precheck: precheck,
            confirm: confirm,
          );
          if (!context.mounted || prepared == null) {
            return;
          }
          await flow.executeRestore(backupFile: backupFile, prepared: prepared);
          await onComplete(
            backupRecoveryKey: prepared.backupRecoveryKey,
            precheck: prepared.precheck,
          );
        },
        child: const Text('run'),
      ),
    );
  }
}
