import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

class PortableEntryOption<T> {
  const PortableEntryOption({
    required this.id,
    this.title,
    required this.subtitle,
  });

  final T id;
  final String? title;
  final String subtitle;
}

Future<Set<T>?> showPortableEntrySelectionDialog<T>({
  required BuildContext context,
  required List<PortableEntryOption<T>> entries,
  required Set<T> initiallySelected,
}) {
  final Set<T> draft = Set<T>.from(initiallySelected);

  return showAppDialog<Set<T>>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          final ColorScheme cs = Theme.of(context).colorScheme;
          final bool canConfirm = draft.isNotEmpty;

          return AppDialogShell(
            title: l10n.portableExportSelectEntriesLabel,
            content: AppScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: <Widget>[
                  AppDialogSummary(
                    icon: Icons.checklist_rounded,
                    title: l10n.portableExportSelectEntriesSummary(
                      draft.length,
                      entries.length,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      TextButton(
                        onPressed: draft.length == entries.length
                            ? null
                            : () => setState(() {
                                draft
                                  ..clear()
                                  ..addAll(
                                    entries.map(
                                      (PortableEntryOption<T> e) => e.id,
                                    ),
                                  );
                              }),
                        child: Text(l10n.homeSelectionSelectAll),
                      ),
                      TextButton(
                        onPressed: draft.isEmpty
                            ? null
                            : () => setState(draft.clear),
                        child: Text(l10n.homeSelectionDeselectAll),
                      ),
                    ],
                  ),
                  AppDialogSection(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: entries.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withValues(alpha: 0.35),
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        final PortableEntryOption<T> entry = entries[index];
                        final String title =
                            (entry.title?.trim().isNotEmpty ?? false)
                            ? entry.title!.trim()
                            : l10n.editorUntitledDraft;
                        final bool selected = draft.contains(entry.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                draft.add(entry.id);
                              } else {
                                draft.remove(entry.id);
                              }
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entry.subtitle),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: canConfirm
                    ? () => Navigator.of(dialogContext).pop(Set<T>.from(draft))
                    : null,
                child: Text(l10n.commonActionConfirm),
              ),
            ],
          );
        },
      );
    },
  );
}

class PortableTransferEntryPickerTile extends StatelessWidget {
  const PortableTransferEntryPickerTile({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.onTap,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AppDialogSection(
      child: ListTile(
        leading: Icon(Icons.checklist_rounded, color: colors.primary),
        title: Text(l10n.portableExportSelectEntriesLabel),
        subtitle: Text(
          l10n.portableExportSelectEntriesSummary(selectedCount, totalCount),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class PortableTransferConfirmBody extends StatelessWidget {
  const PortableTransferConfirmBody({
    super.key,
    required this.summaryTitle,
    required this.summaryIcon,
    this.summaryDetails = const <String>[],
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectEntries,
    this.options = const <Widget>[],
    this.notice,
  });

  final String summaryTitle;
  final List<String> summaryDetails;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectEntries;
  final IconData summaryIcon;
  final List<Widget> options;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: <Widget>[
        AppDialogSummary(
          title: summaryTitle,
          details: summaryDetails,
          icon: summaryIcon,
        ),
        PortableTransferEntryPickerTile(
          selectedCount: selectedCount,
          totalCount: totalCount,
          onTap: onSelectEntries,
        ),
        if (options.isNotEmpty)
          AppDialogSection(child: Column(children: options)),
        ?notice,
      ],
    );
  }
}

Future<bool> showPortableTransferConfirmDialog({
  required BuildContext context,
  required String title,
  required String confirmLabel,
  required bool Function() canConfirm,
  required Widget Function(BuildContext context, StateSetter setState) body,
}) async {
  final bool? confirmed = await showAppDialog<bool>(
    context: context,
    size: AppDialogSize.standard,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final AppLocalizations l10n = context.l10n;
          return AppDialogShell(
            title: title,
            content: AppScrollView(child: body(context, setState)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.commonActionCancel),
              ),
              FilledButton(
                onPressed: canConfirm()
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return confirmed == true;
}
