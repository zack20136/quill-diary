import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/l10n/l10n.dart';

class ChatDiaryComposerActions extends StatelessWidget {
  const ChatDiaryComposerActions({
    super.key,
    required this.model,
    required this.onGenerate,
  });

  final Widget? model;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall!;
    final l10n = context.l10n;
    final generate = Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('chat-diary-generate'),
        onTap: onGenerate,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 18),
            child: Center(
              widthFactor: 1,
              child: Text(
                l10n.chatDiaryGenerateDiary,
                style: style.copyWith(
                  color: onGenerate == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          final painter = TextPainter(
            text: TextSpan(text: l10n.chatDiaryGenerateDiary, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout();
          final generateWidth = painter.width + 16;
          painter.dispose();
          if (model == null) {
            return Align(alignment: Alignment.centerRight, child: generate);
          }
          final minModelWidth =
              96 * scaler.scale(style.fontSize!) / style.fontSize!;
          if (constraints.maxWidth < minModelWidth + 8 + generateWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: generate),
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerLeft, child: model),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: model!),
              ),
              const SizedBox(width: 8),
              generate,
            ],
          );
        },
      ),
    );
  }
}
