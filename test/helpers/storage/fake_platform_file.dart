import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

/// 以指定 URI 與回報大小模擬選取檔案。
final class FakePlatformFile extends PlatformFile {
  FakePlatformFile({
    required this.name,
    required this.uri,
    this.reportedLength,
  });

  factory FakePlatformFile.local({
    required String name,
    required String path,
    int? reportedLength,
  }) {
    return FakePlatformFile(
      name: name,
      uri: Uri.file(path),
      reportedLength: reportedLength,
    );
  }

  factory FakePlatformFile.content({
    required String name,
    required String uri,
    int? reportedLength,
  }) {
    return FakePlatformFile(
      name: name,
      uri: Uri.parse(uri),
      reportedLength: reportedLength,
    );
  }

  @override
  final String name;

  @override
  final Uri uri;

  final int? reportedLength;

  @override
  XFile get xFile => XFile(path ?? uri.toString(), name: name);

  @override
  int? lengthSync() => reportedLength;

  @override
  Future<int?> length() async => reportedLength;

  @override
  Future<Uint8List> readAsBytes() async => Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => const Stream.empty();
}
