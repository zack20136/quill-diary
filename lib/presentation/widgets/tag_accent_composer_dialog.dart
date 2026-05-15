import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/editor/providers/editor_providers.dart';
import '../../shared/providers/core_providers.dart';
import '../tag_visual.dart';

class TagAccentComposerDialog extends ConsumerStatefulWidget {
  const TagAccentComposerDialog({
    super.key,
    this.initialDisplayLabel,
    this.initialAccentArgb,
    this.lockLabel = false,
    this.titleText = 'Create tag',
    this.descriptionText,
    this.primaryButtonLabel = 'Save tag',
  });

  final String? initialDisplayLabel;
  final int? initialAccentArgb;
  final bool lockLabel;
  final String titleText;
  final String? descriptionText;
  final String primaryButtonLabel;

  @override
  ConsumerState<TagAccentComposerDialog> createState() => _TagAccentComposerDialogState();
}

class _TagAccentComposerDialogState extends ConsumerState<TagAccentComposerDialog> {
  late final TextEditingController _nameCtrl;
  late Color _accent;
  late double _hueDeg;
  bool _fromHueSlider = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialDisplayLabel ?? '');
    if (widget.initialAccentArgb != null) {
      final Color parsed = Color(widget.initialAccentArgb!);
      _accent = parsed;
      _hueDeg = HSVColor.fromColor(parsed).hue;
    } else {
      _accent = kEditorTagAccentPresets.first;
      _hueDeg = HSVColor.fromColor(_accent).hue;
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

  Future<void> _save() async {
    final String name = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a tag name.')),
      );
      return;
    }
    try {
      await ref.read(indexDatabaseProvider).upsertTagAccentArgb(name, colorArgb32(_accent));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tag: $error')),
        );
      }
      return;
    }
    ref.invalidate(tagAccentArgbMapProvider);
    if (mounted) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool showBlurb =
        widget.descriptionText != null && widget.descriptionText!.trim().isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.lerp(cs.primary, cs.surface, 0.92)!,
                cs.surface,
              ],
            ),
            border: Border.all(color: cs.primary.withValues(alpha: 0.14)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.color_lens_rounded, color: cs.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.titleText,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
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
                ] else ...<Widget>[
                  const SizedBox(height: 22),
                ],
                if (widget.lockLabel) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.42),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.sell_rounded,
                              color: cs.primary.withValues(alpha: 0.9),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _nameCtrl.text.trim().isEmpty ? 'Untitled tag' : _nameCtrl.text.trim(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                ] else ...<Widget>[
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Tag name',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      filled: true,
                      fillColor: cs.surface.withValues(alpha: 0.95),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                ],
                Text(
                  'Preset colors',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: kEditorTagAccentPresets.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final Color c = kEditorTagAccentPresets[index];
                      final bool selected =
                          !_fromHueSlider && colorArgb32(c) == colorArgb32(_accent);
                      return GestureDetector(
                        onTap: () => setState(() {
                          _accent = c;
                          _hueDeg = HSVColor.fromColor(c).hue;
                          _fromHueSlider = false;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c,
                            border: Border.all(
                              color: selected
                                  ? cs.primary.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.9),
                              width: selected ? 3.25 : 1.85,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: c.withValues(alpha: 0.32),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Hue',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _hueDeg.clamp(0.0, 359.0),
                    min: 0,
                    max: 359,
                    divisions: 96,
                    onChanged: (double v) {
                      setState(() {
                        _hueDeg = v;
                        _accent = HSVColor.fromAHSV(1, v, 0.76, 0.9).toColor();
                        _fromHueSlider = true;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(cs.primary.withValues(alpha: 0.04), cs.surface),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: <Widget>[
                        Text(
                          'Preview',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.outline,
                          ),
                        ),
                        const Spacer(),
                        Builder(
                          builder: (BuildContext context) {
                            final String text =
                                _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
                            final (Color bgNow, Color fgNow) =
                                chipFillFromAccentColor(_accent, cs);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: bgNow.withValues(alpha: 0.95),
                                border: Border.all(
                                  color: fgNow.withValues(alpha: 0.33),
                                  width: 0.95,
                                ),
                              ),
                              child: Text(
                                text.isEmpty ? 'Tag name' : text,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: fgNow,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      onPressed: _save,
                      label: Text(widget.primaryButtonLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
