import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

abstract final class HomeLayout {
  static const double bodyHorizontal = 16;
  static const EdgeInsets bodyPadding = EdgeInsets.fromLTRB(
    bodyHorizontal,
    4,
    bodyHorizontal,
    16,
  );
  static const double sectionGap = 12;
  static const double tagListSectionHeight = 350;

  static const EdgeInsets tagListSectionCardPadding = EdgeInsets.fromLTRB(
    bodyHorizontal,
    16,
    bodyHorizontal - 5,
    14,
  );

  static const ScrollCacheExtent entryListCacheExtent =
      ScrollCacheExtent.pixels(1200);

  static const double circleActionSize = 44;
  static const double circleActionIconSize = 26;
  static const double circleActionSideInset = 8;
  static const double circleActionHorizontalInset =
      bodyHorizontal + circleActionSideInset;
  static const double snackBarBottomPadding = 12;
  static const double snackBarLaneHeight = 44;
  static const double actionAboveSnackBarGap = 6;
  static const double bottomActionsRestInset = snackBarBottomPadding;
  static const double snackBarLiftHeight =
      snackBarLaneHeight + actionAboveSnackBarGap;
  static const double bottomActionsLiftedInset =
      bottomActionsRestInset + snackBarLiftHeight;
  static const Duration bottomChromeAnimationDuration = Duration(
    milliseconds: 280,
  );
  static const Curve bottomChromeAnimationCurve = Curves.easeInOutCubic;

  static double bottomActionsInsetFor({required bool snackBarVisible}) {
    return snackBarVisible ? bottomActionsLiftedInset : bottomActionsRestInset;
  }
}
