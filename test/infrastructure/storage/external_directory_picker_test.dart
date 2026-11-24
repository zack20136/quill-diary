import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quill_diary/application/transfer/portable_transfer_service.dart';
import 'package:quill_diary/infrastructure/storage/external_directory_store.dart';
import 'package:quill_diary/infrastructure/storage/portable/portable_export_io.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_directory_picker.dart';
import 'package:quill_diary/infrastructure/storage/shared/external_file_delivery.dart';

import '../../helpers/shared/test_l10n.dart';
import '../../helpers/vault/vault_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform previous;

  setUp(() {
    previous = FilePickerPlatform.instance;
  });

  tearDown(() {
    FilePickerPlatform.instance = previous;
  });

  test('file URI 轉回不含結尾分隔符的資料夾路徑', () async {
    final directory = await Directory.systemTemp.createTemp(
      'external_directory_picker_',
    );
    addTearDown(() async {
      if (directory.existsSync()) {
        await directory.delete(recursive: true);
      }
    });
    FilePickerPlatform.instance = _FixedDirectoryPicker(
      Uri.directory(directory.path),
    );

    final String? picked = await ExternalDirectoryPicker.pickExternalDirectory(
      prompt: '選資料夾',
      initialDirectory: directory.path,
    );

    expect(picked, p.normalize(directory.path));
    expect(picked, isNot(endsWith(p.separator)));
  });

  test('content URI 原樣回傳，取消則為 null', () async {
    const String treeUri =
        'content://com.android.externalstorage.documents/tree/primary%3ADownload';
    FilePickerPlatform.instance = _FixedDirectoryPicker(Uri.parse(treeUri));

    expect(
      await ExternalDirectoryPicker.pickExternalDirectory(prompt: '選資料夾'),
      treeUri,
    );

    FilePickerPlatform.instance = _FixedDirectoryPicker(null);
    expect(
      await ExternalDirectoryPicker.pickExternalDirectory(prompt: '選資料夾'),
      isNull,
    );
  });

  test('無法記住上次資料夾時仍回傳已匯出的檔案', () async {
    final work = await Directory.systemTemp.createTemp('external_delivery_');
    addTearDown(() => work.delete(recursive: true));
    final selected = await Directory(p.join(work.path, 'selected')).create();
    final source = await File(p.join(work.path, 'staged.html'))
        .writeAsString('測試日記');
    FilePickerPlatform.instance = _FixedDirectoryPicker(
      Uri.directory(selected.path),
    );
    final output = await deliverToExternalDirectory(
      dialogTitle: '選資料夾',
      fileName: 'diary.html',
      source: source,
      resolveInitialDirectory: () async => null,
      rememberDirectory: (_) async => throw const FileSystemException('無法儲存偏好'),
    );
    expect(await File(output!).readAsString(), '測試日記');
  });

  test('匯出後暫存已消失時仍回傳已交付的 HTML 資料夾', () async {
    final harness = await VaultTestHarness.create();
    addTearDown(harness.dispose);
    final setup = await harness.repository.setupRecoveryKey();
    final entryId = await harness.saveSimpleEntry(setup, title: '測試日記');
    final selected = await Directory(p.join(harness.tempDir.path, 'selected'))
        .create();
    FilePickerPlatform.instance = _FixedDirectoryPicker(
      Uri.directory(selected.path),
    );
    final io = harness.createTransferIo();
    final service = PortableTransferService(
      exportIo: io.exporter,
      importIo: io.importer,
      externalDirectoryStore: _RemoveExportWorkOnDelivery(harness),
      pathStrategy: harness.pathStrategy,
    );

    final output = await service.exportHtmlToDirectory(
      setup.session,
      {entryId},
      testL10n,
      options: const HtmlExportOptions(externalAssets: true),
    );

    final html = await File(p.join(output!, 'diary.html')).readAsString();
    expect(html, contains('測試日記'));
  });
}

final class _FixedDirectoryPicker extends FilePickerPlatform {
  _FixedDirectoryPicker(this.directory);

  final Uri? directory;

  @override
  Future<Uri?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    return directory;
  }
}

final class _RemoveExportWorkOnDelivery extends ExternalDirectoryStore {
  _RemoveExportWorkOnDelivery(VaultTestHarness harness)
    : _harness = harness,
      super(harness.pathStrategy);

  final VaultTestHarness _harness;

  @override
  Future<String?> resolveInitialDirectory() async => null;

  @override
  Future<void> rememberDirectory(String directory) async {
    final work = await _harness.pathStrategy.transferWorkDirectory();
    final staged = await work.list().where((item) => item is Directory).single;
    await staged.delete(recursive: true);
  }
}
