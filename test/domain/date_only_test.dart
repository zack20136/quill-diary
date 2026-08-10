import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/shared/value_objects.dart';

void main() {
  test('DateOnly.tryParse 嚴格拒絕溢位日期', () {
    expect(DateOnly.tryParse('2026-02-28')?.value, '2026-02-28');
    expect(DateOnly.tryParse('2026-02-30'), isNull);
    expect(DateOnly.tryParse('2026-2-03'), isNull);
  });
}
