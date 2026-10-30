import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/shared/presentation/widgets/local_file_thumbnail_io.dart'
    if (dart.library.html) 'package:quill_diary/shared/presentation/widgets/local_file_thumbnail_stub.dart'
    as impl;

Widget localFileThumbnail(
  String? path, {
  double size = 56,
  BoxFit fit = BoxFit.cover,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(12),
  ),
}) {
  return impl.localFileThumbnail(
    path,
    size: size,
    fit: fit,
    borderRadius: borderRadius,
  );
}
