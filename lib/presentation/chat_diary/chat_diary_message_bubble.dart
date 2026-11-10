import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/ai/restored_private_ranges.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_bubble.dart';
import 'package:quill_diary/presentation/ai/ai_message_version_switcher.dart';

class ChatDiaryMessageBubble extends StatelessWidget {
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
  final ValueChanged<String>? onRegenerateReply;

  Widget _versions() {
    final index = versions.indexOf(message);
    return AiMessageVersionSwitcher(
      index: index,
      count: versions.length,
      enabled: !isBusy && chatSession.editingMessageId == null,
      onPrevious: () => onSelectVersion(versions[index - 1].id),
      onNext: () => onSelectVersion(versions[index + 1].id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = chatSession;
    final l10n = context.l10n;
    final failed =
        message.status == ChatDiaryMessageStatus.failed ||
        message.status == ChatDiaryMessageStatus.interrupted;
    final failure = AiErrorCode.values
        .where((e) => e.name == message.errorCode)
        .firstOrNull;
    final bubble = AiMessageBubble(
      id: message.id,
      text: message.text,
      isUser: message.isUser,
      privateRanges: [
        if (!message.isUser)
          ...restoredPrivateRanges(
            outboundText: message.outboundText,
            text: message.text,
            originals: chat.originalTextByToken,
          ),
        ...message.privateRanges,
        if (chat.hidePersonNames)
          for (final span in message.personRanges)
            PrivateTextRange(span.start, span.end),
      ],
      images: [for (final id in message.imageIds) imageBuilder(id)],
      pending: message.status == ChatDiaryMessageStatus.pending,
      failureText: !failed
          ? null
          : message.status == ChatDiaryMessageStatus.interrupted
          ? l10n.chatDiaryInterrupted
          : failure == null
          ? l10n.aiErrorUnexpected
          : aiErrorText(l10n, failure),
      canAct: !isBusy && chat.editingMessageId == null,
      leadingActions: _versions(),
      onEdit: !chat.finished && message.isUser
          ? () => onEditMessage(message)
          : null,
      onRetry: !chat.finished && !message.isUser && onRegenerateReply != null
          ? () => onRegenerateReply!(message.id)
          : null,
      retryFailed: failed,
    );
    if (message.persona == null) return bubble;
    final participant = chat.personaParticipants[message.persona!.personaId];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            participant == null
                ? l10n.personaDeleted
                : l10n.personaBubbleLabel(l10n.personaTitle, participant.name),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: participant?.accentArgb == null
                  ? null
                  : Color(participant!.accentArgb!),
            ),
          ),
        ),
        bubble,
      ],
    );
  }
}
