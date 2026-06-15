import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../../infrastructure/preferences/editor_typography_preferences.dart';
import '../../../infrastructure/preferences/personalization_preferences.dart';
import '../../../infrastructure/preferences/user_preferences.dart';
import '../../../shared/presentation/page_style.dart';
import '../personalization_copy.dart';
import '../providers/personalization_providers.dart';
import '../settings_copy.dart';
import 'settings_sections.dart';

/// 語言選擇（English 第一版 disabled）。
class PersonalizationLanguageSectionBody extends StatelessWidget {
  const PersonalizationLanguageSectionBody({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AppLocalePreference selected;
  final Future<void> Function(AppLocalePreference value) onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsSegmentedChoiceBar<AppLocalePreference>(
          choices: <SettingsSegmentChoice<AppLocalePreference>>[
            SettingsSegmentChoice<AppLocalePreference>(
              value: AppLocalePreference.zhTw,
              label: PersonalizationCopy.languageZhTwLabel,
              icon: Icons.translate_rounded,
            ),
            SettingsSegmentChoice<AppLocalePreference>(
              value: AppLocalePreference.en,
              label: PersonalizationCopy.languageEnLabel,
              icon: Icons.language_rounded,
              enabled: false,
            ),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
        const SizedBox(height: 10),
        const SettingsInfoBanner(
          icon: Icons.info_outline_rounded,
          message: PersonalizationCopy.languageComingSoonHint,
          tone: SettingsBannerTone.neutral,
        ),
      ],
    );
  }
}

/// 自動鎖定逾時分段選項。
class PersonalizationSessionTimeoutSectionBody extends StatelessWidget {
  const PersonalizationSessionTimeoutSectionBody({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final SessionBackgroundTimeoutMinutes selected;
  final Future<void> Function(SessionBackgroundTimeoutMinutes value) onSelected;

  static const List<SessionBackgroundTimeoutMinutes> _options =
      SessionBackgroundTimeoutMinutes.choices;

  @override
  Widget build(BuildContext context) {
    return SettingsSegmentedChoiceBar<SessionBackgroundTimeoutMinutes>(
      choices: _options
          .map(
            (SessionBackgroundTimeoutMinutes value) =>
                SettingsSegmentChoice<SessionBackgroundTimeoutMinutes>(
              value: value,
              label: PersonalizationCopy.sessionTimeoutSegmentLabel(value),
              icon: Icons.timer_outlined,
            ),
          )
          .toList(growable: false),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// 圖片品質分段選項。
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
              value: ImageCompressPreset.original,
              label: PersonalizationCopy.imageCompressOriginalLabel,
              icon: Icons.photo_size_select_large_outlined,
              flex: 2,
            ),
            SettingsSegmentChoice<ImageCompressPreset>(
              value: ImageCompressPreset.standard,
              label: PersonalizationCopy.imageCompressStandardLabel,
              icon: Icons.photo_size_select_small_outlined,
              flex: 2,
            ),
            SettingsSegmentChoice<ImageCompressPreset>(
              value: ImageCompressPreset.high,
              label: PersonalizationCopy.imageCompressHighLabel,
              icon: Icons.high_quality_outlined,
              flex: 2,
            ),
          ],
          selected: selected,
          onSelected: onSelected,
        ),
        const SizedBox(height: 12),
        Text(
          PersonalizationCopy.imageCompressDescription(selected),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// 主題顏色分段選項。
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
          label: PersonalizationCopy.appearanceSystemLabel,
          icon: Icons.brightness_auto_rounded,
          flex: 3,
        ),
        SettingsSegmentChoice<AppThemeModePreference>(
          value: AppThemeModePreference.light,
          label: PersonalizationCopy.appearanceLightLabel,
          icon: Icons.light_mode_outlined,
          flex: 2,
        ),
        SettingsSegmentChoice<AppThemeModePreference>(
          value: AppThemeModePreference.dark,
          label: PersonalizationCopy.appearanceDarkLabel,
          icon: Icons.dark_mode_outlined,
          flex: 2,
        ),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// 日記排版滑桿、預覽與還原預設。
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
    final ColorScheme cs = theme.colorScheme;
    final TextStyle titlePreviewStyle = typography.titleTextStyle(theme.textTheme);
    final TextStyle bodyPreviewStyle = typography.bodyTextStyle(theme.textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SettingsActionButton(
          label: PersonalizationCopy.typographyResetButton,
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
          label: PersonalizationCopy.titleFontSizeLabel,
          valueLabel: PersonalizationCopy.fontSizeValue(typography.titleFontSize),
          value: typography.titleFontSize,
          min: EditorTypographyPreferences.minTitleFontSize,
          max: EditorTypographyPreferences.maxTitleFontSize,
          divisions: ((EditorTypographyPreferences.maxTitleFontSize -
                      EditorTypographyPreferences.minTitleFontSize) /
                  0.5)
              .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(titleFontSize: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: PersonalizationCopy.titleLineHeightLabel,
          valueLabel: PersonalizationCopy.lineHeightValue(typography.titleLineHeight),
          value: typography.titleLineHeight,
          min: EditorTypographyPreferences.minTitleLineHeight,
          max: EditorTypographyPreferences.maxTitleLineHeight,
          divisions: ((EditorTypographyPreferences.maxTitleLineHeight -
                      EditorTypographyPreferences.minTitleLineHeight) /
                  0.05)
              .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(titleLineHeight: value));
          },
        ),
        const SizedBox(height: 12),
        _PreferenceSliderRow(
          label: PersonalizationCopy.bodyFontSizeLabel,
          valueLabel: PersonalizationCopy.fontSizeValue(typography.bodyFontSize),
          value: typography.bodyFontSize,
          min: EditorTypographyPreferences.minBodyFontSize,
          max: EditorTypographyPreferences.maxBodyFontSize,
          divisions: ((EditorTypographyPreferences.maxBodyFontSize -
                      EditorTypographyPreferences.minBodyFontSize) /
                  0.5)
              .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(bodyFontSize: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: PersonalizationCopy.bodyLineHeightLabel,
          valueLabel: PersonalizationCopy.lineHeightValue(typography.bodyLineHeight),
          value: typography.bodyLineHeight,
          min: EditorTypographyPreferences.minBodyLineHeight,
          max: EditorTypographyPreferences.maxBodyLineHeight,
          divisions: ((EditorTypographyPreferences.maxBodyLineHeight -
                      EditorTypographyPreferences.minBodyLineHeight) /
                  0.05)
              .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(bodyLineHeight: value));
          },
        ),
        const SizedBox(height: 8),
        _PreferenceSliderRow(
          label: PersonalizationCopy.bodyParagraphSpacingLabel,
          valueLabel: PersonalizationCopy.paragraphSpacingValue(typography.bodyParagraphSpacing),
          value: typography.bodyParagraphSpacing,
          min: EditorTypographyPreferences.minBodyParagraphSpacing,
          max: EditorTypographyPreferences.maxBodyParagraphSpacing,
          divisions: (EditorTypographyPreferences.maxBodyParagraphSpacing -
                  EditorTypographyPreferences.minBodyParagraphSpacing)
              .round(),
          onChanged: (double value) {
            onTypographyChanged(typography.copyWith(bodyParagraphSpacing: value));
          },
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PageStyle.previewPanelFill(cs),
            borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
            border: Border.fromBorderSide(PageStyle.outlineSide(cs)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ...List<Widget>.generate(
                  PersonalizationCopy.typographyPreviewTitleParagraphs.length,
                  (int index) {
                    final String paragraph =
                        PersonalizationCopy.typographyPreviewTitleParagraphs[index];
                    return Padding(
                      padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                      child: Text(
                        paragraph,
                        style: titlePreviewStyle,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ...List<Widget>.generate(
                  PersonalizationCopy.typographyPreviewBodyParagraphs.length,
                  (int index) {
                    final String paragraph =
                        PersonalizationCopy.typographyPreviewBodyParagraphs[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        top: index == 0 ? 0 : typography.bodyParagraphSpacing,
                      ),
                      child: Text(
                        paragraph,
                        style: bodyPreviewStyle,
                      ),
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
  final bool confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text(PersonalizationCopy.typographyResetConfirmTitle),
          content: const Text(PersonalizationCopy.typographyResetConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(SettingsCopy.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(PersonalizationCopy.typographyResetConfirmAction),
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
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(PersonalizationCopy.typographyResetSuccess)),
  );
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

/// 設定頁通用的分段 pill 選項列。
class SettingsSegmentChoice<T> {
  const SettingsSegmentChoice({
    required this.value,
    required this.label,
    required this.icon,
    this.flex = 2,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final int flex;
  final bool enabled;
}

class SettingsSegmentedChoiceBar<T> extends StatelessWidget {
  const SettingsSegmentedChoiceBar({
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.busy = false,
    super.key,
  });

  final List<SettingsSegmentChoice<T>> choices;
  final T selected;
  final bool busy;
  final Future<void> Function(T value) onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(PageStyle.radiusPanel),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < choices.length; index++) ...<Widget>[
            if (index > 0)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.35),
              ),
            Expanded(
              flex: choices[index].flex,
              child: _SettingsSegment<T>(
                label: choices[index].label,
                icon: choices[index].icon,
                selected: selected == choices[index].value,
                enabled: choices[index].enabled && !busy,
                compact: choices[index].label.length <= 3,
                onTap: choices[index].enabled && !busy
                    ? () => unawaited(onSelected(choices[index].value))
                    : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsSegment<T> extends StatelessWidget {
  const _SettingsSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected
              ? cs.onPrimaryContainer
              : enabled
                  ? cs.onSurfaceVariant
                  : cs.onSurfaceVariant.withValues(alpha: 0.45),
          fontSize: compact ? 13 : null,
        );
    return Material(
      color: selected
          ? cs.primaryContainer
          : cs.surfaceContainerHighest.withValues(alpha: enabled ? 0.55 : 0.35),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 10 : 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? cs.onPrimaryContainer
                    : enabled
                        ? cs.onSurfaceVariant
                        : cs.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: labelStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
