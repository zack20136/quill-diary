import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_colors.dart';
import '../app_feedback.dart';
import '../accent_visual.dart';
import 'accent_dialog_shell.dart';
import 'tag_chip.dart';

Future<Color?> showAccentColorWheelDialog(
  BuildContext context, {
  required Color initialColor,
  required String title,
  required String previewLabel,
  required String previewText,
  required String copiedMessage,
  required String cancelLabel,
  required String saveLabel,
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.appColors.scrim,
    builder: (BuildContext dialogContext) {
      return AccentColorWheelDialog(
        initialColor: initialColor,
        title: title,
        previewLabel: previewLabel,
        previewText: previewText,
        copiedMessage: copiedMessage,
        cancelLabel: cancelLabel,
        saveLabel: saveLabel,
      );
    },
  );
}

class AccentColorWheelDialog extends StatefulWidget {
  const AccentColorWheelDialog({
    super.key,
    required this.initialColor,
    required this.title,
    required this.previewLabel,
    required this.previewText,
    required this.copiedMessage,
    required this.cancelLabel,
    required this.saveLabel,
  });

  final Color initialColor;
  final String title;
  final String previewLabel;
  final String previewText;
  final String copiedMessage;
  final String cancelLabel;
  final String saveLabel;

  @override
  State<AccentColorWheelDialog> createState() =>
      _AccentColorWheelDialogState();
}

class _AccentColorWheelDialogState extends State<AccentColorWheelDialog> {
  late Color _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialColor.withValues(alpha: 1.0);
  }

  Future<void> _copyColorCode() async {
    await Clipboard.setData(ClipboardData(text: '0x${_picked.hexAlpha}'));
    if (!mounted) {
      return;
    }
    showAppFeedbackToast(
      context,
      widget.copiedMessage,
      tone: AppFeedbackTone.success,
    );
  }

  Widget _previewPanel(
    ThemeData theme,
    ColorScheme cs,
    (Color, Color) previewPair,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(cs.primary.withValues(alpha: 0.04), cs.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: <Widget>[
            Text(
              widget.previewLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
            const Spacer(),
            TagChip.pair(label: widget.previewText, pair: previewPair),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors appColors = context.appColors;
    final (Color previewBg, Color previewFg) = accentColorPair(
      _picked,
      appColors.sectionInset,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: AccentDialogShell(
        icon: Icons.palette_outlined,
        title: widget.title,
        onClose: () => Navigator.of(context).pop(),
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    widget.cancelLabel,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(_picked),
                  label: Text(widget.saveLabel),
                ),
              ],
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: ColorWheelPicker(
                  color: _picked,
                  wheelWidth: 14,
                  onChanged: (Color color) {
                    setState(() => _picked = color.withValues(alpha: 1.0));
                  },
                  onWheel: (_) {},
                ),
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '0x${_picked.hexAlpha}',
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).copyButtonLabel,
                      visualDensity: VisualDensity.compact,
                      onPressed: _copyColorCode,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _previewPanel(theme, cs, (previewBg, previewFg)),
          ],
        ),
      ),
    );
  }
}
