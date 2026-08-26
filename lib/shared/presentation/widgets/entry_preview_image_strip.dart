import 'package:flutter/material.dart';

import 'package:quill_diary/shared/presentation/page_style.dart';
import 'package:quill_diary/shared/presentation/widgets/entry_cover_thumbnail.dart';

/// 日記列表預覽圖橫向 strip；[lazyLoad] 為 true 時離屏項目延遲解密。
class EntryPreviewImageStrip extends StatelessWidget {
  const EntryPreviewImageStrip({
    required this.paths,
    this.thumbSize = 72,
    this.lazyLoad = false,
    super.key,
  });

  final List<String> paths;
  final double thumbSize;
  final bool lazyLoad;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: thumbSize,
      child: ClipRect(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < paths.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i < paths.length - 1 ? 10 : 0,
                  ),
                  child: lazyLoad
                      ? LazyEntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          staggerIndex: i,
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusThumbSmall,
                          ),
                        )
                      : EntryCoverThumbnail(
                          encryptedFilePath: paths[i],
                          size: thumbSize,
                          borderRadius: BorderRadius.circular(
                            PageStyle.radiusThumbSmall,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
