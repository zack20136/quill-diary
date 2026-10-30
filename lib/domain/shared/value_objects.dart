import 'package:intl/intl.dart';
import 'package:ulid/ulid.dart';

typedef VaultId = String;
typedef EntryId = String;
typedef AssetId = String;
typedef DeviceSlotId = String;
typedef PersonId = String;

/// 穩定前綴 ID 使匯出檔案可讀，並避免跨類型混淆。
String generateVaultId() => 'vlt_${Ulid().toBase32()}';

String generateEntryId() => 'jrn_${Ulid().toBase32()}';

String generateChatDiaryId() => 'chat_${Ulid().toBase32()}';

String generateChatDiaryMessageId() => 'msg_${Ulid().toBase32()}';

String generateAssetId() => 'att_${Ulid().toBase32()}';

String generateBackupId() => 'bkp_${Ulid().toBase32()}';

String generatePersonId() => 'per_${Ulid().toBase32()}';

String normalizeText(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// 人物姓名／別名正規化（與 [normalizeText] 相同規則）。
String normalizePersonName(String value) => normalizeText(value);

/// 以 `yyyy-MM-dd` 儲存、不含時區語意的日曆日期。
class DateOnly {
  const DateOnly(this.value);

  factory DateOnly.fromDateTime(DateTime dateTime) {
    return DateOnly(DateFormat('yyyy-MM-dd').format(dateTime));
  }

  factory DateOnly.parse(String value) => DateOnly(value);

  static DateOnly? tryParse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    try {
      final DateTime parsed = DateTime.parse(value);
      final String canonical = DateFormat('yyyy-MM-dd').format(parsed);
      return canonical == value ? DateOnly(value) : null;
    } on FormatException {
      return null;
    }
  }

  final String value;

  int get year => int.parse(value.substring(0, 4));

  String get monthPadded => value.substring(5, 7);

  String get yearString => value.substring(0, 4);

  DateTime toDateTime() => DateTime.parse(value);

  @override
  String toString() => value;
}
