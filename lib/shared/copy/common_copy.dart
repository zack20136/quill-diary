import '../../l10n/l10n.dart';

/// 跨功能共用的繁體中文 UI 文案。
abstract final class CommonCopy {
  static AppLocalizations _l10n(BuildContext context) => context.l10n;

  static String actionCancel(BuildContext context) => _l10n(context).commonActionCancel;
  static String actionDelete(BuildContext context) => _l10n(context).commonActionDelete;
  static String actionApply(BuildContext context) => _l10n(context).commonActionApply;
  static String actionClose(BuildContext context) => _l10n(context).commonActionClose;

  static String readFailureTitle(BuildContext context) => _l10n(context).commonReadFailureTitle;
  static String confirmDeleteTitle(BuildContext context) => _l10n(context).commonConfirmDeleteTitle;
  static String noTagSearchResults(BuildContext context) => _l10n(context).commonNoTagSearchResults;

  static String closeTooltip(BuildContext context) => _l10n(context).commonCloseTooltip;
  static String clearSearchTooltip(BuildContext context) => _l10n(context).commonClearSearchTooltip;

  static String confirmDeleteEntries(BuildContext context, int count) =>
      _l10n(context).commonConfirmDeleteEntries(count);
}
