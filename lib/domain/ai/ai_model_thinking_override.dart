import 'dart:convert';

import 'package:quill_diary/domain/ai/ai_catalog.dart';

/// 模型自訂的請求片段；深度凍結，避免編輯設定時改到已送出的快照。
class AiModelThinkingOverride {
  AiModelThinkingOverride({
    required this.defaultLevel,
    required Map<AiThinkingLevel, Map<String, Object?>> levels,
  }) : levels = Map.unmodifiable({
         for (final entry in levels.entries)
           entry.key: _freezeObject(entry.value),
       }) {
    if (levels.isEmpty
        ? defaultLevel != null
        : !levels.containsKey(defaultLevel)) {
      throw const FormatException('預設強度必須是啟用的檔位。');
    }
    for (final fields in levels.values) {
      if (fields.keys.any(protectedAiRequestFields.contains)) {
        throw const FormatException('Thinking 片段不能覆寫訊息或請求控制欄位。');
      }
    }
  }

  factory AiModelThinkingOverride.omit() =>
      AiModelThinkingOverride(defaultLevel: null, levels: const {});

  factory AiModelThinkingOverride.fromJson(Map<String, dynamic> json) {
    final raw = json['levels'];
    if (raw is! Map) throw const FormatException('Thinking 對照格式不正確。');
    final levels = <AiThinkingLevel, Map<String, Object?>>{};
    for (final entry in raw.entries) {
      final level = AiThinkingLevel.values.byName(entry.key as String);
      if (entry.value is! Map) throw const FormatException('每個檔位須為 JSON 物件。');
      levels[level] = Map<String, Object?>.from(entry.value as Map);
    }
    return AiModelThinkingOverride(
      defaultLevel: json['default_level'] == null
          ? null
          : AiThinkingLevel.values.byName(json['default_level'] as String),
      levels: levels,
    );
  }

  final AiThinkingLevel? defaultLevel;
  final Map<AiThinkingLevel, Map<String, Object?>> levels;

  Map<String, Object?> toJson() => {
    'default_level': defaultLevel?.name,
    'levels': {for (final entry in levels.entries) entry.key.name: entry.value},
  };
}

const protectedAiRequestFields = {
  'model',
  'messages',
  'input',
  'instructions',
  'contents',
  'system',
  'systemInstruction',
  'stream',
  'store',
};

Map<String, Object?> _freezeObject(Map<String, Object?> value) =>
    Map.unmodifiable(
      value.map((key, item) => MapEntry(key, _freezeJson(item))),
    );

Object? _freezeJson(Object? value) {
  if (value is Map<String, Object?>) return _freezeObject(value);
  if (value is List) return List<Object?>.unmodifiable(value.map(_freezeJson));
  if (value == null ||
      value is String ||
      value is bool ||
      (value is num && value.isFinite)) {
    return value;
  }
  throw const FormatException('Thinking 片段必須是有效 JSON。');
}

Map<String, Object?> parseThinkingObject(String text) {
  final value = jsonDecode(text);
  if (value is! Map<String, dynamic>) {
    throw const FormatException('請輸入 JSON 物件。');
  }
  return _freezeObject(value);
}

bool aiJsonEquals(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) =>
              right.containsKey(key) && aiJsonEquals(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (!aiJsonEquals(left[i], right[i])) return false;
    }
    return true;
  }
  return left == right;
}

Map<String, Object?> mergeThinkingRequestFields(
  Map<String, Object?> base,
  Map<String, Object?> fields,
) => {
  ...base,
  for (final entry in fields.entries)
    entry.key:
        base[entry.key] is Map<String, Object?> &&
            entry.value is Map<String, Object?>
        ? mergeThinkingRequestFields(
            base[entry.key]! as Map<String, Object?>,
            entry.value! as Map<String, Object?>,
          )
        : entry.value,
};
