import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_diary/application/editor/editor_flow_controller.dart';
import 'package:quill_diary/application/editor/editor_gallery_export.dart';
import 'package:quill_diary/l10n/l10n.dart';
import 'package:quill_diary/shared/presentation/app_feedback.dart';
import 'package:quill_diary/shared/presentation/display_format.dart';

void showGalleryDownloadSnackBar(
  BuildContext context,
  String message, {
  AppFeedbackTone tone = AppFeedbackTone.success,
}) {
  showAppFeedbackToast(context, message, tone: tone);
}

Future<void> downloadGalleryImage({
  required WidgetRef ref,
  required BuildContext context,
  required GalleryImageItem item,
}) async {
  final Uint8List? bytes = await ref
      .read(editorFlowControllerProvider)
      .loadGalleryImageBytes(item);
  if (!context.mounted) {
    return;
  }
  if (bytes == null || bytes.isEmpty) {
    showGalleryDownloadSnackBar(
      context,
      context.l10n.editorGalleryDownloadFailed,
      tone: AppFeedbackTone.error,
    );
    return;
  }
  final String? savedName = await saveGalleryImageToPictures(
    bytes: bytes,
    fileName: item.fileName,
    mimeType: item.mimeType,
  );
  if (!context.mounted) {
    return;
  }
  if (savedName == null) {
    showGalleryDownloadSnackBar(
      context,
      context.l10n.editorGalleryDownloadFailed,
      tone: AppFeedbackTone.error,
    );
    return;
  }
  showGalleryDownloadSnackBar(
    context,
    context.l10n.editorGalleryDownloadSuccess(
      DisplayFormat.formatPicturesDisplayPath(savedName),
    ),
  );
}
