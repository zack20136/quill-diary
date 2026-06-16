import 'package:flutter/rendering.dart';

/// 首頁各分頁共用的版面常數。
abstract final class HomeLayout {
  static const double bodyHorizontal = 12;
  static const EdgeInsets bodyPadding =
      EdgeInsets.fromLTRB(bodyHorizontal, 4, bodyHorizontal, 16);
  static const double sectionGap = 12;
  static const double tagListSectionHeight = 350;
  static const ScrollCacheExtent entryListCacheExtent =
      ScrollCacheExtent.pixels(600);
}
