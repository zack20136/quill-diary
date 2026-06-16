import 'package:flutter/material.dart';

import '../settings_copy.dart';
import 'backup_pick_list_item.dart';

typedef BackupDeleteConfirm = Future<bool> Function(String fileName);

/// 顯示本機或雲端備份還原清單，支援刪除與選取。
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

  final List<BackupPickListItem> visibleItems = List<BackupPickListItem>.from(items);
  return showDialog<BackupPickListItem>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final TextTheme textTheme = Theme.of(context).textTheme;
          final double dialogWidth = (MediaQuery.sizeOf(context).width - 32)
              .clamp(320.0, 420.0);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: dialogWidth,
              child: visibleItems.isEmpty
                  ? Text(emptyMessage)
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleItems.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (BuildContext context, int index) {
                        final BackupPickListItem item = visibleItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          title: Text(
                            item.createdAtLabel,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
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
                          onTap: () => Navigator.of(dialogContext).pop(item),
                          trailing: item.onDelete == null
                              ? null
                              : IconButton(
                                  tooltip: deleteTooltip,
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: actionsDisabled
                                      ? null
                                      : () async {
                                          final bool confirmed =
                                              await confirmDelete(item.fileName);
                                          if (!confirmed) {
                                            return;
                                          }
                                          await item.onDelete!();
                                          setDialogState(() {
                                            visibleItems.removeAt(index);
                                          });
                                        },
                                ),
                        );
                      },
                    ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(SettingsCopy.actionCancel),
              ),
            ],
          );
        },
      );
    },
  );
}
