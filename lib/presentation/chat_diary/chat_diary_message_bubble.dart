import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/ai_error_text.dart';
import 'package:quill_diary/application/people/people_providers.dart';
import 'package:quill_diary/domain/ai/ai_failure.dart';
import 'package:quill_diary/domain/ai/restored_private_ranges.dart';
import 'package:quill_diary/domain/chat_diary/chat_diary_session.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_bubble.dart';
import 'package:quill_diary/presentation/ai/ai_message_version_switcher.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/person_visual.dart';

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
    final participant = message.persona == null
        ? null
        : chat.personaParticipants[message.persona!.personaId];
    final bubble = AiMessageBubble(
      id: message.id,
      text: message.text,
      isUser: message.isUser,
      privateRanges: privacyDisplayRanges(
        text: message.text,
        manual: message.privateRanges,
        automatic: message.automaticRanges,
        people: chat.hidePersonNames ? message.personRanges : const [],
        outboundText: message.isUser ? null : message.outboundText,
        originals: chat.originalTextByToken,
      ),
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
      header: message.isUser
          ? null
          : message.persona == null
          ? _DefaultSpeakerLabel(name: l10n.personaDefaultName)
          : _PersonaSpeakerLabel(
              personId: message.persona!.personId,
              name: participant?.name,
              accentArgb: participant?.accentArgb,
              deletedLabel: l10n.personaDeleted,
            ),
      onEdit: !chat.finished && message.isUser
          ? () => onEditMessage(message)
          : null,
      onRetry: !chat.finished && !message.isUser && onRegenerateReply != null
          ? () => onRegenerateReply!(message.id)
          : null,
      retryFailed: failed,
    );
    return bubble;
  }
}

class _PersonaSpeakerLabel extends ConsumerWidget {
  const _PersonaSpeakerLabel({
    required this.personId,
    required this.name,
    required this.accentArgb,
    required this.deletedLabel,
  });

  final String personId;
  final String? name;
  final int? accentArgb;
  final String deletedLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (name == null) {
      return Text(
        deletedLabel,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final person = ref
        .watch(peopleListProvider)
        .value
        ?.where((person) => person.id == personId)
        .firstOrNull;
    final surface = context.appColors.sectionInset;
    final (background, accent) = person == null
        ? personAccentPairFor(
            personId: personId,
            surface: surface,
            accentArgb: accentArgb,
          )
        : personLabelColorPair(person, surface);
    return _SpeakerCaption(name: name!, background: background, accent: accent);
  }
}

class _DefaultSpeakerLabel extends StatelessWidget {
  const _DefaultSpeakerLabel({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final background = accentColorPair(
      accent,
      context.appColors.sectionInset,
    ).$1;
    return _SpeakerCaption(name: name, background: background, accent: accent);
  }
}

class _SpeakerCaption extends StatelessWidget {
  const _SpeakerCaption({
    required this.name,
    required this.background,
    required this.accent,
  });

  final String name;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: background,
          foregroundColor: accent,
          child: Text(
            personInitials(name),
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
