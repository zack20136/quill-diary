import 'package:material_ui/material_ui.dart';

typedef AppColorPair = ({Color background, Color foreground});

const AppColorPair kAppLightSuccessColors = (
  background: Color(0xFFE3ECE6),
  foreground: Color(0xFF35614E),
);
const AppColorPair kAppDarkSuccessColors = (
  background: Color(0xFF20352F),
  foreground: Color(0xFFA6CDB7),
);
const Color kAppLightDiffAdded = Color(0xFF196C3B);
const Color kAppDarkDiffAdded = Color(0xFF7EE2A8);
const Color kAppLightDiffRemoved = Color(0xFFA83038);
const Color kAppDarkDiffRemoved = Color(0xFFFFA7A7);

/// 手調淺色色票：淺藍底、天藍強調色。
const ColorScheme kAppLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF3B6DB5),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD6E6FF),
  onPrimaryContainer: Color(0xFF001B3D),
  secondary: Color(0xFF4F5F7A),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDCE3F2),
  onSecondaryContainer: Color(0xFF0A1628),
  tertiary: Color(0xFF52779F),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFD8E8F8),
  onTertiaryContainer: Color(0xFF0A1E33),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF410002),
  surface: Color(0xFFF8FAFF),
  onSurface: Color(0xFF191C22),
  surfaceDim: Color(0xFFD8DEEA),
  surfaceBright: Color(0xFFF8FAFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF1F4FA),
  surfaceContainer: Color(0xFFEBEEF6),
  surfaceContainerHigh: Color(0xFFE5E9F0),
  surfaceContainerHighest: Color(0xFFDFE3EC),
  onSurfaceVariant: Color(0xFF424752),
  outline: Color(0xFF727886),
  outlineVariant: Color(0xFFC2C8D6),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF2E3138),
  onInverseSurface: Color(0xFFF0F2F7),
  inversePrimary: Color(0xFFA8C8FF),
  surfaceTint: Color(0xFF3B6DB5),
);

/// 暗色表面採同一組藍灰階，主要操作使用柔和藍色。
const ColorScheme kAppDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF8DB8E6),
  onPrimary: Color(0xFF13283F),
  primaryContainer: Color(0xFF293F59),
  onPrimaryContainer: Color(0xFFDAE9FA),
  secondary: Color(0xFFB8C7D5),
  onSecondary: Color(0xFF232D37),
  secondaryContainer: Color(0xFF323C46),
  onSecondaryContainer: Color(0xFFDFE8F0),
  tertiary: Color(0xFFA8C9DC),
  onTertiary: Color(0xFF1D2F39),
  tertiaryContainer: Color(0xFF2F424D),
  onTertiaryContainer: Color(0xFFD9EDF7),
  error: Color(0xFFFFB4AA),
  onError: Color(0xFF3D201D),
  errorContainer: Color(0xFF492C29),
  onErrorContainer: Color(0xFFFFDAD4),
  surface: Color(0xFF131923),
  onSurface: Color(0xFFE6EBF2),
  surfaceDim: Color(0xFF131923),
  surfaceBright: Color(0xFF374353),
  surfaceContainerLowest: Color(0xFF10151D),
  surfaceContainerLow: Color(0xFF1B2430),
  surfaceContainer: Color(0xFF212B39),
  surfaceContainerHigh: Color(0xFF283444),
  surfaceContainerHighest: Color(0xFF303D4F),
  onSurfaceVariant: Color(0xFFBCC8D8),
  outline: Color(0xFF8494A8),
  outlineVariant: Color(0xFF414F61),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFFE6EBF2),
  onInverseSurface: Color(0xFF2B3239),
  inversePrimary: Color(0xFF2D628A),
  surfaceTint: Color(0xFF8DB8E6),
);

/// 依亮度回傳固定手調 [ColorScheme]。
ColorScheme resolveAppColorScheme({required Brightness brightness}) {
  return brightness == Brightness.light
      ? kAppLightColorScheme
      : kAppDarkColorScheme;
}
