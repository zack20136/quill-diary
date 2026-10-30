import 'package:quill_diary/domain/shared/value_objects.dart';

class TagCatalogItem {
  const TagCatalogItem({
    required this.label,
    this.accentArgb,
    this.accentIsCustom,
  });

  final String label;
  final int? accentArgb;
  final bool? accentIsCustom;

  String get displayLabel => label.trim().replaceAll(RegExp(r'\s+'), ' ');

  String get normalized => normalizeText(displayLabel);

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'label': displayLabel,
      if (accentArgb != null) 'accent_argb': accentArgb,
      if (accentIsCustom != null) 'accent_is_custom': accentIsCustom,
    };
  }

  static TagCatalogItem? fromJson(Object? raw) {
    if (raw is! Map<Object?, Object?>) {
      return null;
    }
    final String label = '${raw['label'] ?? ''}'.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (label.isEmpty) {
      return null;
    }
    return TagCatalogItem(
      label: label,
      accentArgb: _parseArgb(raw['accent_argb']),
      accentIsCustom: _parseBool(raw['accent_is_custom']),
    );
  }

  static bool? _parseBool(Object? value) {
    if (value is bool) {
      return value;
    }
    return null;
  }

  static int? _parseArgb(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }
}
