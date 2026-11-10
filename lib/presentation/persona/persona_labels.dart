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
