import '../../infrastructure/ai/ai_client.dart';
import '../../l10n/app_localizations.dart';

String aiErrorText(AppLocalizations l10n, AiErrorCode code) => switch (code) {
  AiErrorCode.configuration => l10n.aiErrorConfiguration,
  AiErrorCode.endpoint => l10n.aiErrorEndpoint,
  AiErrorCode.authentication => l10n.aiErrorAuthentication,
  AiErrorCode.quota => l10n.aiErrorQuota,
  AiErrorCode.request => l10n.aiErrorRequest,
  AiErrorCode.network => l10n.aiErrorNetwork,
  AiErrorCode.timeout => l10n.aiErrorTimeout,
  AiErrorCode.tls => l10n.aiErrorTls,
  AiErrorCode.response => l10n.aiErrorResponse,
  AiErrorCode.image => l10n.aiErrorImage,
  AiErrorCode.imageUnsupported => l10n.aiErrorImageUnsupported,
  AiErrorCode.storage => l10n.aiErrorStorage,
  AiErrorCode.unavailable => l10n.aiErrorUnavailable,
  AiErrorCode.unreadable => l10n.aiErrorUnreadable,
};
