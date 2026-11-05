import 'package:flutter_test/flutter_test.dart';
import 'package:quill_diary/presentation/diary_organization/organization_draft_editor.dart';

void main() {
  test('保護區段不可修改，邊界新增文字可正確還原為代號', () {
    final controller = OrganizationDraftTextController('甲⟦S01⟧乙', {
      '⟦S01⟧': '秘密',
    });
    addTearDown(controller.dispose);
    expect(controller.text, '甲秘密乙');
    final rejected = controller.protectEdit(
      controller.value,
      const TextEditingValue(text: '甲密乙'),
    );
    expect(rejected.text, '甲秘密乙');
    controller.value = controller.protectEdit(
      controller.value,
      const TextEditingValue(text: '甲新秘密乙'),
    );
    expect(controller.protectedBody, '甲新⟦S01⟧乙');
    controller.value = controller.protectEdit(
      controller.value,
      const TextEditingValue(text: '甲新秘密增乙'),
    );
    expect(controller.protectedBody, '甲新⟦S01⟧增乙');
  });

  test('同一人物代號的不同寫法依出現順序顯示，編輯後仍共用代號', () {
    final controller = OrganizationDraftTextController(
      '⟦P01⟧與⟦P01⟧',
      {'⟦P01⟧': '小明'},
      surfaces: {
        '⟦P01⟧': ['小明', '王小明'],
      },
    );
    addTearDown(controller.dispose);
    expect(controller.text, '小明與王小明');
    controller.value = controller.protectEdit(
      controller.value,
      const TextEditingValue(text: '小明與王小明後來'),
    );
    expect(controller.protectedBody, '⟦P01⟧與⟦P01⟧後來');
  });

  test('相鄰保護區段不合併代號，原文相同的普通文字仍可修改', () {
    final controller = OrganizationDraftTextController('⟦S01⟧⟦S02⟧秘密', {
      '⟦S01⟧': '秘密',
      '⟦S02⟧': '姓名',
    });
    addTearDown(controller.dispose);
    controller.value = controller.protectEdit(
      controller.value,
      const TextEditingValue(text: '秘密姓名公開'),
    );
    expect(controller.protectedBody, '⟦S01⟧⟦S02⟧公開');
  });
}
