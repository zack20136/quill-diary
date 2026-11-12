import 'package:material_ui/material_ui.dart';
import 'package:quill_diary/shared/presentation/widgets/app_surface.dart';

class PersonDetailSectionCard extends StatelessWidget {
  const PersonDetailSectionCard({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppSectionHeader(title: title, trailing: trailing),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
