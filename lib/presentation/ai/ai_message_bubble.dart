import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/presentation/ai/ai_message_view.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';

class AiMessageBubble extends StatelessWidget {
  const AiMessageBubble({
    super.key,
    required this.id,
    required this.text,
    required this.isUser,
    this.privateRanges = const [],
    this.images = const [],
    this.pending = false,
    this.failureText,
    this.canAct = true,
    this.leadingActions,
    this.onEdit,
    this.onRetry,
    this.retryFailed = false,
  });
  final String id;
  final String text;
  final bool isUser;
  final List<PrivateTextRange> privateRanges;
  final List<Widget> images;
  final bool pending;
  final String? failureText;
  final bool canAct;
  final Widget? leadingActions;
  final VoidCallback? onEdit;
  final VoidCallback? onRetry;
  final bool retryFailed;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    showAppFeedbackToast(
      context,
      context.l10n.commonCopiedToClipboard,
      tone: AppFeedbackTone.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: AiMessageView(
        text: text,
        isUser: isUser,
        format: isUser ? AiMessageFormat.plainText : AiMessageFormat.markdown,
        privateRanges: privateRanges,
        images: images,
        bodyKey: ValueKey('ai-message-body-$id'),
        bubbleFooter: pending ? const _ReplyPendingIndicator() : null,
        footer: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (failureText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  failureText!,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.error),
                ),
              ),
            if (!pending)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: [
                  ?leadingActions,
                  if (text.isNotEmpty)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.commonActionCopy,
                      icon: const Icon(Icons.content_copy_outlined, size: 17),
                      onPressed: canAct ? () => _copy(context) : null,
                    ),
                  if (onEdit != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.chatDiaryEditMessage,
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      onPressed: canAct ? onEdit : null,
                    ),
                  if (onRetry != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: retryFailed
                          ? l10n.chatDiaryRetry
                          : l10n.chatDiaryRegenerateReply,
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: canAct ? onRetry : null,
                    ),
                ],
              ),
          ],
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
