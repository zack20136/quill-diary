import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/shared/vault_file_ops.dart';

void main() {
  late Directory directory;
  late File target;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vault_file_ops_');
    target = File(p.join(directory.path, 'people.json.enc'));
  });

  tearDown(() async {
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('首次寫入中斷只留下暫存檔時會完成替換', () async {
    await File('${target.path}.tmp').writeAsBytes(<int>[1, 2, 3]);

    await recoverFileReplacement(target);

    expect(await target.readAsBytes(), <int>[1, 2, 3]);
    expect(File('${target.path}.tmp').existsSync(), isFalse);
  });

  test('只留下備份與暫存檔時優先還原最後有效版本', () async {
    await File('${target.path}.previous').writeAsBytes(<int>[1]);
    await File('${target.path}.tmp').writeAsBytes(<int>[2]);

    await recoverFileReplacement(target);

    expect(await target.readAsBytes(), <int>[1]);
    expect(File('${target.path}.previous').existsSync(), isFalse);
    expect(File('${target.path}.tmp').existsSync(), isFalse);
  });

  test('目標檔存在時會清除殘留備份與暫存檔', () async {
    await target.writeAsBytes(<int>[3]);
    await File('${target.path}.previous').writeAsBytes(<int>[1]);
    await File('${target.path}.tmp').writeAsBytes(<int>[2]);

    await recoverFileReplacement(target);

    expect(await target.readAsBytes(), <int>[3]);
    expect(File('${target.path}.previous').existsSync(), isFalse);
    expect(File('${target.path}.tmp').existsSync(), isFalse);
  });
}
