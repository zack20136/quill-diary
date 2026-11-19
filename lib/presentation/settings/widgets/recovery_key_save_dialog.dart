import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/application/errors/user_facing_error.dart';
import 'package:quill_diary/domain/recovery/recovery_key.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';
import 'package:quill_diary/shared/presentation/app_scrollbar.dart';
import 'package:quill_diary/shared/presentation/app_typography.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/sensitive_clipboard.dart';
import 'package:quill_diary/shared/presentation/widgets/app_dialog_shell.dart';

Future<bool> showRecoveryKeyCreationDialog(
  BuildContext context, {
  required Future<String> Function() createRecoveryKey,
  bool offerUnlockSetup = false,
}) async {
  if (ModalRoute.of(context)?.isCurrent != true) {
    return false;
  }
  final bool? configureUnlock = await showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecoveryKeySaveDialog._create(
      createRecoveryKey: createRecoveryKey,
      offerUnlockSetup: offerUnlockSetup,
    ),
  );
  return configureUnlock == true;
}

class RecoveryKeySaveDialog extends StatefulWidget {
  const RecoveryKeySaveDialog.confirmUpdate({
    required String this.recoveryKey,
    super.key,
  }) : createRecoveryKey = null,
       offerUnlockSetup = false;

  const RecoveryKeySaveDialog._create({
    required Future<String> Function() this.createRecoveryKey,
    required this.offerUnlockSetup,
  }) : recoveryKey = null;

  final String? recoveryKey;
  final Future<String> Function()? createRecoveryKey;
  final bool offerUnlockSetup;

  @override
  State<RecoveryKeySaveDialog> createState() => _RecoveryKeySaveDialogState();
}

class _RecoveryKeySaveDialogState extends State<RecoveryKeySaveDialog> {
  static const double _copyButtonClearance = 48;
  static final String _keyPlaceholder = RecoveryKey.format(
    '0' * RecoveryKey.symbolCount,
  );
  late final Future<String>? _creation = widget.createRecoveryKey == null
      ? null
      : Future<String>.sync(widget.createRecoveryKey!);

  bool _saved = false;

  @override
  Widget build(BuildContext context) {
    final Future<String>? creation = _creation;
    if (creation == null) {
      return _buildDialog(context, widget.recoveryKey);
    }
    return FutureBuilder<String>(
      future: creation,
      builder: (context, snapshot) {
        final Object? error = snapshot.error;
        return PopScope(
          canPop: error != null,
          child: error == null
              ? _buildDialog(context, snapshot.data)
              : AppDialogShell(
                  title: context.l10n.settingsRecoveryKeyCreateButton,
                  content: Text(
                    userFacingErrorMessage(error, l10n: context.l10n),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildDialog(BuildContext context, String? recoveryKey) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool confirming = widget.recoveryKey != null;
    final bool creating = recoveryKey == null;
    final TextStyle keyStyle =
        AppTypography.mono(theme.textTheme.titleLarge ?? const TextStyle())
            .copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.15,
              height: 1.5,
              color: colorScheme.onPrimaryContainer,
            );

    return AppDialogShell(
      title: confirming
          ? l10n.settingsRecoveryKeySaveNewDialogTitle
          : l10n.settingsRecoveryKeySaveDialogTitle,
      icon: confirming
          ? Icon(Icons.key_outlined, color: colorScheme.primary)
          : null,
      accent: confirming,
      closeEnabled: !creating,
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
              color: colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
                side: context.appColors.outlineBorder(),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final displayedKey = _wrapRecoveryKey(
                    recoveryKey ?? _keyPlaceholder,
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
                        child: Visibility(
                          visible: !creating,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: SelectableText(
                            displayedKey,
                            style: keyStyle,
                            textAlign: TextAlign.center,
                            contextMenuBuilder: SensitiveClipboard.contextMenu,
                          ),
                        ),
                      ),
                      if (recoveryKey == null)
                        SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            semanticsLabel:
                                l10n.settingsRecoveryKeyCreateButton,
                          ),
                        )
                      else
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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => SensitiveClipboard.copy(
                              context,
                              recoveryKey,
                              showSuccess: true,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
        TextButton(
          onPressed: creating ? null : () => Navigator.of(context).pop(),
          child: Text(
            confirming ? l10n.commonActionCancel : l10n.commonActionClose,
          ),
        ),
        if (confirming)
          FilledButton(
            onPressed: _saved ? () => Navigator.of(context).pop(true) : null,
            child: Text(l10n.settingsRecoveryKeyStartUpdate),
          )
        else if (widget.offerUnlockSetup)
          FilledButton(
            onPressed: creating ? null : () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsUnlockMethodConfigureButton),
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
