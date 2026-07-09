import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import 'package:quill_diary/infrastructure/preferences/editor_typography_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/personalization_preferences.dart';
import 'package:quill_diary/infrastructure/preferences/user_preferences.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/app/app_colors.dart';
import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/application/settings/personalization_providers.dart';
import 'settings_sections.dart';

class PersonalizationLanguageSectionBody extends StatelessWidget {
  const PersonalizationLanguageSectionBody({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AppLanguage selected;
  final Future<void> Function(AppLanguage value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsSegmentedChoiceBar<AppLanguage>(
          choices: <SettingsSegmentChoice<AppLanguage>>[
            SettingsSegmentChoice<AppLanguage>(
              value: AppLanguage.zh,
              label: context.l10n.languageNameZh,
              icon: Icons.translate_rounded,
            ),
            SettingsSegmentChoice<AppLanguage>(
              value: AppLanguage.en,
              label: context.l10n.languageNameEn,
              icon: Icons.language_rounded,
            ),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class PersonalizationSessionTimeoutSectionBody extends StatelessWidget {
  const PersonalizationSessionTimeoutSectionBody({
    required this.selected,
    required this.onSelected,
    this.enabled = true,
    this.lockedMessage,
    super.key,
  });

  final SessionBackgroundTimeoutMinutes selected;
  final Future<void> Function(SessionBackgroundTimeoutMinutes value) onSelected;
  final bool enabled;
  final String? lockedMessage;

  static const List<SessionBackgroundTimeoutMinutes> _options =
      SessionBackgroundTimeoutMinutes.choices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child:
                  SettingsSegmentedChoiceBar<SessionBackgroundTimeoutMinutes>(
                    choices: _options
                        .map(
                          (SessionBackgroundTimeoutMinutes value) =>
                              SettingsSegmentChoice<
                                SessionBackgroundTimeoutMinutes
                              >(
                                value: value,
                                label: '${value.minutes}',
                                icon: null,
                                flex: 1,
                                enabled: enabled,
                              ),
                        )
                        .toList(growable: false),
                    selected: selected,
                    onSelected: onSelected,
                  ),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.personalizationSessionTimeoutUnitLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        if (!enabled && lockedMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          AppFeedbackBanner(
            icon: Icons.lock_outline_rounded,
            message: lockedMessage!,
            tone: AppFeedbackTone.warning,
          ),
        ],
      ],
    );
  }
}

class PersonalizationImageCompressSectionBody extends StatelessWidget {
  const PersonalizationImageCompressSectionBody({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final ImageCompressPreset selected;
  final Future<void> Function(ImageCompressPreset value) onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsSegmentedChoiceBar<ImageCompressPreset>(
          choices: <SettingsSegmentChoice<ImageCompressPreset>>[
            SettingsSegmentChoice<ImageCompressPreset>(
              value: ImageCompressPreset.standard,
              label: context.l10n.personalizationImageCompressStandardLabel,
              icon: Icons.photo_size_select_small_outlined,
              flex: 2,
            ),
            SettingsSegmentChoice<ImageCompressPreset>(
              value: ImageCompressPreset.high,
              label: context.l10n.personalizationImageCompressHighLabel,
              icon: Icons.high_quality_outlined,
              flex: 2,
            ),
            SettingsSegmentChoice<ImageCompressPreset>(
              value: ImageCompressPreset.original,
              label: context.l10n.personalizationImageCompressOriginalLabel,
              icon: Icons.photo_size_select_large_outlined,
              flex: 2,
            ),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        Text(
          _imageCompressDescription(context.l10n, selected),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class PersonalizationAppearanceSectionBody extends StatelessWidget {
  const PersonalizationAppearanceSectionBody({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AppThemeModePreference selected;
  final Future<void> Function(AppThemeModePreference value) onSelected;

  @override
  Widget build(BuildContext context) {
    return SettingsSegmentedChoiceBar<AppThemeModePreference>(
      choices: <SettingsSegmentChoice<AppThemeModePreference>>[
        SettingsSegmentChoice<AppThemeModePreference>(
          value: AppThemeModePreference.system,
          label: context.l10n.personalizationAppearanceSystemLabel,
          icon: Icons.brightness_auto_rounded,
          flex: 3,
        ),
        SettingsSegmentChoice<AppThemeModePreference>(
          value: AppThemeModePreference.light,
          label: context.l10n.personalizationAppearanceLightLabel,
          icon: Icons.light_mode_outlined,
          flex: 2,
        ),
        SettingsSegmentChoice<AppThemeModePreference>(
          value: AppThemeModePreference.dark,
          label: context.l10n.personalizationAppearanceDarkLabel,
          icon: Icons.dark_mode_outlined,
          flex: 2,
        ),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class PersonalizationTypographySectionBody extends StatelessWidget {
  const PersonalizationTypographySectionBody({
    required this.typography,
    required this.onTypographyChanged,
    required this.controller,
    super.key,
  });

  final EditorTypographyPreferences typography;
  final ValueChanged<EditorTypographyPreferences> onTypographyChanged;
  final PersonalizationPreferencesController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle titlePreviewStyle = typography.titleTextStyle(
      theme.textTheme,
    );
    final TextStyle bodyPreviewStyle = typography.bodyTextStyle(
      theme.textTheme,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsActionButton(
          label: context.l10n.personalizationTypographyResetButton,
          icon: Icons.restore_rounded,
          fullWidth: true,
          onPressed: typography.isAtDefaults
              ? null
              : () => unawaited(
                  confirmAndResetTypography(
                    context: context,
                    controller: controller,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        _PreferenceSliderRow(
          label: context.l10n.personalizationTitleFontSizeLabel,
          valueLabel: _fontSizeValue(context.l10n, typography.titleFontSize),
          value: typography.titleFontSize,
          min: EditorTypographyPreferences.minTitleFontSize,
          max: EditorTypographyPreferences.maxTitleFontSize,
          divisions:
              ((EditorTypographyPreferences.maxTitleFontSize -
                          EditorTypographyPreferences.minTitleFontSize) /
                      0.5)
                  .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(titleFontSize: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: context.l10n.personalizationTitleLineHeightLabel,
          valueLabel: _lineHeightValue(
            context.l10n,
            typography.titleLineHeight,
          ),
          value: typography.titleLineHeight,
          min: EditorTypographyPreferences.minTitleLineHeight,
          max: EditorTypographyPreferences.maxTitleLineHeight,
          divisions:
              ((EditorTypographyPreferences.maxTitleLineHeight -
                          EditorTypographyPreferences.minTitleLineHeight) /
                      0.05)
                  .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(titleLineHeight: value));
          },
        ),
        const SizedBox(height: 12),
        _PreferenceSliderRow(
          label: context.l10n.personalizationBodyFontSizeLabel,
          valueLabel: _fontSizeValue(context.l10n, typography.bodyFontSize),
          value: typography.bodyFontSize,
          min: EditorTypographyPreferences.minBodyFontSize,
          max: EditorTypographyPreferences.maxBodyFontSize,
          divisions:
              ((EditorTypographyPreferences.maxBodyFontSize -
                          EditorTypographyPreferences.minBodyFontSize) /
                      0.5)
                  .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(bodyFontSize: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: context.l10n.personalizationBodyLineHeightLabel,
          valueLabel: _lineHeightValue(context.l10n, typography.bodyLineHeight),
          value: typography.bodyLineHeight,
          min: EditorTypographyPreferences.minBodyLineHeight,
          max: EditorTypographyPreferences.maxBodyLineHeight,
          divisions:
              ((EditorTypographyPreferences.maxBodyLineHeight -
                          EditorTypographyPreferences.minBodyLineHeight) /
                      0.05)
                  .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(bodyLineHeight: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: context.l10n.personalizationBodyParagraphSpacingLabel,
          valueLabel: _paragraphSpacingValue(
            context.l10n,
            typography.bodyParagraphSpacing,
          ),
          value: typography.bodyParagraphSpacing,
          min: EditorTypographyPreferences.minBodyParagraphSpacing,
          max: EditorTypographyPreferences.maxBodyParagraphSpacing,
          divisions:
              (EditorTypographyPreferences.maxBodyParagraphSpacing -
                      EditorTypographyPreferences.minBodyParagraphSpacing)
                  .round(),
          onChanged: (double value) {
            onTypographyChanged(
              typography.copyWith(bodyParagraphSpacing: value),
            );
          },
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.previewPanel,
            borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
            border: Border.fromBorderSide(context.appColors.outlineBorder()),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...List<Widget>.generate(
                  _typographyPreviewTitleParagraphs(context.l10n).length,
                  (int index) {
                    final String paragraph = _typographyPreviewTitleParagraphs(
                      context.l10n,
                    )[index];
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                      child: Text(paragraph, style: titlePreviewStyle),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(
                  _typographyPreviewBodyParagraphs(context.l10n).length,
                  (int index) {
                    final String paragraph = _typographyPreviewBodyParagraphs(
                      context.l10n,
                    )[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : typography.bodyParagraphSpacing,
                      ),
                      child: Text(paragraph, style: bodyPreviewStyle),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> confirmAndResetTypography({
  required BuildContext context,
  required PersonalizationPreferencesController controller,
}) async {
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: Text(
            dialogContext.l10n.personalizationTypographyResetConfirmTitle,
          ),
          content: Text(
            dialogContext.l10n.personalizationTypographyResetConfirmBody,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.commonActionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                dialogContext.l10n.personalizationTypographyResetConfirmAction,
              ),
            ),
          ],
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    return;
  }

  await controller.resetTypographyToDefaults();

  if (!context.mounted) {
    return;
  }
  showAppFeedbackSnackBar(
    context,
    context.l10n.personalizationTypographyResetSuccess,
    tone: AppFeedbackTone.success,
  );
}

String _imageCompressDescription(
  AppLocalizations l10n,
  ImageCompressPreset preset,
) {
  return switch (preset) {
    ImageCompressPreset.original =>
      l10n.personalizationImageCompressOriginalDescription,
    ImageCompressPreset.standard =>
      l10n.personalizationImageCompressStandardDescription,
    ImageCompressPreset.high =>
      l10n.personalizationImageCompressHighDescription,
  };
}

String _fontSizeValue(AppLocalizations l10n, double size) {
  return l10n.personalizationFontSizeValue(_formatNumber(size));
}

String _lineHeightValue(AppLocalizations l10n, double height) {
  return l10n.personalizationLineHeightValue(_formatNumber(height));
}

String _paragraphSpacingValue(AppLocalizations l10n, double spacing) {
  return l10n.personalizationParagraphSpacingValue(_formatNumber(spacing));
}

List<String> _typographyPreviewTitleParagraphs(AppLocalizations l10n) {
  return <String>[l10n.personalizationTypographyPreviewTitleParagraph1];
}

List<String> _typographyPreviewBodyParagraphs(AppLocalizations l10n) {
  return <String>[
    l10n.personalizationTypographyPreviewBodyParagraph1,
    l10n.personalizationTypographyPreviewBodyParagraph2,
  ];
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(2)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

class _PreferenceSliderRow extends StatelessWidget {
  const _PreferenceSliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  height: 1.45,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
