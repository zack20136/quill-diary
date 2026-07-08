import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/recovery/kdf_descriptor.dart';
import 'package:quill_diary/domain/recovery/recovery_metadata.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_action_dialogs.dart';
import 'package:quill_diary/infrastructure/storage/restore_precheck.dart';
import 'package:quill_diary/l10n/l10n.dart';

import '../../helpers/app_test_theme.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  final RecoveryMetadata backupMetadata = RecoveryMetadata(
    vaultId: 'vlt_restore_dialog',
    recoveryEnabled: true,
    recoveryKeyVersion: 1,
    recoveryKeyHint: 'WXYZ',
    createdAt: DateTime.parse('2026-05-19T00:00:00Z'),
    kdf: KdfDescriptor.argon2idRecovery(saltBytes: List<int>.filled(16, 1)),
  );

  RestorePrecheck buildPrecheck({required bool willOverwriteLocalVault}) {
    return RestorePrecheck(
      preview: BackupRecoveryPreview(metadata: backupMetadata),
      localVaultId: 'vlt_restore_dialog',
      localRecoverySaltBase64: backupMetadata.kdf.saltBase64,
      localHasTrustedDevice: true,
      willOverwriteLocalVault: willOverwriteLocalVault,
    );
  }

  Future<void> pumpDialog(
    WidgetTester tester, {
    required RestorePrecheck precheck,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        darkTheme: appTestTheme(brightness: Brightness.dark),
        locale: appZhLocale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    unawaited(showRestoreConfirmDialog(context, precheck));
                  },
                  child: const Text('open'),
                ),
              ),
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
      precheck: buildPrecheck(willOverwriteLocalVault: true),
    );

    expect(
      find.text(testL10n.settingsRestoreConfirmOverwriteHeadline),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRestorePrecheckSameVaultTitle),
      findsOneWidget,
    );
    expect(
      find.text(testL10n.settingsRestoreConfirmOverwriteAcknowledgeCheckbox),
      findsOneWidget,
    );

    final Finder confirmFinder = find.widgetWithText(
      FilledButton,
      testL10n.settingsActionConfirm,
    );
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
  });

  testWidgets('非覆寫型還原顯示較溫和提示且不需二次確認', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      precheck: buildPrecheck(willOverwriteLocalVault: false),
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
      testL10n.settingsActionConfirm,
    );
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
  });

  testWidgets('還原確認對話框不顯示備份未含復原金鑰文案', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      precheck: buildPrecheck(willOverwriteLocalVault: false),
    );

    expect(find.text('備份未含復原金鑰'), findsNothing);
    expect(find.textContaining('尚未建立復原金鑰'), findsNothing);
  });
}
