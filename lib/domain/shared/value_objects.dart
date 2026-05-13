typedef VaultId = String;
typedef EntryId = String;
typedef AssetId = String;
typedef BackupId = String;

class DateOnly {
  const DateOnly(this.value);

  final String value;

  @override
  String toString() => value;
}
