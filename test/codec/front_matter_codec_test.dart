import 'package:flutter_test/flutter_test.dart';
import 'package:quill_lock_diary/domain/attachment/asset_attachment.dart';
import 'package:quill_lock_diary/domain/diary/diary_entry.dart';
import 'package:quill_lock_diary/domain/shared/value_objects.dart';
import 'package:quill_lock_diary/infrastructure/markdown/front_matter_codec.dart';

void main() {
  const FrontMatterCodec codec = FrontMatterCodec();

  test('front matter codec round-trips diary documents', () {
    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: generateVaultId(),
      title: '今天散步',
      date: const DateOnly('2026-05-13'),
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T21:02:44Z'),
      tags: const <String>['生活', '散步'],
      mood: 'calm',
      markdownBody: '# 今天散步\n\n今天晚上去河邊走了一圈。',
      attachmentIds: const <String>['att_TEST0001'],
    );
    final AssetAttachment attachment = AssetAttachment(
      id: 'att_TEST0001',
      entryId: 'jrn_TEST0001',
      mimeType: 'image/webp',
      safeFilename: 'att_TEST0001.webp',
      byteSize: 1024,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      sha256: 'deadbeef',
    );

    final String document = codec.encode(entry, attachments: <AssetAttachment>[attachment]);
    final DiaryEntry decoded = codec.decode(document);

    expect(decoded.id, entry.id);
    expect(decoded.title, entry.title);
    expect(decoded.date.value, entry.date.value);
    expect(decoded.tags, entry.tags);
    expect(decoded.mood, entry.mood);
    expect(decoded.markdownBody, entry.markdownBody);
    expect(decoded.attachmentIds, const <String>['att_TEST0001']);
    expect(document, contains('attachment_ids:'));
  });

  test('attachment_ids 優先於 attachments 路徑檔名', () {
    final DiaryEntry entry = DiaryEntry(
      id: generateEntryId(),
      vaultId: generateVaultId(),
      date: const DateOnly('2026-05-13'),
      createdAt: DateTime.parse('2026-05-13T20:30:12Z'),
      updatedAt: DateTime.parse('2026-05-13T21:02:44Z'),
      markdownBody: '匯入內容',
      attachmentIds: const <String>['ast_REAL0001'],
    );
    final AssetAttachment attachment = AssetAttachment(
      id: 'ast_REAL0001',
      entryId: entry.id,
      mimeType: 'image/jpeg',
      safeFilename: 'embedded_1.jpg',
      byteSize: 2048,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      sha256: 'abc',
    );

    final String document = codec.encode(entry, attachments: <AssetAttachment>[attachment]);
    final DiaryEntry decoded = codec.decode(document);

    expect(decoded.attachmentIds, const <String>['ast_REAL0001']);
  });

  test('無 front matter 時 body 原樣保留', () {
    const String raw = '純文字日記內容';
    final DiaryEntry decoded = codec.decode(raw);
    expect(decoded.markdownBody, raw);
    expect(decoded.tags, isEmpty);
  });

  test('encode 空 tags 列表', () {
    final DiaryEntry entry = DiaryEntry(
      id: 'jrn_EMPTY_TAGS',
      vaultId: 'vlt_LOCAL',
      date: const DateOnly('2026-01-01'),
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-02T00:00:00Z'),
      markdownBody: 'body',
      tags: const <String>[],
    );

    final String document = codec.encode(entry);
    expect(document, contains('tags: []'));
    expect(codec.decode(document).tags, isEmpty);
  });
}
