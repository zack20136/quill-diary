import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_request_preview.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/presentation/ai/ai_preview_text_section.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

typedef AiPreviewImageBuilder = Widget Function(
  String imageId,
  List<String> galleryImageIds,
);

class AiRequestPreviewDialog extends StatelessWidget {
  const AiRequestPreviewDialog({
    super.key,
    required this.preview,
    this.imageBuilder,
    this.generationPreview,
    this.generationLabel,
  });

  final AiRequestPreview preview;
  final AiPreviewImageBuilder? imageBuilder;
  final AiRequestPreview? generationPreview;
  final String? generationLabel;

  @override
  Widget build(BuildContext context) {
    final turns = preview.conversationTurns ?? preview.turns;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final galleryImageIds = [for (final turn in turns) ...turn.imageIds];
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.onSurfaceVariant);
    final diary = preview.diaryContext;
    final generation = generationPreview;
    final sections = <Widget>[
      Text(l10n.chatDiaryRequestPreviewHint, style: muted),
      if ((generation ?? preview).hasLocalPrivateNotes)
        Text(l10n.chatDiaryPrivateNotesHint, style: muted),
      if (generation == null)
        AiPreviewTextSection(
          key: const ValueKey('ai-request-instructions'),
          title: l10n.chatDiarySystemLabel,
          text: preview.instructions,
        )
      else ...[
        AiPreviewTextSection(
          key: const ValueKey('ai-request-instructions'),
          title: l10n.aiPreviewSystemLabel(l10n.aiRequestPreviewChat),
          text: preview.instructions,
        ),
        AiPreviewTextSection(
          key: const ValueKey('ai-request-generation-instructions'),
          title: l10n.aiPreviewSystemLabel(
            generationLabel ?? l10n.chatDiaryGenerateDiary,
          ),
          text: generation.instructions,
        ),
      ],
      if (diary != null) ...[
        AiPreviewTextSection(
          key: const ValueKey('ai-request-original'),
          title: l10n.aiRequestOriginalBody,
          text: diary.originalBody,
          initiallyExpanded: true,
        ),
      ],
    ];
    return Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          backgroundColor: theme.scaffoldBackgroundColor,
        ),
      ),
      child: AppDialogShell(
        title: l10n.aiPreviewRequest,
        content: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            final desiredMax = math.min(
              screenHeight * 0.82,
              personaDialogBodyHeight(context),
            );
            final maxHeight = constraints.maxHeight.isFinite
                ? math.min(desiredMax, constraints.maxHeight)
                : desiredMax;
            final minHeight = math.min(screenHeight * 0.58, maxHeight);
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: minHeight,
                maxHeight: maxHeight,
              ),
              child: SizedBox(
                width: double.infinity,
                height: maxHeight,
                child: AppScrollableContent(
                  builder: (_, controller) => ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 4),
                    itemCount:
                        sections.length + (turns.isEmpty ? 1 : turns.length),
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, itemIndex) {
                      if (itemIndex < sections.length) {
                        return sections[itemIndex];
                      }
                      final index = itemIndex - sections.length;
                      if (turns.isEmpty) {
                        return Text(l10n.chatDiaryPreviewEmpty, style: muted);
                      }
                      return _PreviewTurnCard(
                        turn: turns[index],
                        galleryImageIds: galleryImageIds,
                        imageBuilder: imageBuilder,
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonActionClose),
          ),
        ],
      ),
    );
  }
}

class _PreviewTurnCard extends StatelessWidget {
  const _PreviewTurnCard({
    required this.turn,
    required this.galleryImageIds,
    required this.imageBuilder,
  });

  final AiPreviewTurn turn;
  final List<String> galleryImageIds;
  final AiPreviewImageBuilder? imageBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final user = turn.isUser;
    final role = Text(
      user ? l10n.chatDiaryPreviewUser : l10n.chatDiaryPreviewAssistant,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: user ? colors.primary : colors.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
    final pendingTag = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          l10n.chatDiaryPreviewPending,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: colors.onSecondaryContainer),
        ),
      ),
    );
    return AiMessageView(
      text: turn.text,
      isUser: user,
      format: AiMessageFormat.plainText,
      privateRanges: privacyTokenRanges(turn.text),
      images: [
        for (final id in turn.imageIds) imageBuilder!(id, galleryImageIds),
      ],
      header: Wrap(
        alignment: user ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          if (turn.pending && user) pendingTag,
          role,
          if (turn.pending && !user) pendingTag,
        ],
      ),
    );
  }
}
