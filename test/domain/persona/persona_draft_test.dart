import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/domain/persona/persona.dart';

import '../../helpers/persona/persona_fixtures.dart';

void main() {
  test('草稿保存獨立的舊卡帶入選擇，缺少舊欄位時不自動帶入', () {
    final draft = personaDraftRecord('vault', 'per_test').draft!;
    draft.includeCurrent.addAll({
      PersonaCardKind.memory: true,
      PersonaCardKind.tone: false,
    });
    final loaded = PersonaDraft.fromJson(draft.toJson());
    expect(loaded.includeCurrent, draft.includeCurrent);
    final previous = draft.toJson()..remove('include_current');
    expect(PersonaDraft.fromJson(previous).includeCurrent, isEmpty);
  });

  test('已提供的帶入選項型別錯誤或超出目標時拒絕', () {
    final draft = PersonaDraft(
      target: PersonaUpdateTarget.memory,
      baseUpdatedAt: {PersonaCardKind.memory: null},
    );
    expect(
      () => PersonaDraft.fromJson({
        ...draft.toJson(),
        'include_current': {'memory': 'true'},
      }),
      throwsA(isA<TypeError>()),
    );
    final invalid = PersonaDraft.fromJson({
      ...draft.toJson(),
      'include_current': {'tone': true},
    });
    expect(invalid.validate, throwsFormatException);
  });
}
