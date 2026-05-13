import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class QuillLockDiaryApp extends StatelessWidget {
  const QuillLockDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuillLockDiary',
      theme: buildAppTheme(),
      initialRoute: AppRouter.homeRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
