import 'package:flutter/material.dart';
import 'package:quill_diary/app/theme.dart';

/// Widget 測試用的完整 App 主題（含 [AppColors] extension）。
ThemeData appTestTheme({Brightness brightness = Brightness.light}) =>
    buildAppTheme(brightness: brightness);
