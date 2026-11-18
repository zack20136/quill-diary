import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:path/path.dart' as p;

class ZipStructureLimitException implements Exception {
  const ZipStructureLimitException(this.limit);
  final String limit;
}

class ZipUnsafePathException extends FormatException {
  const ZipUnsafePathException() : super('ZIP 包含不安全路徑');
}

final class _ZipEntry {
  const _ZipEntry(
    this.name,
    this.rawName,
    this.flags,
    this.method,
    this.crc,
    this.compressed,
    this.size,
    this.offset,
    this.zip64,
  );
  final String name;
  final Uint8List rawName;
  final int flags, method, crc, compressed, size, offset;
  final bool zip64;
}

final class _ZipSource {
  _ZipSource(File file) : handle = file.openSync(), length = file.lengthSync();
  final RandomAccessFile handle;
  final int length;
  var cacheStart = -1;
  Uint8List cache = Uint8List(0);

  Uint8List read(int offset, int count) {
    if (offset < 0 || count < 0 || offset > length || count > length - offset) {
      throw const FormatException('ZIP 記錄截斷或範圍溢位');
    }
    if (offset >= cacheStart && offset + count <= cacheStart + cache.length) {
      return Uint8List.sublistView(
        cache,
        offset - cacheStart,
        offset - cacheStart + count,
      );
    }
    handle.setPositionSync(offset);
    cacheStart = offset;
    cache = handle.readSync(max(count, min(65536, length - offset)));
    if (cache.length < count) throw const FormatException('ZIP 讀取截斷');
    return Uint8List.sublistView(cache, 0, count);
  }

  int u16(int at) =>
      ByteData.sublistView(read(at, 2)).getUint16(0, Endian.little);
  int u32(int at) =>
      ByteData.sublistView(read(at, 4)).getUint32(0, Endian.little);
  int u64(int at) {
    final value = ByteData.sublistView(read(at, 8)).getUint64(0, Endian.little);
    if (value < 0) throw const FormatException('ZIP64 整數超出支援範圍');
    return value;
  }
}

String _path(Uint8List bytes) {
  String name;
  try {
    name = utf8.decode(bytes);
  } on FormatException {
    const cp437High =
        'ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»'
        '░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀'
        'αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ ';
    name = String.fromCharCodes(
      bytes.map((byte) => byte < 128 ? byte : cp437High.codeUnitAt(byte - 128)),
    );
  }
  final separators = name.replaceAll('\\', '/');
  final segments = separators.split('/');
  if (name.isEmpty ||
      name.contains('\x00') ||
      separators.startsWith('/') ||
      segments.contains('..') ||
      segments.any(
        (segment) =>
            segment.contains(':') ||
            segment.endsWith('.') && segment != '.' ||
            segment.endsWith(' '),
      )) {
    throw const ZipUnsafePathException();
  }
  final normalized = p.posix.normalize(separators);
  if (normalized == '.' || normalized.isEmpty) {
    throw const FormatException('ZIP 路徑不正確');
  }
  return separators.endsWith('/') && !normalized.endsWith('/')
      ? '$normalized/'
      : normalized;
}

String _entryPath(Uint8List raw, Map<int, Uint8List> extras) {
  final original = _path(raw);
  final unicode = extras[0x7075];
  if (unicode == null ||
      unicode.length < 5 ||
      unicode[0] != 1 ||
      ByteData.sublistView(unicode).getUint32(1, Endian.little) !=
          getCrc32(raw)) {
    return original;
  }
  final path = Uint8List.sublistView(unicode, 5);
  if (path.isEmpty) return original;
  utf8.decode(path);
  return _path(path);
}

Map<int, Uint8List> _extras(Uint8List bytes) {
  final result = <int, Uint8List>{};
  final data = ByteData.sublistView(bytes);
  var at = 0;
  while (at < bytes.length) {
    if (bytes.length - at < 4) {
      throw const FormatException('ZIP extra field 截斷');
    }
    final id = data.getUint16(at, Endian.little);
    final size = data.getUint16(at + 2, Endian.little);
    at += 4;
    if (size > bytes.length - at || result.containsKey(id)) {
      throw const FormatException('ZIP extra field 重複或截斷');
    }
    result[id] = Uint8List.sublistView(bytes, at, at + size);
    at += size;
  }
  return result;
}

List<int> _zip64Values(
  Map<int, Uint8List> extras,
  List<int> values,
  List<int> sentinels,
) {
  if (!List.generate(
    values.length,
    (i) => values[i] == sentinels[i],
  ).contains(true)) {
    return values;
  }
  final bytes = extras[1];
  if (bytes == null) throw const FormatException('缺少 ZIP64 extra field');
  final data = ByteData.sublistView(bytes);
  var at = 0;
  return List.generate(values.length, (i) {
    if (values[i] != sentinels[i]) return values[i];
    final width = i == 3 ? 4 : 8;
    if (bytes.length - at < width) {
      throw const FormatException('ZIP64 extra field 截斷');
    }
    final value = width == 4
        ? data.getUint32(at, Endian.little)
        : data.getUint64(at, Endian.little);
    at += width;
    if (value < 0) throw const FormatException('ZIP64 整數溢位');
    return value;
  });
}

/// 在解碼器建立 Archive、合併同名項目之前檢查原始記錄。
void validateZipStructure(
  File file, {
  required int maxEntries,
  required int maxEntryBytes,
  required int maxTotalBytes,
  required int maxCompressionRatio,
  required int maxMetadataBytes,
}) {
  final source = _ZipSource(file);
  try {
    if (source.length < 22) throw const FormatException('ZIP 缺少結束記錄');
    final start = max(0, source.length - 65557);
    final tail = source.read(start, source.length - start);
    final data = ByteData.sublistView(tail);
    final candidates = <int>[];
    for (var i = tail.length - 22; i >= 0; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50 &&
          i + 22 + data.getUint16(i + 20, Endian.little) == tail.length) {
        candidates.add(start + i);
      }
    }
    if (candidates.length != 1) {
      throw const FormatException('ZIP 結束記錄存在歧義或缺失');
    }
    _validateRecords(
      source,
      candidates.single,
      maxEntries,
      maxEntryBytes,
      maxTotalBytes,
      maxCompressionRatio,
      maxMetadataBytes,
    );
  } finally {
    source.handle.closeSync();
  }
}

void _validateRecords(
  _ZipSource source,
  int end,
  int maxEntries,
  int maxEntryBytes,
  int maxTotalBytes,
  int maxCompressionRatio,
  int maxMetadataBytes,
) {
  if (source.u16(end + 4) != 0 ||
      source.u16(end + 6) != 0 ||
      source.u16(end + 8) != source.u16(end + 10)) {
    throw const FormatException('不支援分卷 ZIP');
  }
  var count = source.u16(end + 10);
  var directorySize = source.u32(end + 12);
  var directoryOffset = source.u32(end + 16);
  var directoryEnd = end;
  if (end >= 20 && source.u32(end - 20) == 0x07064b50) {
    if (source.u32(end - 16) != 0 || source.u32(end - 4) != 1) {
      throw const FormatException('不支援分卷 ZIP64');
    }
    final record = source.u64(end - 12);
    if (source.u32(record) != 0x06064b50 ||
        source.u64(record + 4) < 44 ||
        source.u64(record + 4) > maxMetadataBytes ||
        record + 12 + source.u64(record + 4) != end - 20 ||
        source.u32(record + 16) != 0 ||
        source.u32(record + 20) != 0 ||
        source.u64(record + 24) != source.u64(record + 32)) {
      throw const FormatException('ZIP64 結束記錄不正確');
    }
    final actualCount = source.u64(record + 32);
    final actualSize = source.u64(record + 40);
    final actualOffset = source.u64(record + 48);
    if (count != 0xffff && count != actualCount ||
        directorySize != 0xffffffff && directorySize != actualSize ||
        directoryOffset != 0xffffffff && directoryOffset != actualOffset) {
      throw const FormatException('ZIP64 與傳統結束記錄矛盾');
    }
    count = actualCount;
    directorySize = actualSize;
    directoryOffset = actualOffset;
    directoryEnd = record;
  } else if (count == 0xffff ||
      directorySize == 0xffffffff ||
      directoryOffset == 0xffffffff) {
    throw const FormatException('缺少 ZIP64 結束記錄');
  }
  if (count > maxEntries) {
    throw const ZipStructureLimitException('tooManyEntries');
  }
  var metadataBytes = directorySize + source.length - directoryEnd;
  if (metadataBytes > maxMetadataBytes) {
    throw const ZipStructureLimitException('totalTooLarge');
  }
  if (directoryOffset < 0 ||
      directorySize < 0 ||
      directoryOffset > directoryEnd ||
      directorySize != directoryEnd - directoryOffset) {
    throw const FormatException('ZIP 中央目錄範圍不正確');
  }
  final entries = <_ZipEntry>[];
  final names = <String, bool>{};
  var position = directoryOffset;
  var total = 0;
  for (var i = 0; i < count; i++) {
    if (position > directoryEnd - 46 || source.u32(position) != 0x02014b50) {
      throw const FormatException('ZIP 中央記錄截斷');
    }
    final nameSize = source.u16(position + 28);
    final extraSize = source.u16(position + 30);
    final commentSize = source.u16(position + 32);
    final endRecord = position + 46 + nameSize + extraSize + commentSize;
    if (endRecord > directoryEnd) throw const FormatException('ZIP 中央項目截斷');
    final rawName = Uint8List.fromList(source.read(position + 46, nameSize));
    final extras = _extras(source.read(position + 46 + nameSize, extraSize));
    final name = _entryPath(rawName, extras);
    final canonical = name.replaceFirst(RegExp(r'/$'), '').toLowerCase();
    if (names.containsKey(canonical)) {
      throw const FormatException('ZIP 項目重複或路徑衝突');
    }
    final directory = name.endsWith('/');
    names[canonical] = directory;
    final flags = source.u16(position + 8);
    final method = source.u16(position + 10);
    if (flags & ~0x080e != 0 ||
        method != 0 && method != 8 ||
        method == 0 && flags & 6 != 0) {
      throw const FormatException('ZIP 使用不支援的旗標、加密或壓縮方法');
    }
    if (flags & 0x800 != 0) utf8.decode(rawName);
    final attributes = source.u32(position + 38);
    final type = (attributes >> 16) & 0xf000;
    if (type != 0 && type != 0x8000 && type != 0x4000 ||
        type == 0x4000 && !directory ||
        type == 0x8000 && directory) {
      throw const FormatException('ZIP 包含連結或特殊檔案');
    }
    if (extras[0x000d] != null && extras[0x000d]!.length > 12 ||
        extras[0x756e] != null && extras[0x756e]!.length > 14) {
      throw const FormatException('ZIP 包含不支援的連結描述');
    }
    final originalSize = source.u32(position + 24);
    final originalCompressed = source.u32(position + 20);
    final values = _zip64Values(
      extras,
      [
        originalSize,
        originalCompressed,
        source.u32(position + 42),
        source.u16(position + 34),
      ],
      [0xffffffff, 0xffffffff, 0xffffffff, 0xffff],
    );
    if (values[3] != 0) throw const FormatException('不支援分卷項目');
    final size = values[0];
    final compressed = values[1];
    if (size > maxEntryBytes) {
      throw const ZipStructureLimitException('entryTooLarge');
    }
    total += size;
    if (total > maxTotalBytes) {
      throw const ZipStructureLimitException('totalTooLarge');
    }
    if (size > 0 &&
        (compressed == 0 || size > compressed * maxCompressionRatio)) {
      throw const ZipStructureLimitException('suspiciousRatio');
    }
    if (method == 0 && size != compressed || directory && size != 0) {
      throw const FormatException('ZIP 宣告大小不正確');
    }
    entries.add(
      _ZipEntry(
        name,
        rawName,
        flags,
        method,
        source.u32(position + 16),
        compressed,
        size,
        values[2],
        originalSize == 0xffffffff || originalCompressed == 0xffffffff,
      ),
    );
    position = endRecord;
  }
  if (position != directoryEnd) throw const FormatException('ZIP 中央目錄項目數不符');
  for (final name in names.keys) {
    var parent = p.posix.dirname(name);
    while (parent != '.') {
      if (names[parent] == false) throw const FormatException('ZIP 檔案與目錄路徑衝突');
      parent = p.posix.dirname(parent);
    }
  }
  entries.sort((a, b) => a.offset.compareTo(b.offset));
  var previousEnd = 0;
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final offset = entry.offset;
    final boundary = i + 1 == entries.length
        ? directoryOffset
        : entries[i + 1].offset;
    if (offset != previousEnd ||
        offset > boundary - 30 ||
        source.u32(offset) != 0x04034b50 ||
        source.u16(offset + 6) != entry.flags ||
        source.u16(offset + 8) != entry.method) {
      throw const FormatException('ZIP Local Header 重疊、遺漏或與中央記錄矛盾');
    }
    final nameSize = source.u16(offset + 26);
    final extraSize = source.u16(offset + 28);
    final contentStart = offset + 30 + nameSize + extraSize;
    metadataBytes += contentStart - offset;
    if (metadataBytes > maxMetadataBytes) {
      throw const ZipStructureLimitException('totalTooLarge');
    }
    if (contentStart > boundary ||
        nameSize != entry.rawName.length ||
        base64Encode(source.read(offset + 30, nameSize)) !=
            base64Encode(entry.rawName)) {
      throw const FormatException('ZIP Local Header 檔名不符');
    }
    final extras = _extras(source.read(offset + 30 + nameSize, extraSize));
    if (extras.containsKey(0x7075) &&
        _entryPath(entry.rawName, extras) != entry.name) {
      throw const FormatException('ZIP Unicode 路徑描述不一致');
    }
    final local = _zip64Values(
      extras,
      [source.u32(offset + 22), source.u32(offset + 18)],
      [0xffffffff, 0xffffffff],
    );
    if (entry.compressed > boundary - contentStart) {
      throw const FormatException('ZIP 資料範圍重疊或截斷');
    }
    final contentEnd = contentStart + entry.compressed;
    if (entry.flags & 8 == 0) {
      if (source.u32(offset + 14) != entry.crc ||
          local[0] != entry.size ||
          local[1] != entry.compressed ||
          contentEnd != boundary) {
        throw const FormatException('ZIP Local Header 大小或 CRC 不符');
      }
    } else {
      metadataBytes += boundary - contentEnd;
      if (metadataBytes > maxMetadataBytes) {
        throw const ZipStructureLimitException('totalTooLarge');
      }
      if (source.u32(offset + 14) != 0 &&
              source.u32(offset + 14) != entry.crc ||
          local[0] != 0 && local[0] != entry.size ||
          local[1] != 0 && local[1] != entry.compressed) {
        throw const FormatException('ZIP Bit 3 占位值不正確');
      }
      var matches = 0;
      for (final signature in [false, true]) {
        for (final width in [4, 8]) {
          if (entry.zip64 && width != 8) continue;
          final descriptorSize = (signature ? 4 : 0) + 4 + width * 2;
          if (boundary - contentEnd != descriptorSize) continue;
          var at = contentEnd;
          if (signature) {
            if (source.u32(at) != 0x08074b50) continue;
            at += 4;
          }
          if (source.u32(at) != entry.crc) continue;
          at += 4;
          final compressed = width == 4 ? source.u32(at) : source.u64(at);
          final size = width == 4
              ? source.u32(at + width)
              : source.u64(at + width);
          if (compressed == entry.compressed && size == entry.size) matches++;
        }
      }
      if (matches != 1) {
        throw const FormatException('ZIP Data Descriptor 缺少、矛盾或存在歧義');
      }
    }
    previousEnd = boundary;
  }
  if (previousEnd != directoryOffset) {
    throw const FormatException('ZIP 有未列入中央目錄的資料');
  }
}
