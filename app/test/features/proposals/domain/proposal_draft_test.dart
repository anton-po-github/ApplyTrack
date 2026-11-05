import 'package:flutter_test/flutter_test.dart';

import 'package:apply_track/features/proposals/domain/calendar_date.dart';
import 'package:apply_track/features/proposals/domain/proposal.dart';
import 'package:apply_track/features/proposals/domain/proposal_draft.dart';
import 'package:apply_track/features/proposals/domain/proposal_platform.dart';
import 'package:apply_track/features/proposals/domain/proposal_status.dart';

const List<String> _allKeys = <String>[
  'title',
  'company',
  'platform',
  'status',
  'budget',
  'followUpDate',
  'link',
  'notes',
];

void main() {
  group('toJson', () {
    test('always has all 8 keys (PUT is a full replace)', () {
      final Map<String, Object?> json = const ProposalDraft(
        title: 'Hello',
        platform: ProposalPlatform.upwork,
        status: ProposalStatus.draft,
      ).toJson();

      expect(json.keys.toSet(), _allKeys.toSet());
      expect(json['company'], isNull);
      expect(json['budget'], isNull);
      expect(json['followUpDate'], isNull);
      expect(json['link'], isNull);
      expect(json['notes'], isNull);
    });

    test('sends enums as numbers and the date as yyyy-MM-dd', () {
      final Map<String, Object?> json = ProposalDraft(
        title: 'Hello',
        platform: ProposalPlatform.email,
        status: ProposalStatus.won,
        followUpDate: CalendarDate(2026, 3, 5),
      ).toJson();

      expect(json['platform'], 2);
      expect(json['status'], 4);
      expect(json['followUpDate'], '2026-03-05');
    });

    test('has no id and no userId', () {
      final Map<String, Object?> json = const ProposalDraft.empty().toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('userId'), isFalse);
    });

    test('trims title, company and link', () {
      final Map<String, Object?> json = const ProposalDraft(
        title: '  Hi there  ',
        company: '  Acme ',
        link: ' https://a.b ',
        platform: ProposalPlatform.other,
        status: ProposalStatus.sent,
      ).toJson();

      expect(json['title'], 'Hi there');
      expect(json['company'], 'Acme');
      expect(json['link'], 'https://a.b');
    });

    test('blank optional text becomes null', () {
      final Map<String, Object?> json = const ProposalDraft(
        title: 'Hello',
        company: '   ',
        link: '',
        notes: ' \n\t ',
        platform: ProposalPlatform.upwork,
        status: ProposalStatus.draft,
      ).toJson();

      expect(json['company'], isNull);
      expect(json['link'], isNull);
      expect(json['notes'], isNull);
    });

    test('notes keep their line breaks', () {
      final Map<String, Object?> json = const ProposalDraft(
        title: 'Hello',
        notes: 'a\n\tb',
        platform: ProposalPlatform.upwork,
        status: ProposalStatus.draft,
      ).toJson();

      expect(json['notes'], 'a\n\tb');
    });

    test('budget is rounded to 2 decimals and 0 is kept', () {
      Map<String, Object?> withBudget(double value) => ProposalDraft(
        title: 'Hello',
        budget: value,
        platform: ProposalPlatform.upwork,
        status: ProposalStatus.draft,
      ).toJson();

      expect(withBudget(10.456)['budget'], 10.46);
      expect(withBudget(7)['budget'], 7.0);
      expect(withBudget(0)['budget'], 0.0);
    });
  });

  group('fromProposal', () {
    final Proposal proposal = Proposal.fromJson(<String, Object?>{
      'id': 'abc',
      'title': 'Flutter app',
      'company': 'Acme',
      'platform': 1,
      'status': 2,
      'budget': 50,
      'followUpDate': '2026-12-31',
      'link': 'https://example.com',
      'notes': 'Note',
      'createdAtMs': 1,
      'updatedAtMs': 2,
    });

    test('copies the editable fields', () {
      final ProposalDraft draft = ProposalDraft.fromProposal(proposal);

      expect(draft.title, 'Flutter app');
      expect(draft.company, 'Acme');
      expect(draft.platform, ProposalPlatform.linkedIn);
      expect(draft.status, ProposalStatus.viewed);
      expect(draft.budget, 50.0);
      expect(draft.followUpDate, CalendarDate(2026, 12, 31));
      expect(draft.link, 'https://example.com');
      expect(draft.notes, 'Note');
    });

    test('toJson of an unchanged draft keeps the server values', () {
      final Map<String, Object?> json = ProposalDraft.fromProposal(proposal)
          .toJson();

      expect(json, <String, Object?>{
        'title': 'Flutter app',
        'company': 'Acme',
        'platform': 1,
        'status': 2,
        'budget': 50.0,
        'followUpDate': '2026-12-31',
        'link': 'https://example.com',
        'notes': 'Note',
      });
    });

    test('withStatus changes only the status', () {
      final ProposalDraft draft = ProposalDraft.fromProposal(proposal);
      final ProposalDraft next = draft.withStatus(ProposalStatus.interview);

      expect(next.status, ProposalStatus.interview);
      expect(next.title, draft.title);
      expect(next.followUpDate, draft.followUpDate);
      expect(draft.status, ProposalStatus.viewed);
    });
  });

  test('empty draft starts as Upwork and Draft', () {
    const ProposalDraft draft = ProposalDraft.empty();
    expect(draft.title, '');
    expect(draft.platform, ProposalPlatform.upwork);
    expect(draft.status, ProposalStatus.draft);
  });

  test('equal data gives equal drafts', () {
    expect(const ProposalDraft.empty(), const ProposalDraft.empty());
    expect(
      const ProposalDraft.empty().hashCode,
      const ProposalDraft.empty().hashCode,
    );
    expect(
      const ProposalDraft.empty(),
      isNot(const ProposalDraft.empty().withStatus(ProposalStatus.sent)),
    );
  });
}
