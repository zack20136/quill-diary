import 'package:material_ui/material_ui.dart';

class AiComposerActions extends StatelessWidget {
  const AiComposerActions({
    super.key,
    required this.model,
    required this.onAction,
    required this.actionLabel,
    required this.actionKey,
    this.actionTooltip,
  });

  final Widget? model;
  final VoidCallback? onAction;
  final String actionLabel;
  final Key actionKey;
  final String? actionTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall!;
    final generate = AiComposerActionButton(
      actionKey: actionKey,
      label: actionLabel,
      tooltip: actionTooltip,
      onPressed: onAction,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          final painter = TextPainter(
            text: TextSpan(text: actionLabel, style: style),
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

class AiComposerActionButton extends StatelessWidget {
  const AiComposerActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.actionKey,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? actionKey;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall!;
    return Tooltip(
      message: tooltip ?? label,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: actionKey,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 18),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: style.copyWith(
                    color: onPressed == null
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
