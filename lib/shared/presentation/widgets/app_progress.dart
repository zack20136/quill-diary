import 'package:flutter/material.dart';

import '../../../app/app_colors.dart';
import '../page_style.dart';
import 'app_layout.dart';

/// 共用線性進度條，會將比例限制在有效範圍內。
class AppLinearProgressIndicator extends StatelessWidget {
  const AppLinearProgressIndicator({
    required this.value,
    this.minHeight = 8,
    super.key,
  });

  final double? value;
  final double minHeight;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value?.clamp(0.0, 1.0),
    minHeight: minHeight,
    borderRadius: BorderRadius.circular(999),
  );
}

/// 用於區塊內的簡潔進度資訊。
class AppProgressPanel extends StatelessWidget {
  const AppProgressPanel({
    required this.label,
    required this.value,
    this.stage,
    this.maxWidth = 360,
    super.key,
  });

  final String label;
  final String? stage;
  final double? value;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: AppResponsiveWidth(
        maxWidth: maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AppLinearProgressIndicator(value: value),
            if (stage != null && stage!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(stage!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// 用於阻塞流程的進度卡片，包含即時語意公告。
class AppProgressCard extends StatelessWidget {
  const AppProgressCard({
    required this.title,
    required this.message,
    required this.semanticLabel,
    required this.value,
    this.trailing,
    this.hint,
    super.key,
  });

  final String title;
  final String message;
  final String semanticLabel;
  final double? value;
  final Widget? trailing;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Semantics(
        liveRegion: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: AppResponsiveWidth(
            maxWidth: 360,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(PageStyle.radiusCard),
                border: Border.fromBorderSide(
                  context.appColors.outlineBorder(),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppLinearProgressIndicator(value: value),
                    if (message.isNotEmpty && message != title) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(message, style: theme.textTheme.bodyMedium),
                    ],
                    if (hint != null && hint!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        hint!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
