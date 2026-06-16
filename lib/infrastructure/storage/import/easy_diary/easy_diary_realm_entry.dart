/// Easy Diary Realm 通道回傳的單篇日記資料。
class EasyDiaryPhotoRef {
  const EasyDiaryPhotoRef({required this.photoKey, this.mimeType});

  final String photoKey;
  final String? mimeType;
}

class EasyDiaryRealmEntry {
  const EasyDiaryRealmEntry({
    required this.title,
    required this.contents,
    required this.dateString,
    required this.currentTimeMillis,
    required this.isEncrypt,
    required this.photos,
  });

  final String? title;
  final String? contents;
  final String? dateString;
  final int? currentTimeMillis;
  final bool isEncrypt;
  final List<EasyDiaryPhotoRef> photos;

  static EasyDiaryRealmEntry? tryParse(Map<dynamic, dynamic> raw) {
    final List<EasyDiaryPhotoRef> photos = <EasyDiaryPhotoRef>[];

    final Object? rawPhotos = raw['photos'];
    if (rawPhotos is List) {
      for (final Object? value in rawPhotos) {
        if (value is! Map) {
          continue;
        }
        final String? photoKey = value['photoKey'] as String?;
        if (photoKey == null || photoKey.trim().isEmpty) {
          continue;
        }
        photos.add(
          EasyDiaryPhotoRef(
            photoKey: photoKey.trim(),
            mimeType: value['mimeType'] as String?,
          ),
        );
      }
    }

    return EasyDiaryRealmEntry(
      title: raw['title'] as String?,
      contents: raw['contents'] as String?,
      dateString: raw['dateString'] as String?,
      currentTimeMillis: (raw['currentTimeMillis'] as num?)?.toInt(),
      isEncrypt: raw['isEncrypt'] == true,
      photos: photos,
    );
  }
}

List<EasyDiaryRealmEntry> parseEasyDiaryRealmEntries(Object? response) {
  if (response is! Map) {
    return const <EasyDiaryRealmEntry>[];
  }

  final Object? rawEntries = response['entries'];
  if (rawEntries is! List) {
    return const <EasyDiaryRealmEntry>[];
  }

  final List<EasyDiaryRealmEntry> parsed = <EasyDiaryRealmEntry>[];
  for (final Object? rawEntry in rawEntries) {
    if (rawEntry is! Map) {
      continue;
    }
    final EasyDiaryRealmEntry? entry = EasyDiaryRealmEntry.tryParse(rawEntry);
    if (entry != null) {
      parsed.add(entry);
    }
  }
  return parsed;
}
