import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/app/theme.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/features/editor/presentation/editor_form_sections.dart';
import 'package:quill_diary/features/editor/presentation/editor_top_bar.dart';
import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_date_time_column.dart';

void main() {
  group('EntryDateTimeColumn', () {
    testWidgets('uses the same formatted strings as home list datetime', (
      WidgetTester tester,
    ) async {
      const DateOnly date = DateOnly('2026-07-02');
      final DateTime at = DateTime(2026, 7, 2, 14, 30);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          locale: appZhLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: EntryDateTimeColumn(date: date, at: at),
              );
            },
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(Scaffold));
      expect(
        find.text(DisplayFormat.formatDateOnly(context.l10n, date)),
        findsOneWidget,
      );
      expect(
        find.text(DisplayFormat.formatWeekdayAndTime(context.l10n, date, at)),
        findsOneWidget,
      );
    });
  });

  group('Editor chrome layout', () {
    testWidgets('edit mode shows timestamp in top bar and toolbar under title', (
      WidgetTester tester,
    ) async {
      const DateOnly date = DateOnly('2026-07-02');
      final DateTime at = DateTime(2026, 7, 2, 9, 15);
      final TextEditingController titleController = TextEditingController(
        text: '測試標題',
      );
      final TextEditingController bodyController = TextEditingController();
      final TextEditingController tagsController = TextEditingController();
      late String timestampLabel;

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          locale: appZhLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              timestampLabel =
                  '${DisplayFormat.formatDateOnlyWithWeekday(context.l10n, date)} · ${DisplayFormat.formatTime24h(at)}';
              return Scaffold(
                body: Column(
                  children: <Widget>[
                    EditorTopBar(
                      previewMode: false,
                      saving: false,
                      canSaveEntry: true,
                      canDelete: true,
                      timestampLabel: timestampLabel,
                      onClose: () {},
                      onSave: () {},
                      onDelete: () {},
                      onEnterEditMode: () {},
                    ),
                    EditorTitleSection(
                      previewMode: false,
                      titleController: titleController,
                      bodyController: bodyController,
                      tagsController: tagsController,
                      typography: EditorTypographyPreferences.defaults,
                      showEntryRequiredHint: false,
                      showUnsavedTag: false,
                      showMetadataTags: true,
                      tagAccentArgbMap: const <String, int>{},
                      editToolbar: EditorActionToolbar(
                        saving: false,
                        onPickDate: () {},
                        onPickTime: () {},
                        onEditTags: () {},
                        onPickImage: () {},
                        onPickFile: () {},
                        onInsertCheckbox: () {},
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text(timestampLabel), findsOneWidget);

      expect(find.byKey(const Key('editor-top-bar-close')), findsOneWidget);
      expect(find.byKey(const Key('editor-action-toolbar')), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2));
      expect(find.byKey(const Key('editor-top-bar-save')), findsOneWidget);
      expect(find.byKey(const Key('editor-top-bar-delete')), findsOneWidget);
      expect(find.byKey(const Key('editor-top-bar-edit')), findsNothing);

      final Offset saveOffset = tester.getTopLeft(
        find.byKey(const Key('editor-top-bar-save')),
      );
      final Offset toolbarOffset = tester.getTopLeft(
        find.byKey(const Key('editor-action-toolbar')),
      );
      expect(toolbarOffset.dy, greaterThan(saveOffset.dy));
    });

    testWidgets('preview mode keeps edit action in top bar only', (
      WidgetTester tester,
    ) async {
      const DateOnly date = DateOnly('2026-07-02');
      final DateTime at = DateTime(2026, 7, 2, 9, 15);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness: Brightness.light),
          locale: appZhLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              final String timestampLabel =
                  '${DisplayFormat.formatDateOnlyWithWeekday(context.l10n, date)} · ${DisplayFormat.formatTime24h(at)}';
              return Scaffold(
                body: EditorTopBar(
                  previewMode: true,
                  saving: false,
                  canSaveEntry: false,
                  canDelete: true,
                  timestampLabel: timestampLabel,
                  onClose: () {},
                  onSave: () {},
                  onDelete: () {},
                  onEnterEditMode: () {},
                ),
              );
            },
          ),
        ),
      );

      expect(find.byKey(const Key('editor-top-bar-edit')), findsOneWidget);
      expect(find.byKey(const Key('editor-action-toolbar')), findsNothing);
      expect(find.byKey(const Key('editor-top-bar-save')), findsNothing);
    });
  });
}
