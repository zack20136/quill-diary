import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/chat_diary/chat_diary_request_preview.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_hidden_text.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

typedef ChatDiaryPreviewImageBuilder = Widget Function(
  String imageId,
  List<String> galleryImageIds,
);

class ChatDiaryRequestPreviewDialog extends StatelessWidget {
  const ChatDiaryRequestPreviewDialog({
    super.key,
    required this.preview,
    required this.imageBuilder,
  });

  final ChatDiaryRequestPreview preview;
  final ChatDiaryPreviewImageBuilder imageBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final galleryImageIds = [
      for (final turn in preview.turns) ...turn.imageIds,
    ];
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.onSurfaceVariant);
    return AppDialogShell(
      title: l10n.chatDiaryPreviewRequest,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.chatDiaryRequestPreviewHint, style: muted),
                  const SizedBox(height: 12),
                  _SystemPromptCard(prompt: preview.systemPrompt),
                  const SizedBox(height: 12),
                  Expanded(
                    child: preview.turns.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              l10n.chatDiaryPreviewEmpty,
                              style: muted,
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 4),
                            itemCount: preview.turns.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _PreviewTurnCard(
                              turn: preview.turns[index],
                              galleryImageIds: galleryImageIds,
                              imageBuilder: imageBuilder,
                            ),
                          ),
                  ),
                ],
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
    );
  }
}

class _SystemPromptCard extends StatefulWidget {
  const _SystemPromptCard({required this.prompt});

  final String prompt;

  @override
  State<_SystemPromptCard> createState() => _SystemPromptCardState();
}

class _SystemPromptCardState extends State<_SystemPromptCard> {
  var _expanded = false;

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
                      context.l10n.chatDiarySystemPrompt,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: colors.onSurfaceVariant,
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
                child: _HiddenSelectableText(widget.prompt),
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

  final ChatDiaryPreviewTurn turn;
  final List<String> galleryImageIds;
  final ChatDiaryPreviewImageBuilder imageBuilder;

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
    final message = turn.text.isEmpty
        ? null
        : user
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _HiddenSelectableText(turn.text),
            ),
          )
        : _HiddenSelectableText(turn.text);
    final images = turn.imageIds.isEmpty
        ? null
        : Wrap(
            alignment: user ? WrapAlignment.end : WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in turn.imageIds) imageBuilder(id, galleryImageIds),
            ],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (turn.pending && user) ...[
                pendingTag,
                const SizedBox(width: 8),
              ],
              role,
              if (turn.pending && !user) ...[
                const SizedBox(width: 8),
                pendingTag,
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: user ? 0.88 : 1,
            child: Column(
              crossAxisAlignment: user
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (images != null && message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: images,
                  ),
                if (message != null) message else ?images,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HiddenSelectableText extends StatelessWidget {
  const _HiddenSelectableText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText.rich(
      chatDiaryHiddenTextSpan(
        text: text,
        ranges: chatDiaryPrivacyTokenRanges(text),
        highlight: chatDiaryHiddenHighlight(Theme.of(context).colorScheme),
      ),
    );
  }
}
