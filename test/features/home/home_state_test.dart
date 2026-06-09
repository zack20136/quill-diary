import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/features/home/state/home_state.dart';

void main() {
  test('memory scope defaults to month', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(memoryScopeProvider), MemoryScope.month);
  });
}
