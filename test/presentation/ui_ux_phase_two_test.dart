import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/application/editor/editor_actions.dart';
import 'package:quill_diary/application/editor/editor_body_blocks.dart';
import 'package:quill_diary/application/session/providers/session_providers.dart';
import 'package:quill_diary/application/session/state/app_session_state.dart';
import 'package:quill_diary/application/settings/settings_providers.dart';
import 'package:quill_diary/domain/security/unlocked_vault_session.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/editor/pages/editor_page.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_checkbox_block_row.dart';
import 'package:quill_diary/presentation/home/widgets/entry_widgets.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/widgets/accent_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_state_card.dart';

import '../helpers/app_test_theme.dart';
import '../helpers/presentation/editor/editor_test_scope.dart';
import '../helpers/presentation/editor/fake_editor_actions.dart';
import '../helpers/shared/entry_index_fixtures.dart';
import '../helpers/shared/test_l10n.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: appTestTheme(),
      locale: appZhLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('SettingsFactChip 使用正確繁中分隔', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(const SettingsFactChip(label: '提示', value: 'ABCD')),
    );

    expect(find.text('提示：ABCD'), findsOneWidget);
    expect(find.textContaining('嚗'), findsNothing);
  });

  testWidgets('編輯器缺少復原金鑰時顯示前往設定 CTA', (WidgetTester tester) async {
    const UnlockedVaultSession session = UnlockedVaultSession(
      vaultId: 'vault-1',
      trustedDevice: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          editorActionsProvider.overrideWithValue(FakeEditorActions()),
          effectiveAppSessionProvider.overrideWith(
            (Ref ref) async => const AppSessionState(
              status: AppLockStatus.unlocked,
              session: session,
            ),
          ),
          recoveryMetadataProvider.overrideWith((Ref ref) async => null),
        ],
        child: editorTestApp(child: const EditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppStateView), findsOneWidget);
    expect(
      find.text(testL10n.sessionBlockedRecoveryRequiredTitle),
      findsOneWidget,
    );
    expect(find.text(testL10n.editorNeedsRecoveryKeyMessage), findsOneWidget);
    expect(find.text(testL10n.homeGoToSettings), findsOneWidget);
  });

  testWidgets('AppFeedbackBanner 具有 liveRegion 語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(const AppFeedbackBanner(message: '已儲存')),
    );

    final SemanticsNode node = tester.getSemantics(
      find.byType(AppFeedbackBanner),
    );
    expect(node.flagsCollection.isLiveRegion, isTrue);
  });

  testWidgets('AppFeedbackToast 具有 liveRegion 語意', (WidgetTester tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTestTheme(),
        home: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    showAppFeedbackToast(hostContext, '備份成功', tone: AppFeedbackTone.success);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics && widget.properties.liveRegion == true,
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 250));
  });

  testWidgets('日記卡片提供 button 與 selected 語意', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        HomeEntryCard(
          entry: buildEntryIndexRecord(),
          typography: EditorTypographyPreferences.defaults,
          selectionActive: true,
          selected: true,
          tagAccents: const <String, int>{},
          showUnsavedDraft: false,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );

    final SemanticsNode node = tester.getSemantics(find.byType(HomeEntryCard));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('核取方塊視覺 24px 並與第一行文字頂對齊', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        EditorCheckboxBlockRow(
          block: const EditorCheckboxLine(
            id: 'c1',
            text: '第一行\n第二行\n第三行',
            checked: false,
          ),
          typography: EditorTypographyPreferences.defaults,
          bodyStyle: const TextStyle(fontSize: 16, height: 1.4),
          editable: true,
          textController: TextEditingController(text: '第一行\n第二行\n第三行'),
          onCheckedChanged: (_) {},
          onTextChanged: (_) {},
        ),
      ),
    );

    final Size checkboxSize = tester.getSize(find.byType(Checkbox));
    expect(checkboxSize.width, lessThanOrEqualTo(24));
    expect(checkboxSize.height, lessThanOrEqualTo(24));

    final double checkboxTop = tester.getTopLeft(find.byType(Checkbox)).dy;
    final double textTop = tester.getTopLeft(find.byType(TextField)).dy;
    // 允許 top: 2 的光學微調，但不應落到多行文字中央。
    expect((checkboxTop - textTop).abs(), lessThan(8));
  });

  testWidgets('AccentDialogShell 關閉按鈕觸控目標至少 44', (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        AccentDialogShell(
          icon: Icons.palette_outlined,
          title: '標題',
          onClose: () {},
          child: const SizedBox(height: 40),
        ),
      ),
    );

    final Size size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
