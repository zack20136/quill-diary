import '../../l10n/l10n.dart';

String userFacingErrorMessage(
  Object error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
  if (error is StateError) {
    final String message = error.message.trim();
    if (message.isNotEmpty) {
      return stripLocalPathsFromMessage(message, l10n: l10n);
    }
  }
  if (error is FormatException && error.message.isNotEmpty) {
    return stripLocalPathsFromMessage(error.message, l10n: l10n);
  }
  return fallback ?? l10n.userFacingErrorDefaultMessage;
}

String stripLocalPathsFromMessage(
  String message, {
  required AppLocalizations l10n,
}) {
  final String maskedWindows = message.replaceAllMapped(
    RegExp(
      r'''(^|[\s([{<"':：；，。！？「『])([A-Za-z]:[\\/][^\s)\]}>,"'`：；，。！？「』】）]+)''',
    ),
    (Match match) => '${match.group(1)}${l10n.userFacingErrorLocalPathLabel}',
  );
  return maskedWindows.replaceAllMapped(
    RegExp(
      r'''(^|[\s([{<"':：；，。！？「『])(/(?:[^/\s]+/)+[^/\s/)\]}>,"'`：；，。！？「』】）]+/?)''',
    ),
    (Match match) => '${match.group(1)}${l10n.userFacingErrorLocalPathLabel}',
  );
}
