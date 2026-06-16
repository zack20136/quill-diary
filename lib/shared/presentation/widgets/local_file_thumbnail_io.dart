import 'dart:io';

import 'package:flutter/material.dart';

Widget localFileThumbnail(
  String? path, {
  double size = 56,
  BoxFit fit = BoxFit.cover,
  BorderRadiusGeometry borderRadius = const BorderRadius.all(
    Radius.circular(12),
  ),
}) {
  if (path == null || path.isEmpty) {
    return SizedBox(width: size, height: size);
  }
  final File file = File(path);
  if (!file.existsSync()) {
    return SizedBox(width: size, height: size);
  }
  return SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        file,
        fit: fit,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: size.round().clamp(64, 512),
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                SizedBox(width: size, height: size),
      ),
    ),
  );
}
