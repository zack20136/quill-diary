import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/diary_organization/organization_quick_actions.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('四個整理方向點擊後送出各自完整需求', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      widgetTestApp(
        child: Scaffold(
          body: OrganizationQuickActions(
            enabled: true,
            onSelected: selected.add,
          ),
        ),
      ),
    );
    final choices = [
      (testZhL10n.organizationPolish, testZhL10n.organizationPolishRequest),
      (testZhL10n.organizationCondense, testZhL10n.organizationCondenseRequest),
      (
        testZhL10n.organizationStructure,
        testZhL10n.organizationStructureRequest,
      ),
      (
        testZhL10n.organizationElaborate,
        testZhL10n.organizationElaborateRequest,
      ),
    ];
    for (final choice in choices) {
      await tester.tap(find.text(choice.$1));
      expect(selected.last, choice.$2);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} 小按鈕固定單排，可橫向捲動並逐次選擇', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final selected = <String>[];
      await tester.pumpWidget(
        widgetTestApp(
          brightness: brightness,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: OrganizationQuickActions(
              compact: true,
              enabled: true,
              onSelected: selected.add,
            ),
          ),
        ),
      );
      final first = find.byKey(const ValueKey('organization-quick-0'));
      final last = find.byKey(const ValueKey('organization-quick-3'));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
      await tester.tap(first);
      await tester.drag(
        find.byKey(const ValueKey('organization-quick-bar')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(last);
      expect(selected, [
        testZhL10n.organizationPolishRequest,
        testZhL10n.organizationElaborateRequest,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '${brightness == Brightness.light ? '亮色' : '暗色'}窄畫面大字的選項可捲動，忙碌時停用',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var calls = 0;
        await tester.pumpWidget(
          widgetTestApp(
            brightness: brightness,
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: OrganizationQuickActions(
                      enabled: false,
                      onSelected: (_) => calls++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final last = find.byKey(const ValueKey('organization-quick-3'));
        await tester.ensureVisible(last);
        await tester.tap(last);
        expect(calls, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
