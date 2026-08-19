import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/vault_repair_file_operations.dart';

void main() {
  late Directory tempDirectory;
  const VaultRepairFileOperations operations = VaultRepairFileOperations();

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('repair_file_ops_');
  });

  tearDown(() async {
    if (tempDirectory.existsSync()) await tempDirectory.delete(recursive: true);
  });

  test('暫存副本驗證成功後才提交到正式路徑', () async {
    final File source = File('${tempDirectory.path}/source.enc');
    final File target = File('${tempDirectory.path}/nested/target.enc');
    await source.writeAsBytes(<int>[1, 2, 3]);

    final VaultRepairCopyResult result = await operations
        .copyAtomicallyIfAbsent(
          sourcePath: source.path,
          targetPath: target.path,
          validate: (String path) async =>
              (await File(path).readAsBytes()).join(',') == '1,2,3',
        );

    expect(result, VaultRepairCopyResult.copied);
    expect(await target.readAsBytes(), <int>[1, 2, 3]);
    expect(source.existsSync(), isTrue);
  });

  test('暫存副本驗證失敗時保留來源且不留下半成品', () async {
    final File source = File('${tempDirectory.path}/source.enc');
    final File target = File('${tempDirectory.path}/target.enc');
    await source.writeAsBytes(<int>[1, 2, 3]);

    await expectLater(
      operations.copyAtomicallyIfAbsent(
        sourcePath: source.path,
        targetPath: target.path,
        validate: (_) async => false,
      ),
      throwsStateError,
    );

    expect(source.existsSync(), isTrue);
    expect(target.existsSync(), isFalse);
    final List<File> remaining = tempDirectory
        .listSync()
        .whereType<File>()
        .toList();
    expect(remaining, hasLength(1));
    expect(p.basename(remaining.single.path), 'source.enc');
  });

  test('暫存檔驗證後正式目標才出現時不覆寫', () async {
    final File source = File('${tempDirectory.path}/source.enc');
    final File target = File('${tempDirectory.path}/target.enc');
    await source.writeAsBytes(<int>[1]);

    final VaultRepairCopyResult result = await operations
        .copyAtomicallyIfAbsent(
          sourcePath: source.path,
          targetPath: target.path,
          validate: (_) async {
            await target.writeAsBytes(<int>[9]);
            return true;
          },
        );

    expect(result, VaultRepairCopyResult.targetExists);
    expect(await target.readAsBytes(), <int>[9]);
  });
}
