import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/infrastructure/storage/user_export_paths.dart';

void main() {
  test('picturesDisplayPath 使用 Pictures / quill-diary', () {
    expect(
      UserExportPaths.picturesDisplayPath('photo.jpg'),
      'Pictures / quill-diary / photo.jpg',
    );
  });

  test('downloadsDisplayPath 使用 Downloads / quill-diary', () {
    expect(
      UserExportPaths.downloadsDisplayPath('backup.zip'),
      'Downloads / quill-diary / backup.zip',
    );
  });
}
