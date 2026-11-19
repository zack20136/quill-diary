import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/settings/pages/settings_page.dart';
import 'package:quill_diary/presentation/settings/widgets/local_backup_section.dart';
import 'package:quill_diary/shared/navigation/app_routes.dart';

import '../../helpers/presentation/settings/settings_test_scope.dart';

void main() {
  testWidgets('從還原入口進入設定會對齊並聚焦本機備份卡片', (WidgetTester tester) async {
    await tester.pumpWidget(
      settingsTestScope(
        child: const SettingsPage(
          entryAction: SettingsEntryAction.focusExternalRestore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext sectionContext = tester.element(
      find.byType(LocalBackupSection),
    );
    expect(Focus.of(sectionContext).hasFocus, isTrue);
  });
}
