import 'dart:async' show unawaited;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/presentation/restore/widgets/restore_confirm_dialog.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  final RecoveryMetadata backupMetadata = RecoveryMetadata(
    vaultId: 'vlt_restore_dialog',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );

  Future<void> pumpDialog(
    WidgetTester tester, {
    required RestorePrecheck precheck,
    required bool requiresRecoveryKey,
  }) async {
    await tester.pumpWidget(
      widgetTestApp(
        includeDarkTheme: true,
        child: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () {
                unawaited(
                  showRestoreConfirmDialog(
                    context,
                    precheck,
                    requiresRecoveryKey: requiresRecoveryKey,
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('覆寫型還原需勾選確認後才能按下確認', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      precheck: RestorePrecheck(
        preview: BackupRecoveryPreview(
          metadata: backupMetadata,
          backupId: 'test-backup',
        ),
        localMetadata: backupMetadata,
        localHasTrustedDevice: true,
        willOverwriteLocalVault: true,
      ),
      requiresRecoveryKey: false,
    );

    expect(
      find.text(testL10n.settingsRestoreConfirmOverwriteHeadline),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRestorePrecheckSameVaultTitle),
      findsOneWidget,
    );
    final Finder acknowledgment = find.text(
      testL10n.settingsRestoreConfirmOverwriteAcknowledgeCheckbox,
    );
    final Finder confirmFinder = find.widgetWithText(
      FilledButton,
      testL10n.settingsActionConfirm,
    );
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.ensureVisible(acknowledgment);
    await tester.pumpAndSettle();
    await tester.tap(acknowledgment);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);

    await tester.tap(acknowledgment);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);
  });

  testWidgets('建立日記庫時可直接進入金鑰輸入', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      precheck: RestorePrecheck(
        preview: BackupRecoveryPreview(
          metadata: backupMetadata,
          backupId: 'test-backup',
        ),
        localHasTrustedDevice: false,
        willOverwriteLocalVault: false,
      ),
      requiresRecoveryKey: true,
    );

    expect(
      find.text(testL10n.settingsRestoreConfirmFreshVaultHeadline),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRestoreConfirmOverwriteAcknowledgeCheckbox),
      findsNothing,
    );

    final Finder confirmFinder = find.widgetWithText(
      FilledButton,
      testL10n.settingsRestoreEnterKeyNext,
    );
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
  });

  testWidgets('其他日記庫的舊備份先顯示金鑰提示並提醒完整性限制', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      precheck: RestorePrecheck(
        preview: BackupRecoveryPreview(metadata: backupMetadata),
        localMetadata: RecoveryMetadata(
          vaultId: 'vlt_other',
          recoveryEnabled: true,
          recoveryKeyVersion: 1,
          recoveryKeyHint: 'ABCD',
          createdAt: backupMetadata.createdAt,
          kdf: backupMetadata.kdf,
        ),
        localHasTrustedDevice: true,
        willOverwriteLocalVault: true,
      ),
      requiresRecoveryKey: true,
    );

    final Finder hint = find.text(
      testL10n.settingsRestoreKeyEnding(backupMetadata.recoveryKeyHint),
    );
    final Finder source = find.text(
      testL10n.settingsRestorePrecheckOtherVaultTitle,
    );
    expect(tester.getTopLeft(hint).dy, lessThan(tester.getTopLeft(source).dy));
    expect(
      find.text(testL10n.settingsRestoreLegacyBackupNotice),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              testL10n.settingsRestoreEnterKeyNext,
            ),
          )
          .onPressed,
      isNull,
    );
  });
}
