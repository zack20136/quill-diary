import 'package:flutter/material.dart';

import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'backup_pick_list_item.dart';

typedef BackupDeleteConfirm = Future<bool> Function(String fileName);

Future<BackupPickListItem?> showBackupPickDialog({
  required BuildContext context,
  required String title,
  required String emptyMessage,
  required String deleteTooltip,
  required BackupDeleteConfirm confirmDelete,
  required List<BackupPickListItem> items,
  bool actionsDisabled = false,
}) async {
  if (items.isEmpty) {
    return null;
  }

  final List<BackupPickListItem> visibleItems = List<BackupPickListItem>.from(
    items,
  );
  return showAppDialog<BackupPickListItem>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final TextTheme textTheme = Theme.of(context).textTheme;

          return AppDialogShell(
            title: title,
            content: visibleItems.isEmpty
                ? Text(emptyMessage)
                : SizedBox(
                    width: double.infinity,
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final BackupPickListItem item = visibleItems[index];
                        return InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        item.createdAtLabel,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.fileName,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (item.sizeLabel != null) ...<Widget>[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.sizeLabel!,
                                          style: textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (item.onDelete != null) ...<Widget>[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: IconButton(
                                      tooltip: deleteTooltip,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.error,
                                        size: 22,
                                      ),
                                      onPressed: actionsDisabled
                                          ? null
                                          : () async {
                                              final bool confirmed =
                                                  await confirmDelete(
                                                    item.fileName,
                                                  );
                                              if (!confirmed) {
                                                return;
                                              }
                                              await item.onDelete!();
                                              setDialogState(() {
                                                visibleItems.removeAt(index);
                                              });
                                            },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.l10n.commonActionCancel),
              ),
            ],
          );
        },
      );
    },
  );
}
