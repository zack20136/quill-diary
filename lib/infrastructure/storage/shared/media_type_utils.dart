import 'dart:convert';

import 'package:path/path.dart' as p;

/// 依副檔名推斷 MIME。
String mimeTypeFromFileName(String fileName) {
  return switch (p.extension(fileName).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.png' => 'image/png',
    '.gif' => 'image/gif',
    '.webp' => 'image/webp',
    '.bmp' => 'image/bmp',
    '.heic' || '.heif' => 'image/heic',
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
    'image/bmp' => 'bmp',
    'image/heic' => 'heic',
    'image/svg+xml' => 'svg',
    'text/plain' => 'txt',
    'text/markdown' => 'md',
    'application/pdf' => 'pdf',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    _ => 'bin',
  };
}

/// 依可靠的檔案特徵判斷 MIME；無法可靠辨識時回傳 null。
String? sniffKnownMediaMimeType(List<int> bytes) {
  if (_startsWith(bytes, const <int>[0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (_startsWith(bytes, const <int>[
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ])) {
    return 'image/png';
  }
  if (_startsWith(bytes, const <int>[0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
      _startsWith(bytes, const <int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      _asciiAt(bytes, 0, 4) == 'RIFF' &&
      _asciiAt(bytes, 8, 4) == 'WEBP') {
    return 'image/webp';
  }
  if (_startsWith(bytes, const <int>[0x42, 0x4D])) return 'image/bmp';
  if (_startsWith(bytes, const <int>[0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return 'application/pdf';
  }
  if (bytes.length >= 12 && _asciiAt(bytes, 4, 4) == 'ftyp') {
    final String brand = _asciiAt(bytes, 8, 4);
    if (brand == 'qt  ') return 'video/quicktime';
    if (_heicBrands.contains(brand)) {
      return 'image/heic';
    }
    if (_mp4Brands.contains(brand)) return 'video/mp4';
  }
  return null;
}

/// 已知格式必須符合內容特徵；未知格式採保守策略保留。
bool attachmentContentMatchesMimeType(List<int> bytes, String mimeType) {
  final String normalized = mimeType.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized == 'application/octet-stream') return true;
  if (normalized == 'text/plain' || normalized == 'text/markdown') {
    return _isValidUtf8(bytes);
  }
  if (normalized == 'image/svg+xml') {
    if (!_isValidUtf8(bytes)) return false;
    final String text = utf8.decode(bytes).trimLeft();
    return RegExp(
      r'^(?:<\?xml[^>]*>\s*)?(?:<!--.*?-->\s*)*<svg\b',
      dotAll: true,
    ).hasMatch(text);
  }
  final String? detected = sniffKnownMediaMimeType(bytes);
  if (_mimeTypesWithSignatures.contains(normalized)) {
    return detected == normalized;
  }
  return true;
}

bool contentTypeMatchesExtension(String contentType, String extension) {
  final String normalizedExtension = extension
      .trim()
      .toLowerCase()
      .replaceFirst(RegExp(r'^\.'), '');
  if (normalizedExtension.isEmpty || normalizedExtension == 'bin') return true;
  final String inferred = mimeTypeFromFileName('file.$normalizedExtension');
  return inferred == 'application/octet-stream' ||
      inferred == contentType.trim().toLowerCase();
}

const Set<String> _mimeTypesWithSignatures = <String>{
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp',
  'image/bmp',
  'image/heic',
  'application/pdf',
  'video/mp4',
  'video/quicktime',
};

const Set<String> _heicBrands = <String>{
  'heic',
  'heix',
  'hevc',
  'hevx',
  'heim',
  'heis',
  'hevm',
  'hevs',
  'mif1',
  'msf1',
};

const Set<String> _mp4Brands = <String>{
  'isom',
  'iso2',
  'iso3',
  'iso4',
  'iso5',
  'iso6',
  'avc1',
  'dash',
  'M4V ',
  'M4A ',
  'mp41',
  'mp42',
  'mp71',
  'MSNV',
};

bool _startsWith(List<int> bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}

String _asciiAt(List<int> bytes, int start, int length) {
  return String.fromCharCodes(bytes.sublist(start, start + length));
}

bool _isValidUtf8(List<int> bytes) {
  try {
    utf8.decode(bytes);
    return true;
  } on FormatException {
    return false;
  }
}
