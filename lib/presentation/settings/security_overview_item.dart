import 'package:flutter/material.dart';

import 'package:quill_diary/application/settings/settings_health_level.dart';

class SecurityOverviewItem {
  const SecurityOverviewItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.level,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? subtitle;
  final SettingsHealthLevel level;
}
