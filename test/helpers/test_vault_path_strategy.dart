import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:quill_diary/infrastructure/storage/vault_path_strategy.dart';

class TestVaultPathStrategy extends VaultPathStrategy {
  TestVaultPathStrategy(this.root);

  final Directory root;

  @override
  Future<Directory> appRootDirectory() async => root;

  @override
  Future<Directory> vaultRootDirectory() async =>
      Directory(p.join(root.path, 'vault'));

  @override
  Future<Directory> indexRootDirectory() async =>
      Directory(p.join(root.path, 'index'));
}

class TmpIndexPathStrategy extends VaultPathStrategy {
  TmpIndexPathStrategy(this.absolutePath);

  final String absolutePath;

  @override
  Future<String> indexDatabasePath() async => absolutePath;
}

class DummyVaultPathStrategy extends VaultPathStrategy {
  @override
  Future<Directory> appRootDirectory() async {
    return Directory.systemTemp.createTempSync('qld_session_test_');
  }
}
