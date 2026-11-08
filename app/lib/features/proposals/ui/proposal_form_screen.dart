import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:apply_track/features/proposals/ui/proposal_form.dart';
import 'package:apply_track/router/app_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// One screen for both modes.
/// - [proposalId] is null: a new, empty proposal.
/// - [proposalId] is set: the proposal is loaded with `GET /api/proposals/{id}`
///   (so it also works after a web refresh) and then edited.
class ProposalFormScreen extends ConsumerStatefulWidget {
  const new({super.key, this.proposalId});

  final String? proposalId;

  @override
  ConsumerState<ProposalFormScreen> createState() => _ProposalFormScreenState();
}

class _ProposalFormScreenState extends ConsumerState<ProposalFormScreen> {
  Future<ApiResult<Proposal>>? _load;

  bool get _isEdit => widget.proposalId != null;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad() {
    final id = widget.proposalId;
    _load = id == null ? null : ref.read(proposalsApiProvider).get(id);
  }

  void _retry() => setState(_startLoad);

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit proposal' : 'New proposal')),
      body: _body(),
    );
  }

  Widget _body() {
    final load = _load;
    if (load == null) {
      return const ProposalForm(
        key: ValueKey<String>('new'),
        initial: ProposalDraft.empty(),
      );
    }
    return FutureBuilder<ApiResult<Proposal>>(
      future: load,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(key: Key('form-loading')),
          );
        }
        final result = snapshot.data;
        switch (result) {
          case ApiOk<Proposal>(:final Proposal value):
            return ProposalForm(
              key: ValueKey<String>(value.id),
              initial: ProposalDraft.fromProposal(value),
              proposalId: value.id,
            );
          case ApiErr<Proposal>(:final ApiError error)
              when error.code == ApiErrorCodes.notFound:
            return _Message(
              key: const Key('form-not-found'),
              text: 'Proposal not found.',
              buttonLabel: 'Back',
              onPressed: _leave,
            );
          case ApiErr<Proposal>(:final ApiError error):
            return _Message(
              key: const Key('form-load-error'),
              text: apiErrorMessage(error),
              buttonLabel: 'Retry',
              onPressed: _retry,
            );
          case null:
            return _Message(
              key: const Key('form-load-error'),
              text: 'Something went wrong.',
              buttonLabel: 'Retry',
              onPressed: _retry,
            );
        }
      },
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
