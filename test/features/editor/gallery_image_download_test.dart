import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/editor/gallery_image_download.dart';

void main() {
  test('已有副檔名時保留並 sanitize', () {
    expect(
      galleryDownloadFileName('vacation photo.jpg', 'image/jpeg'),
      'vacation_photo.jpg',
    );
  });

  test('無副檔名時依 mime 補上', () {
    expect(
      galleryDownloadFileName('camera_photo', 'image/jpeg'),
      'camera_photo.jpg',
    );
    expect(
      galleryDownloadFileName('anim', 'image/gif'),
      'anim.gif',
    );
  });

  test('空檔名 fallback 為 image.jpg', () {
    expect(
      galleryDownloadFileName(null, 'image/png'),
      'image.png',
    );
  });
}
