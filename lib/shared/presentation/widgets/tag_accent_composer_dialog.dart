import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/security/unlocked_vault_session.dart';
import '../../../l10n/l10n.dart';
import '../../../application/tag/tag_providers.dart';
import '../../../infrastructure/storage/storage_providers.dart';
import '../../utils/user_facing_error.dart';
import '../app_feedback.dart';
import '../../../app/app_colors.dart';
import '../tag_visual.dart';
import 'tag_accent_dialog_shell.dart';
import 'tag_accent_wheel_dialog.dart';
import 'tag_chip.dart';

/// 建立或編輯標籤名稱與強調色的對話框。
class TagAccentComposerDialog extends ConsumerStatefulWidget {
  const TagAccentComposerDialog({
    super.key,
    this.initialDisplayLabel,
    this.initialAccentArgb,
    this.initialAccentIsCustom,
    this.sessionForRename,
    this.titleText,
    this.descriptionText,
    this.primaryButtonLabel,
    this.onDelete,
  });

  final String? initialDisplayLabel;
  final int? initialAccentArgb;
  final bool? initialAccentIsCustom;
  final UnlockedVaultSession? sessionForRename;
  final String? titleText;
  final String? descriptionText;
  final String? primaryButtonLabel;
  final Future<void> Function()? onDelete;

  @override
  ConsumerState<TagAccentComposerDialog> createState() =>
      _TagAccentComposerDialogState();
}

class _TagAccentComposerDialogState
    extends ConsumerState<TagAccentComposerDialog> {
  late final TextEditingController _nameCtrl;
  late Color _accent;
  late bool _isCustom;
  bool _deleting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayLabel ?? '');
    if (widget.initialAccentArgb != null) {
      _accent = Color(widget.initialAccentArgb!);
      _isCustom =
          widget.initialAccentIsCustom ?? !tagAccentMatchesPreset(_accent);
    } else {
      _accent = kDefaultTagAccentPresets.first;
      _isCustom = false;
    }
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCustomColorPicker() async {
    if (_deleting || _saving) {
      return;
    }
    final Color? picked = await showTagAccentWheelDialog(
      context,
      initialColor: _accent,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() {
      _accent = picked;
      _isCustom = true;
    });
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final String name = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      showAppFeedbackSnackBar(context, l10n.tagNameRequiredMessage);
      return;
    }

    setState(() => _saving = true);
    try {
      final vaultRepository = ref.read(vaultRepositoryProvider);
      final String? originalLabel = widget.initialDisplayLabel;
      if (widget.sessionForRename != null && originalLabel != null) {
        await vaultRepository.renameTagCatalogItem(
          widget.sessionForRename!,
          fromLabel: originalLabel,
          toLabel: name,
          accentArgb: colorArgb32(_accent),
          accentIsCustom: _isCustom,
        );
      } else {
        await vaultRepository.upsertTagAccentArgb(
          name,
          colorArgb32(_accent),
          accentIsCustom: _isCustom,
        );
      }
      ref.invalidate(tagCatalogProvider);
      ref.invalidate(tagAccentArgbMapProvider);
      if (mounted) {
        Navigator.of(context).pop(name);
      }
    } catch (error) {
      if (mounted) {
        showAppFeedbackSnackBar(
          context,
          l10n.tagSaveFailure(userFacingErrorMessage(error, l10n: l10n)),
          tone: AppFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = context.l10n;
    if (widget.onDelete == null || _deleting) {
      return;
    }
    setState(() => _deleting = true);
    try {
      await widget.onDelete!();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        showAppFeedbackSnackBar(
          context,
          l10n.tagDeleteFailure(userFacingErrorMessage(error, l10n: l10n)),
          tone: AppFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Widget _previewPanel(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme cs,
    String previewText,
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
            TagChip.pair(
              label: previewText.isEmpty ? l10n.tagNameHint : previewText,
              pair: previewPair,
            ),
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
    final bool showBlurb =
        widget.descriptionText != null &&
        widget.descriptionText!.trim().isNotEmpty;
    final String previewText = _nameCtrl.text.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final AppColors appColors = context.appColors;
    final (Color previewBg, Color previewFg) = chipFillFromAccentColor(
      _accent,
      cs,
      appColors,
    );
    final bool canDelete = widget.onDelete != null;
    final bool busy = _deleting || _saving;
    final bool customSelected = _isCustom;

    return TagAccentDialogShell(
      icon: Icons.color_lens_rounded,
      title: widget.titleText ?? l10n.tagAddTitle,
      closeEnabled: !busy,
      onClose: () => Navigator.of(context).pop(),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              if (canDelete)
                TextButton.icon(
                  onPressed: busy ? null : _delete,
                  icon: _deleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.error,
                          ),
                        )
                      : Icon(Icons.delete_outline_rounded, color: cs.error),
                  label: Text(
                    l10n.tagDeleteLabel,
                    style: TextStyle(color: cs.error),
                  ),
                )
              else
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(),
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
                icon: _saving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onPrimary,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                onPressed: busy ? null : _save,
                label: Text(widget.primaryButtonLabel ?? l10n.tagSaveButton),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showBlurb) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              widget.descriptionText!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.42,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
          ] else ...<Widget>[const SizedBox(height: 22)],
          TextField(
            controller: _nameCtrl,
            enabled: !busy,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.tagNameHint,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              filled: true,
              fillColor: cs.surface.withValues(alpha: 0.95),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.tagDefaultColorLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          ClipRect(
            child: SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: kDefaultTagAccentPresets.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 12),
                itemBuilder: (BuildContext context, int index) {
                  final Color c = kDefaultTagAccentPresets[index];
                  final (Color chipBg, Color chipFg) = chipFillFromAccentColor(
                    c,
                    cs,
                    appColors,
                  );
                  final bool selected =
                      !_isCustom && colorArgb32(c) == colorArgb32(_accent);
                  final BorderSide? unselectedSide = tagChipBorderSide(
                    appColors,
                    cs,
                    chipBg,
                    chipFg,
                    width: 1.85,
                  );
                  return GestureDetector(
                    onTap: busy
                        ? null
                        : () => setState(() {
                            _accent = c;
                            _isCustom = false;
                          }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chipBg,
                        border: Border.all(
                          color: selected
                              ? cs.primary.withValues(alpha: 0.9)
                              : unselectedSide!.color,
                          width: selected ? 3.25 : 1.85,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : _openCustomColorPicker,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: BorderSide(
                color: customSelected
                    ? cs.primary.withValues(alpha: 0.9)
                    : cs.outlineVariant.withValues(alpha: 0.5),
                width: customSelected ? 2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.palette_outlined,
                  size: 20,
                  color: customSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.tagCustomColorLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: customSelected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: previewBg,
                    border: () {
                      if (customSelected) {
                        return Border.all(
                          color: cs.primary.withValues(alpha: 0.9),
                          width: 2.5,
                        );
                      }
                      final BorderSide? side = tagChipBorderSide(
                        appColors,
                        cs,
                        previewBg,
                        previewFg,
                        width: 1.5,
                      );
                      return side == null ? null : Border.fromBorderSide(side);
                    }(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _previewPanel(l10n, theme, cs, previewText, (previewBg, previewFg)),
        ],
      ),
    );
  }
}
