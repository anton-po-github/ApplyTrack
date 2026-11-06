import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:apply_track/core/api/api_error.dart';
import 'package:apply_track/core/api/api_error_message.dart';
import 'package:apply_track/core/api/api_result.dart';
import 'package:apply_track/core/layout/max_content_width.dart';
import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_field.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';
import 'package:apply_track/features/proposals/domain/proposal_validators.dart';
import 'package:apply_track/features/proposals/state/proposal_list_controller.dart';
import 'package:apply_track/features/proposals/ui/proposal_formatters.dart';
import 'package:apply_track/router/app_router.dart';

/// The raw values of the inputs. Used to know if the user changed anything.
final class _FormValues {
  const _FormValues({
    required this.title,
    required this.company,
    required this.budget,
    required this.link,
    required this.notes,
    required this.platform,
    required this.status,
    required this.followUp,
  });

  final String title;
  final String company;
  final String budget;
  final String link;
  final String notes;
  final ProposalPlatform platform;
  final ProposalStatus status;
  final CalendarDate? followUp;

  @override
  bool operator ==(Object other) =>
      other is _FormValues &&
      other.title == title &&
      other.company == company &&
      other.budget == budget &&
      other.link == link &&
      other.notes == notes &&
      other.platform == platform &&
      other.status == status &&
      other.followUp == followUp;

  @override
  int get hashCode => Object.hash(
    title,
    company,
    budget,
    link,
    notes,
    platform,
    status,
    followUp,
  );
}

/// The form for a new proposal ([proposalId] is null) or for an edit.
///
/// - Client checks use the Step 3 validators. The server checks again, and
///   its field errors are shown under the matching inputs.
/// - Save sends the whole object (PUT is a full replace).
/// - The list controller does the request, so the list and the stats stay
///   in sync.
class ProposalForm extends ConsumerStatefulWidget {
  const ProposalForm({super.key, required this.initial, this.proposalId});

  final ProposalDraft initial;
  final String? proposalId;

  @override
  ConsumerState<ProposalForm> createState() => _ProposalFormState();
}

class _ProposalFormState extends ConsumerState<ProposalForm> {
  static const String _limitMessage =
      'Proposal limit reached. Delete one to add a new one.';
  static const String _goneMessage =
      'This proposal was not found. It may have been deleted.';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _company;
  late final TextEditingController _budget;
  late final TextEditingController _link;
  late final TextEditingController _notes;
  late ProposalPlatform _platform;
  late ProposalStatus _status;
  CalendarDate? _followUp;
  late final _FormValues _initialValues;

  ServerFieldErrors _server = ServerFieldErrors.empty;
  String? _banner;
  bool _saving = false;

  bool get _isEdit => widget.proposalId != null;

  @override
  void initState() {
    super.initState();
    final ProposalDraft initial = widget.initial;
    final double? budget = initial.budget;
    _title = TextEditingController(text: initial.title);
    _company = TextEditingController(text: initial.company ?? '');
    _budget = TextEditingController(
      text: budget == null ? '' : formatBudgetInput(budget),
    );
    _link = TextEditingController(text: initial.link ?? '');
    _notes = TextEditingController(text: initial.notes ?? '');
    _platform = initial.platform;
    _status = initial.status;
    _followUp = initial.followUpDate;
    _initialValues = _values();
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _budget.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  _FormValues _values() => _FormValues(
    title: _title.text,
    company: _company.text,
    budget: _budget.text,
    link: _link.text,
    notes: _notes.text,
    platform: _platform,
    status: _status,
    followUp: _followUp,
  );

  bool get _isDirty => _values() != _initialValues;

  ProposalDraft _buildDraft() => ProposalDraft(
    title: _title.text,
    company: _company.text,
    platform: _platform,
    status: _status,
    budget: ProposalValidators.parseBudget(_budget.text),
    followUpDate: _followUp,
    link: _link.text,
    notes: _notes.text,
  );

  // --------------------------------------------------------------- errors

  /// The user changes [field], so the old server error for it is outdated.
  void _clearServerError(ProposalField field) {
    if (_server.byField.containsKey(field)) {
      setState(() {
        _server = ServerFieldErrors(
          byField: Map<ProposalField, String>.of(_server.byField)
            ..remove(field),
          unmapped: _server.unmapped,
        );
      });
    }
  }

  String? _serverError(ProposalField field) => _server.byField[field];

  void _showError(ApiError error) {
    final ServerFieldErrors fields = ServerFieldErrors.from(error.fields);
    final String? banner;
    if (error.code == ApiErrorCodes.proposalLimit) {
      banner = _limitMessage;
    } else if (error.code == ApiErrorCodes.notFound) {
      banner = _goneMessage;
    } else if (fields.isEmpty) {
      banner = apiErrorMessage(error);
    } else if (fields.unmapped.isNotEmpty) {
      banner = fields.unmapped.join('\n');
    } else {
      banner = null;
    }
    setState(() {
      _saving = false;
      _server = fields;
      _banner = banner;
    });
    // Runs the validators again, so the server messages show up.
    _formKey.currentState?.validate();
  }

  // ----------------------------------------------------------------- save

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final FormState? form = _formKey.currentState;
    if (form == null) {
      return;
    }
    // Old server errors must not block the new check.
    setState(() {
      _server = ServerFieldErrors.empty;
      _banner = null;
    });
    if (!form.validate()) {
      return;
    }

    setState(() => _saving = true);
    final ProposalListController list = ref.read(proposalListProvider.notifier);
    final ProposalDraft draft = _buildDraft();
    final String? id = widget.proposalId;
    final ApiResult<Proposal> result = id == null
        ? await list.create(draft)
        : await list.update(id, draft);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ApiOk<Proposal>():
        _navigateBack();
      case ApiErr<Proposal>(:final ApiError error):
        _showError(error);
    }
  }

  // ----------------------------------------------------------- navigation

  /// A programmatic pop is not stopped by the PopScope. Without history
  /// (a link opened directly) we go to a safe page.
  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final String? id = widget.proposalId;
    context.go(id == null ? AppRoutes.home : AppRoutes.proposal(id));
  }

  Future<bool> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your changes have not been saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _onPopBlocked(bool didPop, Object? result) async {
    if (didPop || _saving) {
      return;
    }
    final bool discard = await _confirmDiscard();
    if (discard && mounted) {
      _navigateBack();
    }
  }

  // ---------------------------------------------------------------- date

  Future<void> _pickDate() async {
    final DateTime now = ref.read(clockProvider)();
    final DateTime first = DateTime(2000);
    final DateTime last = DateTime(2100, 12, 31);
    DateTime initial =
        _followUp?.toDateTime() ?? DateTime(now.year, now.month, now.day);
    if (initial.isBefore(first)) {
      initial = first;
    }
    if (initial.isAfter(last)) {
      initial = last;
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (!mounted || picked == null) {
      return;
    }
    setState(() => _followUp = CalendarDate.fromDateTime(picked));
    _clearServerError(ProposalField.followUpDate);
  }

  void _clearDate() {
    setState(() => _followUp = null);
    _clearServerError(ProposalField.followUpDate);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final String? banner = _banner;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: _onPopBlocked,
      child: MaxContentWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: IgnorePointer(
            ignoring: _saving,
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: () => setState(() {}),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: <Widget>[
                  TextFormField(
                    key: const Key('field-title'),
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (String _) =>
                        _clearServerError(ProposalField.title),
                    validator: (String? value) =>
                        _serverError(ProposalField.title) ??
                        ProposalValidators.title(value),
                  ),
                  TextFormField(
                    key: const Key('field-company'),
                    controller: _company,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (String _) =>
                        _clearServerError(ProposalField.company),
                    validator: (String? value) =>
                        _serverError(ProposalField.company) ??
                        ProposalValidators.company(value),
                  ),
                  DropdownButtonFormField<ProposalPlatform>(
                    key: const Key('field-platform'),
                    initialValue: _platform,
                    decoration: const InputDecoration(
                      labelText: 'Platform',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<ProposalPlatform>>[
                      for (final ProposalPlatform platform
                          in ProposalPlatform.values)
                        DropdownMenuItem<ProposalPlatform>(
                          value: platform,
                          child: Text(platform.label),
                        ),
                    ],
                    onChanged: (ProposalPlatform? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _platform = value);
                      _clearServerError(ProposalField.platform);
                    },
                    validator: (ProposalPlatform? _) =>
                        _serverError(ProposalField.platform),
                  ),
                  DropdownButtonFormField<ProposalStatus>(
                    key: const Key('field-status'),
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: <DropdownMenuItem<ProposalStatus>>[
                      for (final ProposalStatus status in ProposalStatus.values)
                        DropdownMenuItem<ProposalStatus>(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (ProposalStatus? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _status = value);
                      _clearServerError(ProposalField.status);
                    },
                    validator: (ProposalStatus? _) =>
                        _serverError(ProposalField.status),
                  ),
                  TextFormField(
                    key: const Key('field-budget'),
                    controller: _budget,
                    decoration: const InputDecoration(
                      labelText: 'Budget',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (String _) =>
                        _clearServerError(ProposalField.budget),
                    validator: (String? value) =>
                        _serverError(ProposalField.budget) ??
                        ProposalValidators.budget(value),
                  ),
                  _DateField(
                    date: _followUp,
                    errorText: _serverError(ProposalField.followUpDate),
                    onPick: _pickDate,
                    onClear: _clearDate,
                  ),
                  TextFormField(
                    key: const Key('field-link'),
                    controller: _link,
                    decoration: const InputDecoration(
                      labelText: 'Link',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    onChanged: (String _) =>
                        _clearServerError(ProposalField.link),
                    validator: (String? value) =>
                        _serverError(ProposalField.link) ??
                        ProposalValidators.link(value),
                  ),
                  TextFormField(
                    key: const Key('field-notes'),
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    // The counter ("0/2000") comes from maxLength.
                    maxLength: ProposalValidators.notesMax,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    onChanged: (String _) =>
                        _clearServerError(ProposalField.notes),
                    validator: (String? value) =>
                        _serverError(ProposalField.notes) ??
                        ProposalValidators.notes(value),
                  ),
                  if (banner != null) _FormErrorBanner(message: banner),
                  FilledButton(
                    key: const Key('save-button'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? 'Save changes' : 'Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.errorText,
    required this.onPick,
    required this.onClear,
  });

  final CalendarDate? date;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final CalendarDate? value = date;
    return InkWell(
      key: const Key('field-follow-up'),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Follow-up date',
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (value != null)
                IconButton(
                  key: const Key('follow-up-clear'),
                  tooltip: 'Clear date',
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.calendar_today),
              ),
            ],
          ),
        ),
        child: Text(value == null ? 'No date' : formatCalendarDate(value)),
      ),
    );
  }
}

class _FormErrorBanner extends StatelessWidget {
  const _FormErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('form-error-banner'),
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
