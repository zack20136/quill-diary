import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          draft
                            ..clear()
                            ..addAll(
                              entries.map((PortableEntryOption<T> e) => e.id),
                            );
                        });
                      },
                      child: Text(l10n.homeSelectionSelectAll),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(draft.clear);
                      },
                      child: Text(l10n.homeSelectionDeselectAll),
                    ),
                    const Spacer(),
                    Text(
                      l10n.portableExportSelectEntriesSummary(
                        draft.length,
                        entries.length,
                      ),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: Material(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
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
                ),
              ],
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

class PortableTransferSummaryCard extends StatelessWidget {
  const PortableTransferSummaryCard({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < lines.length; index++) ...<Widget>[
              if (index > 0) const SizedBox(height: 4),
              Text(lines[index]),
            ],
          ],
        ),
      ),
    );
  }
}
