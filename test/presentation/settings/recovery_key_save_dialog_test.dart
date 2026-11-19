import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/widgets/recovery_key_save_dialog.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  const String recoveryKey = '0123-4567-89AB-CDEF-GHJK-MNPQ';

  Future<void> pumpDialog(
    WidgetTester tester, {
    Locale locale = appZhLocale,
    ValueChanged<bool>? onRotationConfirmation,
  }) async {
    await tester.pumpWidget(
      widgetTestApp(
        includeDarkTheme: true,
        locale: locale,
        child: Builder(
          builder: (BuildContext context) {
            return FilledButton(
              onPressed: () async {
                if (onRotationConfirmation == null) {
                  await showRecoveryKeyCreationDialog(
                    context,
                    createRecoveryKey: () async => recoveryKey,
                  );
                  return;
                }
                final confirmed = await showAppDialog<bool>(
                  context: context,
                  builder: (_) => const RecoveryKeySaveDialog.confirmUpdate(
                    recoveryKey: recoveryKey,
                  ),
                );
                onRotationConfirmation(confirmed == true);
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

  testWidgets('新金鑰隨寬度分列，勾選已保存才可輪替', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    bool? confirmed;
    await pumpDialog(
      tester,
      onRotationConfirmation: (value) => confirmed = value,
    );
    final updateButton = find.widgetWithText(
      FilledButton,
      testL10n.settingsRecoveryKeyStartUpdate,
    );
    expect(tester.widget<FilledButton>(updateButton).onPressed, isNull);
    String displayedKey() =>
        tester.widget<SelectableText>(find.byType(SelectableText)).data!;
    final narrowKey = displayedKey();
    tester.view.physicalSize = const Size(800, 640);
    await tester.pumpAndSettle();
    expect(narrowKey.replaceAll('-\n', '-'), recoveryKey);
    expect(
      narrowKey.split('\n').length,
      greaterThan(displayedKey().split('\n').length),
    );

    await tester.tap(find.text(testL10n.settingsRecoveryKeySavedCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(updateButton);
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('勾選後取消仍不開始輪替', (tester) async {
    bool? confirmed;
    await pumpDialog(
      tester,
      onRotationConfirmation: (value) => confirmed = value,
    );
    await tester.tap(find.text(testL10n.settingsRecoveryKeySavedCheckbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
  });

  testWidgets('保存對話框複製完整金鑰並可關閉', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpDialog(tester);
    final displayedKey = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(displayedKey, contains('\n'));
    expect(displayedKey.replaceAll('-\n', '-'), recoveryKey);
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.tap(find.byTooltip(testL10n.commonActionCopy));
    await tester.pumpAndSettle();
    expect(copied, recoveryKey);
    await tester.tap(find.text(testL10n.commonActionClose));
    await tester.pumpAndSettle();
    expect(find.byType(RecoveryKeySaveDialog), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
  testWidgets('英文介面複製失敗顯示翻譯提示並保留金鑰', (tester) async {
    await pumpDialog(tester, locale: appEnLocale);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'unavailable');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.tap(find.byTooltip(testEnL10n.commonActionCopy));
    await tester.pumpAndSettle();
    expect(find.text(testEnL10n.commonClipboardWriteFailed), findsOneWidget);
    expect(find.text(testEnL10n.commonCopiedToClipboard), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
