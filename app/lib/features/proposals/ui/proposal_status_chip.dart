import 'package:material_ui/material_ui.dart';

import 'package:apply_track/features/proposals/domain/proposal_status.dart';

/// The coloured status label. Used by the list card and the detail screen.
class ProposalStatusChip extends StatelessWidget {
  const ProposalStatusChip({super.key, required this.status});

  final ProposalStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      ProposalStatus.won => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ProposalStatus.lost => (scheme.errorContainer, scheme.onErrorContainer),
      ProposalStatus.draft => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
