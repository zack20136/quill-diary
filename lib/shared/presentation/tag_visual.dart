import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

AccentColors neutralTagColors(ColorScheme scheme) => (
  background: scheme.surfaceContainerHighest,
  foreground: scheme.onSurfaceVariant,
  accent: null,
);

AccentColors unsavedTagColors(BuildContext context) => accentColorsFor(
  Theme.of(context).colorScheme.error,
  context.appColors.sectionInset,
);

AccentColors resolveTagColors(
  String label,
  ColorScheme scheme,
  Map<String, int> customArgbByNormalized,
  AppColors colors,
) {
  final int? argb = customArgbByNormalized[normalizeText(label)];
  if (argb == null) {
    return neutralTagColors(scheme);
  }
  return accentColorsFor(Color(argb), colors.sectionInset);
}
