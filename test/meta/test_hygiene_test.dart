import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// 守門測試：擋下「為了釘住目錄預設值或文案」的斷言，規則與理由見 test/test-handbook.md。
// 這是啟發式掃描，只看單一 expect 陳述式內的寫法；被擋下時先改寫成行為斷言，
// 確實需要例外時在 _allowedViolations 加上附理由的項目。

enum HygieneRule {
  catalogDefaultPin('預設模型不要寫死模型 ID，改由 defaultConnection 等行為斷言驗證'),
  catalogListPin('完整模型清單會隨目錄變動，改驗相對順序或屬性'),
  copyPin('斷言內容與 ARB 文案相同，文案修改就會失效，改用 ARB 欄位參照或行為斷言');

  const HygieneRule(this.advice);

  final String advice;
}

final class HygieneViolation {
  const HygieneViolation(this.path, this.line, this.rule);

  final String path;
  final int line;
  final HygieneRule rule;

  @override
  String toString() => '$path:$line [${rule.name}] ${rule.advice}';
}

// 寫死的目錄模型 ID，例如 'gpt-6.1-terra'、'claude-haiku-5-5'。
final RegExp _catalogModelLiteral = RegExp(
  r'''["'](?:gpt|claude|gemini|grok)-[^"'\n]*["']''',
);

// 會讀取目錄預設值的入口。
final RegExp _defaultAccessor = RegExp(
  r'defaultConnection\(|builtinModelsFor\(|aiModelCatalog|defaultThinking|enabledByDefault',
);

final RegExp _expectStatement = RegExp(r'\bexpect\([^;]*;');

final RegExp _stringLiteral = RegExp(r'''(['"])(.*?)\1''');

// 文案比對的最短長度，避免「草稿」之類的短字誤判。
const int _copyMinRunes = 12;

// 只把含中文或空白的長字串當成句子，排除 relationship id 這類英文識別字。
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');

bool _looksLikeSentence(String text) {
  return text.runes.length >= _copyMinRunes &&
      (_cjk.hasMatch(text) || text.contains(' '));
}

// 隱私代號規則是安全不變量，即使文案相同也要保留斷言。
const String _privacyTokenMarker = '{{';

List<HygieneViolation> findHygieneViolations(
  String path,
  String source, {
  required Set<String> copyPhrases,
}) {
  final List<HygieneViolation> violations = <HygieneViolation>[];
  for (final RegExpMatch match in _expectStatement.allMatches(source)) {
    final String statement = match.group(0)!;
    final int line =
        '\n'.allMatches(source.substring(0, match.start)).length + 1;
    final int catalogLiterals = _catalogModelLiteral
        .allMatches(statement)
        .length;

    if (catalogLiterals > 0 && _defaultAccessor.hasMatch(statement)) {
      violations.add(
        HygieneViolation(path, line, HygieneRule.catalogDefaultPin),
      );
    }
    if (catalogLiterals >= 3) {
      violations.add(HygieneViolation(path, line, HygieneRule.catalogListPin));
    }
    for (final RegExpMatch literal in _stringLiteral.allMatches(statement)) {
      final String text = literal.group(2)!;
      if (!_looksLikeSentence(text) || text.contains(_privacyTokenMarker)) {
        continue;
      }
      if (copyPhrases.any((String phrase) => phrase.contains(text))) {
        violations.add(HygieneViolation(path, line, HygieneRule.copyPin));
      }
    }
  }
  return violations;
}

// 目前已知的例外：key 為 "路徑:規則"，值為理由。預設為空，新增時必須附理由。
const Map<String, String> _allowedViolations = <String, String>{};

Set<String> _arbCopyPhrases() {
  final Set<String> phrases = <String>{};
  for (final String arb in <String>[
    'lib/l10n/app_zh.arb',
    'lib/l10n/app_en.arb',
  ]) {
    final Map<String, Object?> entries =
        jsonDecode(File(arb).readAsStringSync()) as Map<String, Object?>;
    for (final MapEntry<String, Object?> entry in entries.entries) {
      final Object? value = entry.value;
      if (!entry.key.startsWith('@') && value is String) {
        phrases.add(value);
      }
    }
  }
  return phrases;
}

Iterable<File> _testFiles() {
  return Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('_test.dart'))
      .where((File file) {
        final String normalized = file.path.replaceAll('\\', '/');
        return !normalized.startsWith('test/meta/');
      });
}

void main() {
  test('測試檔不寫死目錄預設值、完整模型清單或 ARB 文案', () {
    final Set<String> copyPhrases = _arbCopyPhrases();
    final List<String> failures = <String>[];
    for (final File file in _testFiles()) {
      final String path = file.path.replaceAll('\\', '/');
      final List<HygieneViolation> violations = findHygieneViolations(
        path,
        file.readAsStringSync(),
        copyPhrases: copyPhrases,
      );
      for (final HygieneViolation violation in violations) {
        final String key = '$path:${violation.rule.name}';
        if (_allowedViolations.containsKey(key)) {
          continue;
        }
        failures.add(violation.toString());
      }
    }

    expect(
      failures,
      isEmpty,
      reason: '請改寫成行為斷言，或在 _allowedViolations 附理由。\n${failures.join('\n')}',
    );
  });

  group('守門規則會擋下違規寫法', () {
    const Set<String> phrases = <String>{'預設使用繁體中文、台灣常用詞與自然標點'};

    test('寫死預設模型 ID 會被擋', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        "expect(defaultConnection(AiProvider.claude).model, 'claude-haiku-5-5');",
        copyPhrases: phrases,
      );

      expect(violations.map((HygieneViolation v) => v.rule), <HygieneRule>[
        HygieneRule.catalogDefaultPin,
      ]);
    });

    test('完整模型清單會被擋', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        "expect(order, ['gpt-6.1-terra', 'gpt-6.1-sol', 'gpt-6-luna']);",
        copyPhrases: phrases,
      );

      expect(
        violations.map((HygieneViolation v) => v.rule),
        contains(HygieneRule.catalogListPin),
      );
    });

    test('斷言內容與 ARB 文案相同會被擋', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        "expect(prompt, contains('預設使用繁體中文、台灣常用詞與自然標點'));",
        copyPhrases: phrases,
      );

      expect(violations.map((HygieneViolation v) => v.rule), <HygieneRule>[
        HygieneRule.copyPin,
      ]);
    });

    test('多行 expect 同樣會被擋並回報起始行號', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        'void f() {\n  expect(\n    prompt,\n    startsWith(\'預設使用繁體中文、台灣常用詞與自然標點\'),\n  );\n}',
        copyPhrases: phrases,
      );

      expect(violations, hasLength(1));
      expect(violations.single.line, 2);
    });
  });

  group('守門規則不誤擋合理寫法', () {
    const Set<String> phrases = <String>{'預設使用繁體中文、台灣常用詞與自然標點'};

    test('行為斷言與短字串不擋', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        [
          "expect(next.model, 'gpt-6.1-sol');",
          'expect(menu.models.single.modelId, openai.model);',
          "expect(page.body, contains('草稿'));",
          'expect(enChat, contains(en.chatDiaryConversationRulesPrompt));',
        ].join('\n'),
        copyPhrases: phrases,
      );

      expect(violations, isEmpty);
    });

    test('測試資料中的長句不擋（不是 ARB 文案）', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        "expect(body, contains('今天跟小明一起去北海道玩很開心'));",
        copyPhrases: phrases,
      );

      expect(violations, isEmpty);
    });

    test('隱私代號規則的整句保留斷言', () {
      final List<HygieneViolation> violations = findHygieneViolations(
        'fake_test.dart',
        "expect(zhChat, contains('同一個 {{PER…}} 代號代表同一位人物'));",
        copyPhrases: <String>{'同一個 {{PER…}} 代號代表同一位人物'},
      );

      expect(violations, isEmpty);
    });
  });
}
