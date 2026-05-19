import 'dart:io';

import 'package:flutter/material.dart';

Widget localFileThumbnail(
  String? path, {
  double size = 56,
  BoxFit fit = BoxFit.cover,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(12)),
}) {
  if (path == null || path.isEmpty) {
    return SizedBox(width: size, height: size);
  }
  final File file = File(path);
  if (!file.existsSync()) {
    return SizedBox(width: size, height: size);
  }
  return ClipRRect(
    borderRadius: borderRadius,
    child: Image.file(
      file,
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
          SizedBox(width: size, height: size),
    ),
  );
}
