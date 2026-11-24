import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/presentation/settings/backup/backup_pick_dialog.dart';
import 'package:quill_diary/presentation/settings/backup/backup_pick_list_item.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/shared/widget_test_app.dart';

void main() {
  testWidgets('備份刪除失敗保留項目，重試成功後仍可關閉', (tester) async {
    const name = 'backup-test.zip';
    final firstDelete = Completer<void>();
    var attempts = 0;
    const opening = ValueKey('open-backup-picker');
    BackupPickListItem? picked;

    await tester.pumpWidget(
      widgetTestApp(
        child: Builder(
          builder: (context) => FilledButton(
            key: opening,
            onPressed: () async {
              picked = await showBackupPickDialog(
                context: context,
                title: testL10n.settingsLocalBackupPickDialogTitle,
                emptyMessage: testL10n.settingsLocalBackupNoBackups,
                deleteTooltip: testL10n.settingsBackupDeleteTooltip,
                confirmDelete: (fileName) async => fileName == name,
                items: [
                  BackupPickListItem(
                    id: 'test-backup',
                    createdAtLabel: '2026/11/24',
                    fileName: name,
                    onDelete: () async {
                      if (++attempts == 1) await firstDelete.future;
                    },
                  ),
                ],
              );
            },
            child: const Text('開啟測試備份清單'),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(opening));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(testL10n.settingsBackupDeleteTooltip));
    await tester.pumpAndSettle();

    final row = find.ancestor(
      of: find.text(name),
      matching: find.byType(ListTile),
    );
    final delete = find.byTooltip(testL10n.settingsBackupDeleteTooltip);
    expect(tester.widget<ListTile>(row).onTap, isNull);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
          )
          .onPressed,
      isNull,
    );
    firstDelete.completeError(StateError('測試刪除失敗'));
    await tester.pumpAndSettle();
    final error = find.text(testL10n.settingsBackupDeleteFailed('').trim());
    expect(error.hitTestable(), findsOneWidget);
    expect(tester.widget<ListTile>(row).onTap, isNotNull);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(error, findsNothing);
    expect(find.text(name), findsNothing);
    expect(find.text(testL10n.settingsLocalBackupNoBackups), findsOneWidget);

    await tester.tap(find.text(testL10n.commonActionCancel));
    await tester.pumpAndSettle();

    expect(find.byKey(opening).hitTestable(), findsOneWidget);
    expect(picked, isNull);
  });
}
