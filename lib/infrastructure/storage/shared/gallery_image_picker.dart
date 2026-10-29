import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

Future<List<XFile>> pickGalleryImages() async {
  final picker = ImagePicker();
  final files = <XFile>[];
  if (defaultTargetPlatform == TargetPlatform.android) {
    final lostData = await picker.retrieveLostData();
    files.addAll([
      if (lostData.file != null) lostData.file!,
      ...?lostData.files,
    ]);
  }

  try {
    files.addAll(await picker.pickMultiImage());
  } on Object {
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) files.add(image);
  }

  final seenPaths = <String>{};
  return files.where((file) => seenPaths.add(file.path)).toList();
}
