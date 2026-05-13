import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../../domain/attachment/asset_attachment.dart';
import '../../domain/diary/diary_entry.dart';
import '../../domain/shared/value_objects.dart';

class FrontMatterCodec {
  const FrontMatterCodec();

  String encode(
    DiaryEntry entry, {
    List<AssetAttachment> attachments = const <AssetAttachment>[],
  }) {
    final List<String> lines = <String>[
      '---',
      'id: "${entry.id}"',
      'title: ${_encodeScalar(entry.normalizedTitle)}',
      'date: "${entry.date}"',
      'created_at: "${entry.createdAt.toIso8601String()}"',
      'updated_at: "${entry.updatedAt.toIso8601String()}"',
      if (entry.tags.isEmpty) 'tags: []' else 'tags:',
      ...entry.tags.map((String tag) => '  - "${_escape(tag)}"'),
      'mood: ${_encodeScalar(entry.mood)}',
      if (attachments.isEmpty) 'attachments: []' else 'attachments:',
      ...attachments.map((AssetAttachment asset) => '  - "../assets/'
          '${entry.date.yearString}/${entry.date.monthPadded}/${asset.safeFilename}"'),
      'schema_version: 1',
      '---',
      '',
      entry.markdownBody.trimRight(),
      '',
    ];
    return lines.join('\n');
  }

  DiaryEntry decode(String document) {
    final ({Map<String, Object?> frontMatter, String body}) parsed =
        _splitDocument(document);
    final Map<String, Object?> frontMatter = parsed.frontMatter;
    final List<String> attachmentPaths = _stringList(frontMatter['attachments']);

    return DiaryEntry(
      id: (frontMatter['id'] ?? generateEntryId()).toString(),
      vaultId: (frontMatter['vault_id'] ?? 'vlt_LOCAL').toString(),
      title: _nullableString(frontMatter['title']),
      date: DateOnly.parse((frontMatter['date'] ?? '1970-01-01').toString()),
      createdAt: DateTime.tryParse('${frontMatter['created_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse('${frontMatter['updated_at'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tags: _stringList(frontMatter['tags']),
      mood: _nullableString(frontMatter['mood']),
      markdownBody: parsed.body,
      attachmentIds: attachmentPaths
          .map(
            (String pathValue) => p.basenameWithoutExtension(pathValue),
          )
          .where((String value) => value.isNotEmpty)
          .toList(),
      isDeleted: frontMatter['is_deleted'] == true,
    );
  }

  ({Map<String, Object?> frontMatter, String body}) _splitDocument(
    String document,
  ) {
    if (!document.startsWith('---\n')) {
      return (frontMatter: <String, Object?>{}, body: document.trim());
    }

    final int secondMarker = document.indexOf('\n---\n', 4);
    if (secondMarker == -1) {
      return (frontMatter: <String, Object?>{}, body: document.trim());
    }

    final String yamlSource = document.substring(4, secondMarker).trim();
    final String body = document.substring(secondMarker + 5).trim();
    final Object? loaded = loadYaml(yamlSource);
    final Map<String, Object?> frontMatter = <String, Object?>{};

    if (loaded is YamlMap) {
      for (final MapEntry<Object?, Object?> entry in loaded.entries) {
        frontMatter['${entry.key}'] = _convertYaml(entry.value);
      }
    }

    return (frontMatter: frontMatter, body: body);
  }

  Object? _convertYaml(Object? value) {
    if (value is YamlMap) {
      return <String, Object?>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          '${entry.key}': _convertYaml(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(_convertYaml).toList();
    }
    return value;
  }

  List<String> _stringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value.map((Object? item) => '$item').where((String item) => item.isNotEmpty).toList();
  }

  String? _nullableString(Object? value) {
    final String stringValue = '${value ?? ''}'.trim();
    if (stringValue.isEmpty || stringValue == 'null') {
      return null;
    }
    return stringValue;
  }

  String _encodeScalar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'null';
    }
    return '"${_escape(value.trim())}"';
  }

  String _escape(String input) => input.replaceAll('"', r'\"');
}
