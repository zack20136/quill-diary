class VaultPathStrategy {
  const VaultPathStrategy();

  String entryPath({
    required String year,
    required String month,
    required String entryId,
  }) {
    return 'vault/entries/$year/$month/$entryId.md.enc';
  }

  String assetPath({
    required String year,
    required String month,
    required String assetId,
    required String extension,
  }) {
    return 'vault/assets/$year/$month/$assetId.$extension.enc';
  }
}
