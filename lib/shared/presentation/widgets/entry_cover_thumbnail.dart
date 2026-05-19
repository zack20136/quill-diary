import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/editor/providers/editor_providers.dart';

/// Decrypts and renders an image preview for an encrypted vault asset path.
class EntryCoverThumbnail extends ConsumerWidget {
  const EntryCoverThumbnail({
    super.key,
    required this.encryptedFilePath,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.placeholderIcon = Icons.image_outlined,
  });

  final String? encryptedFilePath;
  final double size;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String? path = encryptedFilePath?.trim();
    if (path == null || path.isEmpty) {
      return _placeholder(theme);
    }

    final AsyncValue<Uint8List?> async = ref.watch(entryCoverPreviewBytesProvider(path));
    return async.when(
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return _placeholder(theme);
        }
        final double dpr = MediaQuery.of(context).devicePixelRatio;
        final int cacheDim = (size * dpr).round().clamp(64, 512);
        return ClipRRect(
          borderRadius: borderRadius,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: cacheDim,
            cacheHeight: cacheDim,
            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                _placeholder(theme),
          ),
        );
      },
      loading: () => _loading(theme),
      error: (Object error, StackTrace stackTrace) => _placeholder(theme),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        placeholderIcon,
        color: theme.colorScheme.onSurfaceVariant,
        size: size * 0.4,
      ),
    );
  }

  Widget _loading(ThemeData theme) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: SizedBox(
        width: size * 0.28,
        height: size * 0.28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
