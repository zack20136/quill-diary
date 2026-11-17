import 'package:material_ui/material_ui.dart';

import 'package:quill_diary/application/settings/settings_health.dart';

class SecurityOverviewItem {
  const SecurityOverviewItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.level,
    this.subtitle,
    this.subtitleCode,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? subtitle;

  /// 副標結尾的代碼片段（如復原金鑰末四碼），以等寬字呈現，便於逐字比對。
  final String? subtitleCode;
  final SettingsHealthLevel level;
}
