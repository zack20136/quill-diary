import '../shared/value_objects.dart';

abstract final class DiaryDatePolicy {
  static final DateTime earliestSelectableDate = DateTime(2000);

  static DateTime latestSelectableDate({DateTime? now}) {
    final DateTime anchor = now ?? DateTime.now();
    return DateTime(anchor.year + 1, 12, 31);
  }

  static ({DateTime first, DateTime last}) selectableRange({
    DateTime? now,
    DateOnly? includedDate,
  }) {
    DateTime first = earliestSelectableDate;
    DateTime last = latestSelectableDate(now: now);
    final DateTime? included = includedDate?.toDateTime();
    if (included != null && included.isBefore(first)) {
      first = included;
    }
    if (included != null && included.isAfter(last)) {
      last = included;
    }
    return (first: first, last: last);
  }
}
