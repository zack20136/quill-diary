final privacyTokenPattern = RegExp(r'⟦[PS][0-9A-F]{2,}⟧');

String nextPrivacyToken(
  Iterable<String> tokens, {
  String prefix = 'S',
  String reservedText = '',
}) {
  var next = 1;
  final pattern = RegExp('^⟦$prefix([0-9A-F]{2,})⟧\$');
  for (final token in tokens) {
    final match = pattern.firstMatch(token);
    if (match == null) continue;
    final number = int.parse(match[1]!, radix: 16);
    if (number >= next) next = number + 1;
  }
  while (true) {
    final number = next.toRadixString(16).toUpperCase().padLeft(2, '0');
    final token = '⟦$prefix$number⟧';
    if (!reservedText.contains(token)) return token;
    next++;
  }
}

/// 同一人物回傳既有 P 代號。新人物才分配代號，對照表只留第一次的寫法。
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
    prefix: 'P',
    reservedText: reservedText,
  );
  tokenByPersonId[personId] = token;
  originals[token] = surface;
  return token;
}
