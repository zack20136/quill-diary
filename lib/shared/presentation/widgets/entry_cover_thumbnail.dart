import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
    final String? path = encryptedFilePath?.trim();
    if (path == null || path.isEmpty) {
      return EntryCoverThumbnailPlaceholder(
        size: size,
        borderRadius: borderRadius,
        icon: placeholderIcon,
      );
    }

    final AsyncValue<Uint8List?> async = ref.watch(entryCoverPreviewBytesProvider(path));
    return async.when(
      data: (Uint8List? bytes) {
        if (bytes == null || bytes.isEmpty) {
          return EntryCoverThumbnailPlaceholder(
            size: size,
            borderRadius: borderRadius,
            icon: placeholderIcon,
          );
        }
        final double dpr = MediaQuery.of(context).devicePixelRatio;
        final int cacheDim = (size * dpr).round().clamp(64, 512);
        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              width: double.infinity,
              height: double.infinity,
              gaplessPlayback: true,
              cacheWidth: cacheDim,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) =>
                  EntryCoverThumbnailPlaceholder(
                size: size,
                borderRadius: borderRadius,
                icon: placeholderIcon,
              ),
            ),
          ),
        );
      },
      loading: () => EntryCoverThumbnailLoading(
        size: size,
        borderRadius: borderRadius,
      ),
      error: (Object error, StackTrace stackTrace) => EntryCoverThumbnailPlaceholder(
        size: size,
        borderRadius: borderRadius,
        icon: placeholderIcon,
      ),
    );
  }
}

/// Defers thumbnail decryption until visible or after a prefetch stagger delay.
class LazyEntryCoverThumbnail extends ConsumerStatefulWidget {
  const LazyEntryCoverThumbnail({
    super.key,
    required this.encryptedFilePath,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.placeholderIcon = Icons.image_outlined,
    this.staggerIndex = 0,
  });

  final String? encryptedFilePath;
  final double size;
  final BorderRadius borderRadius;
  final IconData placeholderIcon;
  final int staggerIndex;

  @override
  ConsumerState<LazyEntryCoverThumbnail> createState() => _LazyEntryCoverThumbnailState();
}

class _LazyEntryCoverThumbnailState extends ConsumerState<LazyEntryCoverThumbnail> {
  static const Duration _prefetchBaseDelay = Duration(milliseconds: 50);
  static const Duration _prefetchStaggerStep = Duration(milliseconds: 60);

  bool _shouldLoad = false;
  Timer? _prefetchTimer;

  @override
  void initState() {
    super.initState();
    final Duration delay =
        _prefetchBaseDelay + _prefetchStaggerStep * widget.staggerIndex;
    _prefetchTimer = Timer(delay, () {
      if (mounted && !_shouldLoad) {
        setState(() => _shouldLoad = true);
      }
    });
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (info.visibleFraction > 0 && !_shouldLoad) {
      _prefetchTimer?.cancel();
      setState(() => _shouldLoad = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String pathKey = widget.encryptedFilePath?.trim() ?? 'empty';
    return VisibilityDetector(
      key: ValueKey<String>('lazy-cover-$pathKey-${widget.staggerIndex}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _shouldLoad
          ? EntryCoverThumbnail(
              encryptedFilePath: widget.encryptedFilePath,
              size: widget.size,
              borderRadius: widget.borderRadius,
              placeholderIcon: widget.placeholderIcon,
            )
          : EntryCoverThumbnailPlaceholder(
              size: widget.size,
              borderRadius: widget.borderRadius,
              icon: widget.placeholderIcon,
            ),
    );
  }
}

class EntryCoverThumbnailPlaceholder extends StatelessWidget {
  const EntryCoverThumbnailPlaceholder({
    super.key,
    required this.size,
    required this.borderRadius,
    this.icon = Icons.image_outlined,
  });

  final double size;
  final BorderRadius borderRadius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.onSurfaceVariant,
        size: size * 0.4,
      ),
    );
  }
}

class EntryCoverThumbnailLoading extends StatelessWidget {
  const EntryCoverThumbnailLoading({
    super.key,
    required this.size,
    required this.borderRadius,
  });

  final double size;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
