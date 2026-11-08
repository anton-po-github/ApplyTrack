import 'dart:async';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_follow_up.dart';
import 'package:apply_track/features/proposals/domain/proposal_link.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_status_flow.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/ui/proposal_formatters.dart';
import 'package:apply_track/features/proposals/ui/proposal_status_chip.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One proposal: all fields, the quick "next stage" action, edit and delete.
///
/// - The proposal is loaded with `GET /api/proposals/{id}`, so the screen
///   also works after a web refresh. The server answer is the truth.
/// - Status change and delete go through the list controller, so the list
///   and the stats stay in sync.
/// - [proposalId] must be a valid GUID. The router checks it.
class ProposalDetailScreen extends ConsumerStatefulWidget {
  const new({required this.proposalId, super.key});

  final String proposalId;

  @override
  ConsumerState<ProposalDetailScreen> createState() =>
      _ProposalDetailScreenState();
}

class _ProposalDetailScreenState extends ConsumerState<ProposalDetailScreen> {
  Proposal? _proposal;
  ApiError? _loadError;
  bool _loading = true;

  /// The server says this proposal does not exist (any more).
  bool _gone = false;

  /// A status change or a delete runs. Blocks double taps. The flag is set
  /// before the first `await`, so two fast taps cannot both pass.
  bool _busy = false;

  String? _banner;

  /// Grows with every load. An old slow answer never replaces a newer one.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_fetch());
  }

  // ----------------------------------------------------------------- load

  Future<void> _fetch() async {
    final request = ++_request;
    final result = await ref.read(proposalsApiProvider).get(widget.proposalId);
    if (!mounted || request != _request) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case ApiOk<Proposal>(:final Proposal value):
          _proposal = value;
          _loadError = null;
          _gone = false;
        case ApiErr<Proposal>(:final ApiError error):
          if (error.code == ApiErrorCodes.notFound) {
            _gone = true;
          } else if (_proposal == null) {
            // With old data on screen, a failed reload is not shown.
            _loadError = error;
          }
      }
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    unawaited(_fetch());
  }

  // ----------------------------------------------------------- navigation

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _edit() async {
    if (_busy) {
      return;
    }
    await context.push<Object?>(AppRoutes.proposalEdit(widget.proposalId));
    if (!mounted) {
      return;
    }
    // The form saved through the list controller. The server copy is the
    // truth, so we read it again.
    unawaited(_fetch());
  }

  // ----------------------------------------------------------- status flow

  Future<void> _advance(ProposalStatus next) async {
    final current = _proposal;
    if (current == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _banner = null;
    });
    // PUT is a full replace: send all fields, change only the status.
    final result = await ref
        .read(proposalListProvider.notifier)
        .update(
          widget.proposalId,
          ProposalDraft.fromProposal(current).withStatus(next),
        );
    if (!mounted) {
      return;
    }
    switch (result) {
      case ApiOk<Proposal>(:final Proposal value):
        _request++; // A load that is still running is outdated now.
        setState(() {
          _proposal = value;
          _busy = false;
        });
      case ApiErr<Proposal>(:final ApiError error):
        _showFailure(error);
    }
  }

  // --------------------------------------------------------------- delete

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete proposal?'),
        content: const Text('This proposal will be removed from your list.'),
        actions: <Widget>[
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete() async {
    if (_busy) {
      return;
    }
    final confirmed = await _confirmDelete();
    if (!confirmed || !mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _banner = null;
    });
    final result = await ref
        .read(proposalListProvider.notifier)
        .delete(widget.proposalId);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ApiOk<void>():
        _leaveAfterDelete(messenger, 'Proposal deleted.');
      // Not found means it is already gone. That is what the user wanted.
      case ApiErr<void>(:final ApiError error)
          when error.code == ApiErrorCodes.notFound:
        _leaveAfterDelete(messenger, 'This proposal was already deleted.');
      case ApiErr<void>(:final ApiError error):
        _showFailure(error);
    }
  }

  void _leaveAfterDelete(ScaffoldMessengerState messenger, String message) {
    _leave();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  // ----------------------------------------------------------------- link

  Future<void> _openLink(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref.read(externalLinkOpenerProvider).open(uri);
    if (!opened && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the link.')),
      );
    }
  }

  // --------------------------------------------------------------- errors

  void _showFailure(ApiError error) {
    setState(() {
      _busy = false;
      if (error.code == ApiErrorCodes.notFound) {
        _gone = true;
      } else {
        _banner = _messageFor(error);
      }
    });
  }

  /// A full PUT can fail the checks if the saved data is not valid. The
  /// detail screen has no inputs, so we send the user to the form.
  String _messageFor(ApiError error) {
    final fields = error.fields;
    if (error.code == ApiErrorCodes.validation &&
        fields != null &&
        fields.isNotEmpty) {
      return 'Some saved data is not valid. '
          'Open Edit to fix it: ${fields.values.join(' ')}';
    }
    return apiErrorMessage(error);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final canAct = _proposal != null && !_gone;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proposal'),
        actions: <Widget>[
          if (canAct) ...<Widget>[
            IconButton(
              key: const Key('detail-edit'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _edit,
            ),
            IconButton(
              key: const Key('detail-delete'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
          ],
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_gone) {
      return _Message(
        key: const Key('detail-not-found'),
        text: 'Proposal not found.',
        buttonLabel: 'Back',
        onPressed: _leave,
      );
    }
    final proposal = _proposal;
    if (proposal != null) {
      return _Details(
        proposal: proposal,
        today: CalendarDate.fromDateTime(ref.read(clockProvider)()),
        busy: _busy,
        banner: _banner,
        onAdvance: _advance,
        onOpenLink: _openLink,
      );
    }
    final error = _loadError;
    if (_loading || error == null) {
      return const Center(
        child: CircularProgressIndicator(key: Key('detail-loading')),
      );
    }
    return _Message(
      key: const Key('detail-load-error'),
      text: apiErrorMessage(error),
      buttonLabel: 'Retry',
      onPressed: _retry,
    );
  }
}

/// Shown for a missing field.
const String _empty = '\u2014';

class _Details extends StatelessWidget {
  const new({
    required this.proposal,
    required this.today,
    required this.busy,
    required this.banner,
    required this.onAdvance,
    required this.onOpenLink,
  });

  final Proposal proposal;
  final CalendarDate today;
  final bool busy;
  final String? banner;
  final ValueChanged<ProposalStatus> onAdvance;
  final ValueChanged<Uri> onOpenLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = banner;
    final budget = proposal.budget;
    final next = ProposalStatusFlow.next(proposal.status);

    return MaxContentWidth(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: <Widget>[
            if (busy) const LinearProgressIndicator(key: Key('detail-busy')),
            if (message != null) _ErrorBanner(message: message),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    proposal.title,
                    key: const Key('detail-title'),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(width: 8),
                ProposalStatusChip(
                  key: const Key('detail-status'),
                  status: proposal.status,
                ),
              ],
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: <Widget>[
                    _Field(
                      label: 'Company',
                      child: _valueText('detail-company', proposal.company),
                    ),
                    _Field(
                      label: 'Platform',
                      child: _valueText(
                        'detail-platform',
                        proposal.platform.label,
                      ),
                    ),
                    _Field(
                      label: 'Budget',
                      child: _valueText(
                        'detail-budget',
                        budget == null ? null : formatBudget(budget),
                      ),
                    ),
                    _Field(label: 'Follow-up date', child: _followUp(context)),
                    _Field(label: 'Link', child: _link(context)),
                    _Field(
                      label: 'Notes',
                      child: _valueText('detail-notes', proposal.notes),
                    ),
                    _Field(
                      label: 'Created',
                      child: _valueText(
                        'detail-created',
                        formatCalendarDate(
                          CalendarDate.fromDateTime(proposal.createdAt),
                        ),
                      ),
                    ),
                    _Field(
                      label: 'Updated',
                      child: _valueText(
                        'detail-updated',
                        formatCalendarDate(
                          CalendarDate.fromDateTime(proposal.updatedAt),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (next.isNotEmpty)
              _NextStage(options: next, enabled: !busy, onSelected: onAdvance),
          ],
        ),
      ),
    );
  }

  static Widget _valueText(String key, String? value) =>
      Text(value ?? _empty, key: Key(key));

  Widget _followUp(BuildContext context) {
    final date = proposal.followUpDate;
    if (date == null) {
      return _valueText('detail-follow-up', null);
    }
    final due = proposal.isFollowUpDue(today);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (due) ...<Widget>[
          Tooltip(
            message: 'Follow-up is due',
            child: Icon(
              Icons.warning_amber_rounded,
              key: const Key('detail-follow-up-due'),
              size: 18,
              color: scheme.error,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            formatCalendarDate(date),
            key: const Key('detail-follow-up'),
            style: due ? TextStyle(color: scheme.error) : null,
          ),
        ),
      ],
    );
  }

  /// Only a safe `http` or `https` link can be tapped. Any other text is
  /// shown as plain text and is never opened.
  Widget _link(BuildContext context) {
    final link = proposal.link;
    if (link == null) {
      return _valueText('detail-link-text', null);
    }
    final uri = ProposalLink.tryParse(link);
    if (uri == null) {
      return _valueText('detail-link-text', link);
    }
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('detail-link'),
      onTap: () => onOpenLink(uri),
      child: Text(
        link,
        style: TextStyle(
          color: scheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const new({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 2,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        child,
      ],
    );
  }
}

class _NextStage extends StatelessWidget {
  const new({
    required this.options,
    required this.enabled,
    required this.onSelected,
  });

  final List<ProposalStatus> options;
  final bool enabled;
  final ValueChanged<ProposalStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: <Widget>[
        Text('Next stage', style: Theme.of(context).textTheme.titleSmall),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final ProposalStatus status in options)
              FilledButton(
                key: ValueKey<String>('advance-${status.name}'),
                onPressed: enabled ? () => onSelected(status) : null,
                child: Text('Mark as ${status.label}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const new({
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
  });

  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('detail-error-banner'),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
