import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../app/app_colors.dart';
import '../app_feedback.dart';
import '../tag_visual.dart';
import 'tag_accent_dialog_shell.dart';
import 'tag_chip.dart';

Future<Color?> showTagAccentWheelDialog(
  BuildContext context, {
  required Color initialColor,
}) {
  return showDialog<Color>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.appColors.scrim,
    builder: (BuildContext dialogContext) {
      return TagAccentWheelDialog(initialColor: initialColor);
    },
  );
}

class TagAccentWheelDialog extends StatefulWidget {
  const TagAccentWheelDialog({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<TagAccentWheelDialog> createState() => _TagAccentWheelDialogState();
}

class _TagAccentWheelDialogState extends State<TagAccentWheelDialog> {
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
    showAppFeedbackSnackBar(
      context,
      context.l10n.tagColorCodeCopiedMessage,
      tone: AppFeedbackTone.success,
    );
  }

  Widget _previewPanel(
    AppLocalizations l10n,
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
              l10n.tagPreviewLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.outline,
              ),
            ),
            const Spacer(),
            TagChip.pair(label: l10n.tagUnnamedPreview, pair: previewPair),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AppColors appColors = context.appColors;
    final (Color previewBg, Color previewFg) = chipFillFromAccentColor(
      _picked,
      cs,
      appColors,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      child: TagAccentDialogShell(
        icon: Icons.palette_outlined,
        title: l10n.tagCustomColorDialogTitle,
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
                    l10n.commonActionCancel,
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
                  label: Text(l10n.tagSaveButton),
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
            _previewPanel(l10n, theme, cs, (previewBg, previewFg)),
          ],
        ),
      ),
    );
  }
}
