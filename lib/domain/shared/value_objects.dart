import 'package:intl/intl.dart';
import 'package:ulid/ulid.dart';

typedef VaultId = String;
typedef EntryId = String;
typedef AssetId = String;
typedef BackupId = String;
typedef DeviceSlotId = String;

String generateVaultId() => 'vlt_${Ulid().toCanonical().toUpperCase()}';

String generateEntryId() => 'jrn_${Ulid().toCanonical().toUpperCase()}';

String generateAssetId() => 'att_${Ulid().toCanonical().toUpperCase()}';

String generateBackupId() => 'bkp_${Ulid().toCanonical().toUpperCase()}';

String generateDeviceSlotId() => 'dev_${Ulid().toCanonical().toUpperCase()}';

String normalizeText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String previewTextFromMarkdown(String markdown, {int maxLength = 80}) {
  final String compact = searchableTextFromMarkdown(markdown);
  if (compact.length <= maxLength) {
    return compact;
  }

  return '${compact.substring(0, maxLength).trim()}...';
}

String searchableTextFromMarkdown(String markdown) {
  return markdown
      .replaceAll(RegExp(r'[#>*_`\[\]\(\)!-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class DateOnly {
  const DateOnly(this.value);

  factory DateOnly.fromDateTime(DateTime dateTime) {
    return DateOnly(DateFormat('yyyy-MM-dd').format(dateTime));
  }

  factory DateOnly.parse(String value) => DateOnly(value);

  final String value;

  int get year => int.parse(value.substring(0, 4));

  String get monthPadded => value.substring(5, 7);

  String get yearString => value.substring(0, 4);

  DateTime toDateTime() => DateTime.parse(value);

  @override
  String toString() => value;
}
