import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_follow_up.dart';
import 'package:apply_track/features/proposals/ui/proposal_formatters.dart';
import 'package:apply_track/features/proposals/ui/proposal_status_chip.dart';
import 'package:material_ui/material_ui.dart';

/// One row of the list. [today] comes from the caller, so the card is easy
/// to test and does not read the clock itself.
class ProposalCard extends StatelessWidget {
  const new({
    required this.proposal,
    required this.today,
    required this.onTap,
    super.key,
  });

  final Proposal proposal;
  final CalendarDate today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final company = proposal.company;
    final budget = proposal.budget;
    final followUp = proposal.followUpDate;
    final due = proposal.isFollowUpDue(today);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      proposal.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ProposalStatusChip(status: proposal.status),
                ],
              ),
              if (company != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  company,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: <Widget>[
                  _Meta(icon: Icons.public, text: proposal.platform.label),
                  if (budget != null)
                    _Meta(
                      icon: Icons.payments_outlined,
                      text: formatBudget(budget),
                    ),
                  if (followUp != null)
                    _Meta(
                      icon: due ? Icons.warning_amber_rounded : Icons.event,
                      iconKey: due
                          ? ValueKey<String>('follow-up-due-${proposal.id}')
                          : null,
                      tooltip: due ? 'Follow-up is due' : null,
                      color: due ? theme.colorScheme.error : null,
                      text: 'Follow-up ${formatCalendarDate(followUp)}',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    this.iconKey,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final String text;
  final Key? iconKey;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    Widget iconWidget = Icon(icon, key: iconKey, size: 16, color: color);
    if (tooltip != null) {
      iconWidget = Tooltip(message: tooltip, child: iconWidget);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        iconWidget,
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
