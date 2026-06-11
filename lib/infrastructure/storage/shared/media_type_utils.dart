import 'package:path/path.dart' as p;

/// 依副檔名推斷 MIME。
String mimeTypeFromFileName(String fileName) {
  return switch (p.extension(fileName).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.svg' => 'image/svg+xml',
    '.txt' => 'text/plain',
    '.md' => 'text/markdown',
    '.pdf' => 'application/pdf',
    '.mp4' => 'video/mp4',
    '.mov' => 'video/quicktime',
    _ => 'application/octet-stream',
  };
}

/// 依 MIME 推斷副檔名（不含點）。
String extensionFromMimeType(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/jpeg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/svg+xml' => 'svg',
    'text/plain' => 'txt',
    'text/markdown' => 'md',
    'application/pdf' => 'pdf',
    _ => 'bin',
  };
}

/// 依副檔名推斷 MIME（儲存庫用）。
String mimeTypeFromExtension(String extension) {
  final String normalized = extension.startsWith('.') ? extension : '.$extension';
  return mimeTypeFromFileName('file$normalized');
}
