import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:quill_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_diary/domain/diary/diary_entry.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';
import 'package:yaml/yaml.dart';

class DecodedFrontMatterDocument {
  const DecodedFrontMatterDocument({
    required this.entry,
    required this.frontMatter,
    required this.body,
    required this.attachmentPaths,
  });

  final DiaryEntry entry;
  final Map<String, Object?> frontMatter;
  final String body;
  final List<String> attachmentPaths;
}

class FrontMatterCodec {
  const FrontMatterCodec();

  String encode(
    DiaryEntry entry, {
    List<AssetAttachment> attachments = const <AssetAttachment>[],
    String Function(AssetAttachment attachment)? attachmentPathBuilder,
  }) {
    final List<String> lines = <String>[
      '---',
      'id: ${jsonEncode(entry.id)}',
      'title: ${jsonEncode(entry.title)}',
      'date: ${jsonEncode(entry.date.value)}',
      'created_at: ${jsonEncode(entry.createdAt.toIso8601String())}',
      'updated_at: ${jsonEncode(entry.updatedAt.toIso8601String())}',
      if (entry.tags.isEmpty) 'tags: []' else 'tags:',
      ...entry.tags.map((String tag) => '  - ${jsonEncode(tag)}'),
      if (entry.attachmentIds.isEmpty)
        'attachment_ids: []'
      else
        'attachment_ids:',
      ...entry.attachmentIds.map(
        (String assetId) => '  - ${jsonEncode(assetId)}',
      ),
      if (attachments.isEmpty) 'attachments: []' else 'attachments:',
      ...attachments.map((AssetAttachment asset) {
        final String path =
            attachmentPathBuilder?.call(asset) ??
            '../assets/${entry.date.yearString}/${entry.date.monthPadded}/${asset.safeFilename}';
        return '  - ${jsonEncode(path)}';
      }),
      '---',
      '',
      entry.markdownBody,
    ];
    return lines.join('\n');
  }

  DecodedFrontMatterDocument decodeDocument(String document) {
    final ({Map<String, Object?> frontMatter, String body}) parsed =
        _splitDocument(document);
    final Map<String, Object?> frontMatter = parsed.frontMatter;
    final List<String> attachmentPaths = _stringList(
      frontMatter['attachments'],
    );
    final List<String> attachmentIds = _resolveAttachmentIds(
      frontMatter: frontMatter,
      attachmentPaths: attachmentPaths,
    );

    return DecodedFrontMatterDocument(
      entry: DiaryEntry(
        id: (frontMatter['id'] ?? generateEntryId()).toString(),
        vaultId: (frontMatter['vault_id'] ?? 'vlt_LOCAL').toString(),
        title: frontMatter['title']?.toString(),
        date: DateOnly.parse((frontMatter['date'] ?? '1970-01-01').toString()),
        createdAt:
            DateTime.tryParse('${frontMatter['created_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            DateTime.tryParse('${frontMatter['updated_at'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        tags: _stringList(frontMatter['tags']),
        markdownBody: parsed.body,
        attachmentIds: attachmentIds,
      ),
      frontMatter: frontMatter,
      body: parsed.body,
      attachmentPaths: attachmentPaths,
    );
  }

  DiaryEntry decode(String document) => decodeDocument(document).entry;

  ({Map<String, Object?> frontMatter, String body}) _splitDocument(
    String document,
  ) {
    final opening = RegExp(r'^\uFEFF?---\r?\n').firstMatch(document);
    if (opening == null) {
      return (frontMatter: <String, Object?>{}, body: document);
    }

    final closing = RegExp(
      r'^---(?:\r?\n|$)',
      multiLine: true,
    ).firstMatch(document.substring(opening.end));
    if (closing == null) {
      return (frontMatter: <String, Object?>{}, body: document);
    }

    final String yamlSource = document.substring(
      opening.end,
      opening.end + closing.start,
    );
    final String body = document
        .substring(opening.end + closing.end)
        .replaceFirst(RegExp(r'^\r?\n'), '');
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

  List<String> _resolveAttachmentIds({
    required Map<String, Object?> frontMatter,
    required List<String> attachmentPaths,
  }) {
    final List<String> explicitIds = _stringList(frontMatter['attachment_ids']);
    if (explicitIds.isNotEmpty) {
      return explicitIds;
    }

    return attachmentPaths
        .map((String pathValue) => p.basenameWithoutExtension(pathValue))
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _stringList(Object? value) {
    if (value is! List<Object?>) {
      return const <String>[];
    }
    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((String item) => item.isNotEmpty)
        .toList();
  }
}
