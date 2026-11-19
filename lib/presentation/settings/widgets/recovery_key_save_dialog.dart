import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/sensitive_clipboard.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<void> showRecoveryKeySaveDialog(
  BuildContext context, {
  required String recoveryKey,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) =>
        RecoveryKeySaveDialog(recoveryKey: recoveryKey),
  );
}

class RecoveryKeySaveDialog extends StatefulWidget {
  const RecoveryKeySaveDialog({
    required this.recoveryKey,
    this.requireSavedConfirmation = false,
    super.key,
  });

  final String recoveryKey;
  final bool requireSavedConfirmation;

  @override
  State<RecoveryKeySaveDialog> createState() => _RecoveryKeySaveDialogState();
}

class _RecoveryKeySaveDialogState extends State<RecoveryKeySaveDialog> {
  static const double _copyButtonClearance = 48;

  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppColors colors = context.appColors;
    final bool confirming = widget.requireSavedConfirmation;
    final TextStyle keyStyle =
        AppTypography.mono(
          (confirming
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.titleMedium) ??
              const TextStyle(),
        ).copyWith(
          fontWeight: confirming ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: confirming ? 1.15 : 1.1,
          height: 1.5,
          color: confirming ? colorScheme.onPrimaryContainer : null,
        );
    Widget keyText(String value) => SelectableText(
      value,
      style: keyStyle,
      textAlign: confirming ? TextAlign.center : null,
      contextMenuBuilder: SensitiveClipboard.contextMenu,
    );
    Future<bool> copyKey() =>
        SensitiveClipboard.copy(context, widget.recoveryKey, showSuccess: true);

    return AppDialogShell(
      title: confirming
          ? l10n.settingsRecoveryKeySaveNewDialogTitle
          : l10n.settingsRecoveryKeySaveDialogTitle,
      icon: confirming
          ? Icon(Icons.key_outlined, color: colorScheme.primary)
          : null,
      accent: confirming,
      content: AppScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              confirming
                  ? l10n.settingsRecoveryKeySaveBeforeUpdateHint
                  : l10n.settingsRecoveryKeySaveDialogHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (confirming) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.settingsRecoveryKeyKeepOldBackupKey,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Material(
              color: confirming
                  ? colorScheme.primaryContainer
                  : colors.sectionInset,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                side: colors.outlineBorder(),
              ),
              child: confirming
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final displayedKey = _wrapRecoveryKey(
                          widget.recoveryKey,
                          style: keyStyle,
                          maxLineWidth:
                              constraints.maxWidth - 2 * _copyButtonClearance,
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: _copyButtonClearance,
                                vertical: 24,
                              ),
                              child: keyText(displayedKey),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.content_copy_rounded,
                                  size: 20,
                                ),
                                tooltip: l10n.commonActionCopy,
                                color: colorScheme.onPrimaryContainer,
                                visualDensity: const VisualDensity(
                                  horizontal: -1,
                                  vertical: -1,
                                ),
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: copyKey,
                              ),
                            ),
                          ],
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: keyText(widget.recoveryKey),
                    ),
            ),
            if (confirming) ...[
              const SizedBox(height: 12),
              Semantics(
                checked: _saved,
                child: InkWell(
                  onTap: () => setState(() => _saved = !_saved),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            _saved
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            key: ValueKey<bool>(_saved),
                            size: 24,
                            color: _saved
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.settingsRecoveryKeySavedCheckbox,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        if (!confirming)
          TextButton(onPressed: copyKey, child: Text(l10n.commonActionCopy)),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            confirming ? l10n.commonActionCancel : l10n.commonActionClose,
          ),
        ),
        if (confirming)
          FilledButton(
            onPressed: _saved ? () => Navigator.of(context).pop(true) : null,
            child: Text(l10n.settingsRecoveryKeyStartUpdate),
          ),
      ],
    );
  }
}

String _wrapRecoveryKey(
  String recoveryKey, {
  required TextStyle style,
  required double maxLineWidth,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final groups = recoveryKey.split('-');
  if (groups.length == 1) return recoveryKey;

  List<String> linesFor(int groupsPerLine) {
    final lines = <String>[];
    for (var start = 0; start < groups.length; start += groupsPerLine) {
      final end = math.min(start + groupsPerLine, groups.length);
      final line = groups.getRange(start, end).join('-');
      lines.add(end < groups.length ? '$line-' : line);
    }
    return lines;
  }

  final painter = TextPainter(
    textDirection: textDirection,
    textScaler: textScaler,
    maxLines: 1,
  );
  bool fits(String line) {
    painter.text = TextSpan(text: line, style: style);
    painter.layout(maxWidth: maxLineWidth);
    return !painter.didExceedMaxLines;
  }

  try {
    for (
      var groupsPerLine = (groups.length + 1) ~/ 2;
      groupsPerLine > 1;
      groupsPerLine--
    ) {
      final lines = linesFor(groupsPerLine);
      if (!maxLineWidth.isFinite || (maxLineWidth > 0 && lines.every(fits))) {
        return lines.join('\n');
      }
    }
    return linesFor(1).join('\n');
  } finally {
    painter.dispose();
  }
}
