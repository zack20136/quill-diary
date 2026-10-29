import 'package:material_ui/material_ui.dart';

import '../../domain/chat_diary/chat_diary_session.dart';
import '../../l10n/l10n.dart';
import 'chat_diary_private_text_controller.dart';

class ChatDiaryInputPanel extends StatelessWidget {
  const ChatDiaryInputPanel({
    super.key,
    required this.chatSession,
    required this.isBusy,
    required this.canSend,
    required this.composerController,
    required this.composerFocusNode,
    required this.imageBuilder,
    required this.onCancelEditing,
    required this.onPickImages,
    required this.onOpenSettings,
    required this.onSend,
  });
  final ChatDiarySession chatSession;
  final bool isBusy;
  final bool canSend;
  final ChatDiaryPrivateTextController composerController;
  final FocusNode composerFocusNode;
  final Widget Function(String imageId) imageBuilder;
  final VoidCallback onCancelEditing;
  final VoidCallback onPickImages;
  final VoidCallback onOpenSettings;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final chat = chatSession;
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (chat.editingMessageId != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.chatDiaryEditingMessage,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: isBusy ? null : onCancelEditing,
                      child: Text(l10n.commonActionCancel),
                    ),
                  ],
                ),
              ),
            if (chat.pendingImageIds.isNotEmpty)
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  children: [
                    for (final id in chat.pendingImageIds)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: imageBuilder(id),
                      ),
                  ],
                ),
              ),
            TextField(
              key: const ValueKey('chat-diary-composer'),
              controller: composerController,
              focusNode: composerFocusNode,
              minLines: 1,
              maxLines: 5,
              enabled: !isBusy,
              decoration: InputDecoration(
                hintText: l10n.chatDiaryMessageHint,
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontStyle: FontStyle.normal,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: isBusy ? null : onOpenSettings,
                    tooltip: l10n.aiSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  IconButton(
                    onPressed: isBusy ? null : onPickImages,
                    tooltip: l10n.chatDiaryChooseImages,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  IconButton(
                    tooltip:
                        !composerController.selection.isValid ||
                            composerController.selection.isCollapsed
                        ? l10n.chatDiarySelectPrivateText
                        : composerController.selectionIsPrivate
                        ? l10n.chatDiaryUnhideSelection
                        : l10n.chatDiaryHideSelection,
                    onPressed:
                        isBusy ||
                            !composerController.selection.isValid ||
                            composerController.selection.isCollapsed ||
                            (composerController.value.composing.isValid &&
                                !composerController.value.composing.isCollapsed)
                        ? null
                        : () {
                            if (composerController.selectionIsPrivate) {
                              composerController.unhideSelection();
                            } else {
                              composerController.hideSelection();
                            }
                            composerFocusNode.requestFocus();
                          },
                    icon: Icon(
                      composerController.selectionIsPrivate
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: !isBusy && canSend ? onSend : null,
                    tooltip: isBusy
                        ? l10n.chatDiaryWorking
                        : chat.editingMessageId == null
                        ? l10n.chatDiarySend
                        : l10n.chatDiaryResendMessage,
                    icon: isBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
