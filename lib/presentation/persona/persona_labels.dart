import 'package:quill_diary/application/persona/persona_controller.dart';
import 'package:quill_diary/domain/persona/persona.dart';
import 'package:quill_diary/l10n/app_localizations.dart';

String personaCardLabel(AppLocalizations l10n, PersonaCardKind kind) =>
    kind == PersonaCardKind.memory ? l10n.personaMemory : l10n.personaTone;

String personaStepLabel(AppLocalizations l10n, PersonaStep step) =>
    switch (step) {
      PersonaStep.materials => l10n.personaMaterials,
      PersonaStep.confirmation => l10n.personaConfirmation,
      PersonaStep.review => l10n.personaReview,
    };

String personaGenerationPhaseLabel(
  AppLocalizations l10n,
  PersonaGenerationPhase? phase,
) => switch (phase) {
  PersonaGenerationPhase.extracting => l10n.personaExtractingActive,
  PersonaGenerationPhase.reducing => l10n.personaReducingActive,
  PersonaGenerationPhase.integrating => l10n.personaIntegratingActive,
  PersonaGenerationPhase.compacting => l10n.personaCompactingActive,
  null => l10n.personaProcessing,
};
