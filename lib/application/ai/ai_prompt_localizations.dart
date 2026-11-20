import 'package:quill_diary/domain/shared/privacy_tokens.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/l10n/l10n.dart';

extension AiPromptLocalizations on AppLocalizations {
  String get chatDiaryConversationRules => chatDiaryConversationRulesPrompt(
    privacyTokenExample(PrivacyTokenKind.person),
    privacyTokenExample(PrivacyTokenKind.private),
  );
  String get chatDiaryGenerationRules => chatDiaryGenerationRulesPrompt(
    privacyTokenExample(PrivacyTokenKind.person),
    privacyTokenExample(PrivacyTokenKind.private),
  );
  String get organizationRules => organizationRulesPrompt(
    privacyTokenExample(PrivacyTokenKind.person),
    privacyTokenExample(PrivacyTokenKind.private),
  );
  String personaOutputRules(int memoryLimit, int toneLimit) =>
      personaOutputPrompt(
        memoryLimit,
        toneLimit,
        privacyTokenExample(PrivacyTokenKind.person),
        privacyTokenExample(PrivacyTokenKind.private),
      );
  String get personaExtractionRules => personaExtractionPrompt(
    privacyTokenExample(PrivacyTokenKind.person),
    privacyTokenExample(PrivacyTokenKind.private),
    PersonaLimits.evidenceCodeUnits,
  );
}
