import 'package:flutter/material.dart';

import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

class DiaryEntryDateTime extends StatelessWidget {
  const DiaryEntryDateTime({
    super.key,
    required this.date,
    required this.at,
    this.compact = false,
    this.alignment = CrossAxisAlignment.end,
    this.textAlign = TextAlign.right,
    this.maxWidth,
  });

  final DateOnly date;
  final DateTime at;
  final bool compact;
  final CrossAxisAlignment alignment;
  final TextAlign textAlign;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? style = (compact
            ? theme.textTheme.labelSmall
            : theme.textTheme.labelMedium)
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final Widget content = Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          DisplayFormat.formatDateOnly(context.l10n, date),
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        Text(
          DisplayFormat.formatWeekdayAndTime(context.l10n, date, at),
          style: style,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ],
    );
    return maxWidth == null
        ? content
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: content,
          );
  }
}
