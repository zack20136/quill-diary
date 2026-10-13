import 'package:material_ui/material_ui.dart';

Widget localFileThumbnail(
  String? path, {
  double size = 56,
  BoxFit fit = BoxFit.cover,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(12),
  ),
}) {
  return SizedBox(width: size, height: size);
}
