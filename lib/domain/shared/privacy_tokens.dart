final privacyTokenPattern = RegExp(r'\{\{(?:PER|PRI)_[0-9A-F]{2,}\}\}');

enum PrivacyTokenKind { person, private }

class PrivacyToken {
  const PrivacyToken(this.kind, this.number);

  factory PrivacyToken.parse(String stored) {
    if (privacyTokenPattern.stringMatch(stored) != stored) {
      throw const FormatException('無效的保護代號');
    }
    final body = stored.substring(2, stored.length - 2);
    return PrivacyToken(
      body.startsWith('PER_')
          ? PrivacyTokenKind.person
          : PrivacyTokenKind.private,
      int.parse(body.substring(4), radix: 16),
    );
  }

  final PrivacyTokenKind kind;
  final int number;

  String get label => kind == PrivacyTokenKind.person ? 'PER' : 'PRI';

  String format() {
    final hex = number.toRadixString(16).toUpperCase().padLeft(2, '0');
    return '{{${label}_$hex}}';
  }
}

bool privacyTokenHasKind(String token, PrivacyTokenKind kind) =>
    privacyTokenPattern.stringMatch(token) == token &&
    PrivacyToken.parse(token).kind == kind;

String privacyTokenExample(PrivacyTokenKind kind) =>
    '{{${kind == PrivacyTokenKind.person ? 'PER' : 'PRI'}_NN}}';

String nextPrivacyToken(
  Iterable<String> tokens, {
  PrivacyTokenKind kind = PrivacyTokenKind.private,
  String reservedText = '',
}) {
  final label = kind == PrivacyTokenKind.person ? 'PER' : 'PRI';
  var next = 1;
  final pattern = RegExp('^\\{\\{${label}_([0-9A-F]{2,})\\}\\}\$');
  for (final token in tokens) {
    final match = pattern.firstMatch(token);
    if (match == null) continue;
    final number = int.parse(match[1]!, radix: 16);
    if (number >= next) next = number + 1;
  }
  while (true) {
    final token = PrivacyToken(kind, next).format();
    if (!reservedText.contains(token)) return token;
    next++;
  }
}

/// 同一人物回傳既有代號。新人物才分配代號，對照表只留第一次的寫法。
String privacyTokenForPerson({
  required String personId,
  required String surface,
  required Map<String, String> tokenByPersonId,
  required Map<String, String> originals,
  String reservedText = '',
}) {
  final existing = tokenByPersonId[personId];
  if (existing != null) return existing;
  final token = nextPrivacyToken(
    originals.keys,
    kind: PrivacyTokenKind.person,
    reservedText: reservedText,
  );
  tokenByPersonId[personId] = token;
  originals[token] = surface;
  return token;
}
