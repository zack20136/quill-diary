import 'dart:isolate';

import 'package:quill_diary/domain/ai/private_text.dart';
import 'package:quill_diary/domain/shared/privacy_tokens.dart';

final _email = RegExp(
  r'[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]{1,64}@[A-Za-z0-9-]{1,63}(?:\.[A-Za-z0-9-]{1,63}){1,10}',
);
final _mobile = RegExp(
  r'(?<![0-9])(?:09[0-9]{2}|\+886[ -]?9[0-9]{2})[ -]?[0-9]{3}[ -]?[0-9]{3}(?![0-9])',
);
final _landline = RegExp(
  r'(?<![0-9])(?:0|\+886[ -]?)(?:[2-8][ -]?[0-9]{3,4}[ -]?[0-9]{4}|(?:37|49|82|89)[ -]?[0-9]{3,4}[ -]?[0-9]{3}|836[ -]?[0-9]{3}[ -]?[0-9]{2})(?:[ \t]?(?:#|ext\.?|分機)[ \t]?[0-9]{1,6})?(?![0-9])',
  caseSensitive: false,
);
final _identity = RegExp(
  r'(?<![A-Za-z0-9])[A-Za-z][12][0-9]{8}(?![A-Za-z0-9])',
);
final _card = RegExp(
  r'(?<![0-9])(?:[0-9]{13,19}|[0-9]{4}(?:[ -][0-9]{4}){2}[ -][0-9]{1,7}|[0-9]{4}[ -][0-9]{6}[ -][0-9]{5})(?![0-9])',
);
final _credential = RegExp(
  r'(?<![A-Za-z0-9_])(?:sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AIza[A-Za-z0-9_-]{35})(?![A-Za-z0-9_-])',
);
const _credentialName =
    r'(?:api[_ -]?key|access[_ -]?token|secret|password|密碼|金鑰)';
final _credentialField = RegExp('^$_credentialName\$', caseSensitive: false);
bool isCredentialField(String? field) =>
    field != null && _credentialField.hasMatch(field);

final _labelledCredential = RegExp(
  '$_credentialName${r'\s{0,8}[:=：]\s{0,8}["\x27]?([^\s"\x27,;，；<>\[\]{}]{4,})'}',
  caseSensitive: false,
);
final _privateKeyStart = RegExp(
  r'-----BEGIN ((?:RSA |EC |OPENSSH )?PRIVATE KEY)-----',
);

bool _validIdentity(String value) {
  const letters = 'ABCDEFGHJKLMNPQRSTUVXYWZIO';
  final code = letters.indexOf(value[0].toUpperCase()) + 10;
  if (code < 10) return false;
  var sum = code ~/ 10 + code % 10 * 9;
  for (var i = 1; i < 9; i++) {
    sum += int.parse(value[i]) * (9 - i);
  }
  return (sum + int.parse(value[9])) % 10 == 0;
}

bool _validCard(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 13 ||
      digits.length > 19 ||
      digits.split('').toSet().length == 1) {
    return false;
  }
  var sum = 0;
  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = int.parse(digits[i]);
    if ((digits.length - 1 - i).isOdd) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    sum += digit;
  }
  return sum % 10 == 0;
}

/// 所有座標都以原文計算；一次掃完才合併替換，避免規則互相改寫輸入。
List<PrivateTextRange> detectSensitiveText(String text) {
  final spans = <PrivateTextRange>[];
  final protected = privacyTokenPattern.allMatches(text).toList();
  void scan(RegExp pattern, {bool Function(String)? validate, int group = 0}) {
    for (final match in pattern.allMatches(text)) {
      final value = match[group]!;
      if (validate != null && !validate(value)) continue;
      final start = group == 0 ? match.start : match.end - value.length;
      final end = start + value.length;
      if (protected.any((token) => start < token.end && end > token.start)) {
        continue;
      }
      spans.add(PrivateTextRange(start, end));
    }
  }

  scan(_email);
  scan(_mobile);
  scan(_landline);
  scan(_identity, validate: _validIdentity);
  scan(_card, validate: _validCard);
  scan(_credential);
  scan(_labelledCredential, group: 1);
  var keyCursor = 0;
  while (keyCursor < text.length) {
    final start = _privateKeyStart.allMatches(text, keyCursor).firstOrNull;
    if (start == null) break;
    final offset = start.start;
    final ending = '-----END ${start[1]}-----';
    final end = text.indexOf(ending, offset + start[0]!.length);
    final limit = end < 0 ? text.length : end + ending.length;
    spans.add(PrivateTextRange(offset, limit));
    keyCursor = limit;
  }
  return mergePrivateRanges(spans, text.length);
}

Future<List<PrivateTextRange>> detectSensitiveTextInBackground(String text) =>
    Isolate.run(() => detectSensitiveText(text));
