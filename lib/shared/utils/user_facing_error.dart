import '../../l10n/l10n.dart';
import 'package:flutter/foundation.dart';

abstract interface class LocalizedUserFacingError {
  String localizedMessage(AppLocalizations l10n);
}

String userFacingErrorMessage(
  Object error, {
  required AppLocalizations l10n,
  String? fallback,
}) {
  if (error is LocalizedUserFacingError) {
    return error.localizedMessage(l10n);
  }
  debugPrint('Unclassified user-facing error: $error');
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
