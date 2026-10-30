import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:quill_diary/shared/presentation/accent_visual.dart';
import 'package:quill_diary/shared/presentation/app_colors.dart';

(Color, Color) tagNeutralAccentPair(ColorScheme scheme) =>
    (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);

(Color, Color) tagUnsavedPair(AppColors colors) =>
    accentColorPair(colors.tagUnsavedAccent, colors.sectionInset);

(Color, Color) tagResolvedAccentPair(
  String label,
  ColorScheme scheme,
  Map<String, int> customArgbByNormalized,
  AppColors colors,
) {
  final int? argb = customArgbByNormalized[normalizeText(label)];
  if (argb == null) {
    return tagNeutralAccentPair(scheme);
  }
  return accentColorPair(Color(argb), colors.sectionInset);
}
