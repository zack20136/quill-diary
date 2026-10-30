import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/infrastructure/ai/ai_client.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_error_text.dart';
import 'package:quill_diary/presentation/chat_diary/chat_diary_hidden_text.dart';
import 'package:quill_diary/presentation/editor/widgets/editor_markdown_preview.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

class ChatDiaryMessageBubble extends ConsumerWidget {
  const ChatDiaryMessageBubble({
    super.key,
    required this.chatSession,
    required this.message,
    required this.versions,
    required this.isBusy,
    required this.imageBuilder,
    required this.onSelectVersion,
    required this.onEditMessage,
    required this.onRegenerateReply,
  });
  final ChatDiarySession chatSession;
  final ChatDiaryMessage message;
  final List<ChatDiaryMessage> versions;
  final bool isBusy;
  final Widget Function(String imageId) imageBuilder;
  final ValueChanged<String> onSelectVersion;
  final ValueChanged<ChatDiaryMessage> onEditMessage;
  final ValueChanged<String> onRegenerateReply;

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!context.mounted) return;
    showAppFeedbackToast(
      context,
      context.l10n.commonCopiedToClipboard,
      tone: AppFeedbackTone.success,
    );
  }

  Widget _versions(BuildContext context) {
    final chat = chatSession;
    if (versions.length < 2) return const SizedBox.shrink();
    final index = versions.indexOf(message);
    final enabled = !isBusy && chat.editingMessageId == null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.chatDiaryPreviousVersion,
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: enabled && index > 0
              ? () => onSelectVersion(versions[index - 1].id)
              : null,
        ),
        Text(
          '${index + 1} / ${versions.length}',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.chatDiaryNextVersion,
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: enabled && index < versions.length - 1
              ? () => onSelectVersion(versions[index + 1].id)
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = chatSession;
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final enabled = !isBusy && chat.editingMessageId == null && !chat.finished;
    final failed =
        message.status == ChatDiaryMessageStatus.failed ||
        message.status == ChatDiaryMessageStatus.interrupted;
    final failure = AiErrorCode.values
        .where((e) => e.name == message.errorCode)
        .firstOrNull;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: message.isUser ? 0.88 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: message.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.imageIds.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: message.text.isNotEmpty ? 8 : 0,
                  ),
                  child: Wrap(
                    alignment: message.isUser
                        ? WrapAlignment.end
                        : WrapAlignment.start,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final imageId in message.imageIds)
                        imageBuilder(imageId),
                    ],
                  ),
                ),
              if (message.text.isNotEmpty ||
                  message.status == ChatDiaryMessageStatus.pending)
                Container(
                  padding: message.isUser
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
                      : const EdgeInsets.symmetric(vertical: 4),
                  decoration: message.isUser
                      ? BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.text.isNotEmpty)
                        if (message.isUser)
                          SelectionArea(
                            child: message.privateRanges.isEmpty
                                ? Text(message.text)
                                : Text.rich(
                                    chatDiaryHiddenTextSpan(
                                      text: message.text,
                                      ranges: message.privateRanges,
                                      highlight: chatDiaryHiddenHighlight(
                                        colors,
                                      ),
                                    ),
                                  ),
                          )
                        else
                          EditorMarkdownPreview(
                            markdown: message.text,
                            typography: watchPersonalizationPreferences(ref)
                                .typography,
                          ),
                      if (message.status == ChatDiaryMessageStatus.pending)
                        const _ReplyPendingIndicator(),
                    ],
                  ),
                ),
              if (message.status == ChatDiaryMessageStatus.interrupted ||
                  message.status == ChatDiaryMessageStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message.status == ChatDiaryMessageStatus.interrupted
                        ? l10n.chatDiaryInterrupted
                        : failure == null
                        ? l10n.aiErrorUnexpected
                        : aiErrorText(l10n, failure),
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: colors.error),
                  ),
                ),
              if (message.status != ChatDiaryMessageStatus.pending)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 2,
                  children: [
                    _versions(context),
                    if (message.text.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l10n.commonActionCopy,
                        icon: const Icon(Icons.content_copy_outlined, size: 17),
                        onPressed: !isBusy && chat.editingMessageId == null
                            ? () => _copyMessage(context)
                            : null,
                      ),
                    if (!chat.finished && message.isUser)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l10n.chatDiaryEditMessage,
                        icon: const Icon(Icons.edit_outlined, size: 17),
                        onPressed: enabled
                            ? () => onEditMessage(message)
                            : null,
                      ),
                    if (!chat.finished && !message.isUser) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: failed
                            ? l10n.chatDiaryRetry
                            : l10n.chatDiaryRegenerateReply,
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: enabled
                            ? () => onRegenerateReply(message.id)
                            : null,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyPendingIndicator extends StatefulWidget {
  const _ReplyPendingIndicator();

  @override
  State<_ReplyPendingIndicator> createState() => _ReplyPendingIndicatorState();
}

class _ReplyPendingIndicatorState extends State<_ReplyPendingIndicator>
    with SingleTickerProviderStateMixin {
  late final _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool? _animationsDisabled;
  late final _dotOpacities = [
    for (var index = 0; index < 3; index++)
      Tween<double>(begin: 0.25, end: 1)
          .chain(
            CurveTween(
              curve: Interval(
                index * 0.2,
                0.6 + index * 0.2,
                curve: Curves.easeInOut,
              ),
            ),
          )
          .animate(_animationController),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (_animationsDisabled == disabled) return;
    _animationsDisabled = disabled;
    if (disabled) {
      _animationController.stop();
      _animationController.value = 0.5;
    } else {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.chatDiaryWaitingForReply,
    child: SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final opacity in _dotOpacities)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FadeTransition(
                opacity: opacity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 6),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
