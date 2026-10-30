import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/widgets/local_backup_section.dart';
import 'package:quill_diary/presentation/settings/widgets/settings_sections.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';

import '../../helpers/presentation/settings/settings_test_scope.dart';
import '../../helpers/shared/test_l10n.dart';

void main() {
  testWidgets('externalRestore 對齊後會聚焦本機備份與還原卡片', (WidgetTester tester) async {
    await tester.pumpWidget(
      settingsTestScope(
        child: const SettingsPage(
          initialFocus: SettingsFocusTarget.externalRestore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext sectionContext = tester.element(
      find.byType(LocalBackupSection),
    );
    expect(Focus.of(sectionContext).hasFocus, isTrue);
  });

  testWidgets('recoveryKey 捲動後仍會聚焦復原金鑰卡片', (WidgetTester tester) async {
    await tester.pumpWidget(
      settingsTestScope(
        child: const SettingsPage(
          initialFocus: SettingsFocusTarget.recoveryKey,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext sectionContext = tester.element(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is SettingsSectionCard &&
            widget.title == testL10n.settingsSecurityOverviewSectionTitle,
      ),
    );
    expect(Focus.of(sectionContext).hasFocus, isTrue);
  });
}
