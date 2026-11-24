import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/ai/ai_request_preview.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/presentation/ai/ai_preview_text_section.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/private_text_spans.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_section.dart';
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
    final preview = this.preview.effective();
    final turns = preview.conversationTurns ?? preview.turns;
    final l10n = context.l10n;
    final galleryImageIds = [for (final turn in turns) ...turn.imageIds];
    final diary = preview.diaryContext;
    final generation = generationPreview?.effective();
    final material = generation?.conversationTurns == null
        ? null
        : generation?.turns.singleOrNull;
    final generationData = material == null
        ? null
        : _decodeMaterial(material.text);
    final chatPrompt = generation == null
        ? l10n.chatDiarySystemLabel
        : l10n.aiPreviewSystemLabel(l10n.aiRequestPreviewChat);
    final generationPrompt = l10n.aiPreviewSystemLabel(
      generationLabel ?? l10n.chatDiaryGenerateDiary,
    );
    final theme = Theme.of(context);
    final sections = <Widget>[
      AppDialogSection(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            Expanded(
              child: Text(
                l10n.chatDiaryRequestPreviewHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      if (generation != null)
        AiPreviewTextSection(
          key: const ValueKey('ai-request-json'),
          title: l10n.aiRequestPreviewFullJson,
          description: l10n.aiRequestPreviewJsonHint,
          text: _requestJson(
            preview,
            generation,
            chatPrompt: chatPrompt,
            generationPrompt: generationPrompt,
            material: material,
            generationData: generationData,
          ),
        ),
      AiPreviewTextSection(
        key: const ValueKey('ai-request-instructions'),
        title: chatPrompt,
        text: preview.instructions,
      ),
      if (generation != null) ...[
        AiPreviewTextSection(
          key: const ValueKey('ai-request-generation-instructions'),
          title: generationPrompt,
          text: generation.instructions,
        ),
        if (material != null)
          AppDialogSummary(
            icon: Icons.forum_outlined,
            title: l10n.chatDiaryGenerationDataLabel,
            details: [
              ..._generationSummary(l10n, generationData),
              if (generation.hasLocalPrivateNotes)
                l10n.chatDiaryPreviewLocalNotes,
            ],
          ),
      ],
      if (diary != null) ...[
        AiPreviewTextSection(
          key: const ValueKey('ai-request-original'),
          title: l10n.aiRequestOriginalBody,
          text: diary.diaryBody,
          initiallyExpanded: true,
        ),
      ],
    ];
    return AppDialogShell(
      fillHeight: true,
      title: l10n.aiPreviewRequest,
      content: AppScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < sections.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              sections[index],
            ],
            if (sections.isNotEmpty) const SizedBox(height: 12),
            if (turns.isEmpty)
              AppDialogSummary(
                icon: Icons.forum_outlined,
                title: l10n.chatDiaryPreviewEmpty,
              )
            else
              for (var index = 0; index < turns.length; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                _PreviewTurnCard(
                  turn: turns[index],
                  galleryImageIds: galleryImageIds,
                  imageBuilder: imageBuilder,
                ),
              ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonActionClose),
        ),
      ],
    );
  }

  Object? _decodeMaterial(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  String _requestJson(
    AiRequestPreview chat,
    AiRequestPreview generation, {
    required String chatPrompt,
    required String generationPrompt,
    required AiPreviewTurn? material,
    required Object? generationData,
  }) {
    final photoNumbers = <String, int>{};
    List<String> photos(AiPreviewTurn turn) => [
      for (final id in turn.imageIds)
        'photo_${photoNumbers.putIfAbsent(id, () => photoNumbers.length + 1)}',
    ];
    Map<String, Object?> settings(AiRequestPreview preview, String prompt) => {
      if (preview.request case final request?)
        'model': request.connection.model,
      'prompt': prompt,
      'parameters': preview.request?.requestFields ?? const <String, Object?>{},
    };
    List<Map<String, Object?>> messages(AiRequestPreview preview) => [
      for (final turn in preview.turns)
        {
          'role': turn.isUser ? 'user' : 'assistant',
          'text': turn.text,
          if (turn.imageIds.isNotEmpty) 'photos': photos(turn),
          if (turn.pending) 'pending': true,
        },
    ];
    return const JsonEncoder.withIndent('  ').convert({
      'chat': {
        ...settings(chat, chatPrompt),
        'messages': messages(chat),
        if (chat.diaryContext case final diary?) 'diary_body': diary.diaryBody,
      },
      'generation': {
        ...settings(generation, generationPrompt),
        if (material == null)
          'messages': messages(generation)
        else ...{
          'data': generationData,
          if (material.imageIds.isNotEmpty) 'photos': photos(material),
        },
        if (generation.diaryContext case final diary?)
          'diary_body': diary.diaryBody,
      },
    });
  }

  List<String> _generationSummary(AppLocalizations l10n, Object? data) {
    if (data case {
      'user_turns': final List<Object?> userTurns,
      'assistant_context': final List<Object?> context,
    }) {
      if (userTurns.isEmpty) return [l10n.chatDiaryGenerationNoSentMessages];
      return [
        l10n.chatDiaryGenerationUserCount(userTurns.length),
        l10n.chatDiaryGenerationContextCount(context.length),
      ];
    }
    return [];
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
