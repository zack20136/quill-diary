String userFacingErrorMessage(Object error, {String fallback = '操作失敗，請稍後再試。'}) {
  if (error is StateError) {
    final String message = error.message.trim();
    if (message.isNotEmpty) {
      return stripLocalPathsFromMessage(message);
    }
  }
  if (error is FormatException && error.message.isNotEmpty) {
    return stripLocalPathsFromMessage(error.message);
  }
  return fallback;
}

String stripLocalPathsFromMessage(String message) {
  return message.replaceAll(RegExp(r'[A-Za-z]:[\\/][^\s，。；：,;:]+'), '本機檔案');
}
