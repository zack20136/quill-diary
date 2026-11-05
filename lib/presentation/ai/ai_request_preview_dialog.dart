import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_request_preview.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/shared/presentation/editor_typography_visual.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';
import 'package:quill_diary/shared/presentation/widgets/app_segmented_choice_bar.dart';
import 'package:quill_diary/shared/presentation/widgets/private_text.dart';

typedef AiPreviewImageBuilder = Widget Function(
  String imageId,
  List<String> galleryImageIds,
);

class AiRequestPreviewDialog extends StatefulWidget {
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
  State<AiRequestPreviewDialog> createState() => _AiRequestPreviewDialogState();
}

class _AiRequestPreviewDialogState extends State<AiRequestPreviewDialog> {
  bool _generate = false;

  @override
  Widget build(BuildContext context) {
    final preview = _generate ? widget.generationPreview! : widget.preview;
    final turns = preview.conversationTurns ?? preview.turns;
    final imageBuilder = widget.imageBuilder;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final galleryImageIds = [for (final turn in turns) ...turn.imageIds];
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.onSurfaceVariant);
    final diary = preview.diaryContext;
    final sections = <Widget>[
      if (widget.generationPreview != null)
        AppSegmentedChoiceBar<bool>(
          choices: [
            AppSegmentChoice(value: false, label: l10n.aiRequestPreviewChat),
            AppSegmentChoice(
              value: true,
              label: widget.generationLabel ?? l10n.chatDiaryGenerateDiary,
            ),
          ],
          selected: _generate,
          onSelected: (value) async => setState(() => _generate = value),
        ),
      Text(l10n.chatDiaryRequestPreviewHint, style: muted),
      _PreviewTextSection(
        key: const ValueKey('ai-request-instructions'),
        title: l10n.chatDiarySystemPrompt,
        text: preview.instructions,
      ),
      if (diary != null) ...[
        _PreviewTextSection(
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
            final desiredMax = screenHeight * 0.82;
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
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 4),
                  itemCount:
                      sections.length + (turns.isEmpty ? 1 : turns.length),
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, itemIndex) {
                    if (itemIndex < sections.length) return sections[itemIndex];
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

class _PreviewTextSection extends StatefulWidget {
  const _PreviewTextSection({
    super.key,
    required this.title,
    required this.text,
    this.initiallyExpanded = false,
  });

  final String title;
  final String text;
  final bool initiallyExpanded;

  @override
  State<_PreviewTextSection> createState() => _PreviewTextSectionState();
}

class _PreviewTextSectionState extends State<_PreviewTextSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurface,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _PreviewText(widget.text),
              ),
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

class _PreviewText extends ConsumerWidget {
  const _PreviewText(this.text);

  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = watchPersonalizationPreferences(ref).typography
        .bodyTextStyle(Theme.of(context).textTheme);
    return SelectionArea(
      child: PrivateText(
        text: text,
        ranges: privacyTokenRanges(text),
        style: style,
      ),
    );
  }
}
