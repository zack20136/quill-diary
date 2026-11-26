import 'dart:async' show unawaited;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/settings/backup/backup_pick_list_item.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

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
  var deleting = false;
  String? deleteError;
  final errorKey = GlobalKey();
  return showAppDialog<BackupPickListItem>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final ColorScheme colorScheme = Theme.of(context).colorScheme;
          final AppLocalizations l10n = context.l10n;

          Future<void> delete(BackupPickListItem item) async {
            if (deleting) return;
            setDialogState(() {
              deleting = true;
              deleteError = null;
            });
            try {
              if (!await confirmDelete(item.fileName) || !context.mounted) {
                return;
              }
              await item.onDelete!();
              visibleItems.remove(item);
            } on Object catch (error) {
              if (context.mounted) {
                deleteError = l10n
                    .settingsBackupDeleteFailed(
                      deleteTooltip,
                      userFacingErrorMessage(error, l10n: l10n, fallback: ''),
                    )
                    .trim();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (errorKey.currentContext case final bannerContext?) {
                    unawaited(Scrollable.ensureVisible(bannerContext));
                  }
                });
              }
            } finally {
              if (context.mounted) setDialogState(() => deleting = false);
            }
          }

          return PopScope(
            canPop: !deleting,
            child: AppDialogShell(
              title: title,
              closeEnabled: !deleting,
              content: AppScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: <Widget>[
                    if (deleteError case final message?)
                      AppFeedbackBanner(
                        key: errorKey,
                        message: message,
                        tone: AppFeedbackTone.error,
                        outlined: true,
                      ),
                    if (visibleItems.isEmpty)
                      AppDialogSummary(
                        icon: Icons.inventory_2_outlined,
                        title: emptyMessage,
                      )
                    else ...<Widget>[
                      AppDialogSummary(
                        icon: Icons.info_outline_rounded,
                        title: l10n.settingsBackupPickInstructions,
                      ),
                      for (final BackupPickListItem item in visibleItems)
                        AppDialogSection(
                          child: ListTile(
                            leading: Icon(
                              Icons.inventory_2_outlined,
                              color: colorScheme.primary,
                            ),
                            title: Text(
                              item.createdAtLabel,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            subtitle: Text(
                              <String>[
                                item.fileName,
                                if (item.sizeLabel case final String size) size,
                              ].join('\n'),
                            ),
                            onTap: deleting
                                ? null
                                : () => Navigator.of(dialogContext).pop(item),
                            trailing: item.onDelete == null
                                ? null
                                : IconButton(
                                    tooltip: deleteTooltip,
                                    color: colorScheme.error,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                    onPressed: actionsDisabled || deleting
                                        ? null
                                        : () => delete(item),
                                  ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonActionCancel),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
