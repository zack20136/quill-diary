import 'package:flutter/material.dart';

import '../../../domain/shared/value_objects.dart';
import '../../../l10n/l10n.dart';
import '../display_format.dart';

/// 日記條目的日期與時間欄，供首頁列表與編輯頁共用。
class EntryDateTimeColumn extends StatelessWidget {
  const EntryDateTimeColumn({
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
    final TextStyle? base = compact
        ? theme.textTheme.labelSmall
        : theme.textTheme.labelMedium;
    final TextStyle? muted = base?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final Widget column = Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          DisplayFormat.formatDateOnly(context.l10n, date),
          style: muted,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
        Text(
          DisplayFormat.formatWeekdayAndTime(context.l10n, date, at),
          style: muted,
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ],
    );

    if (maxWidth == null) {
      return column;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: column,
    );
  }
}
