import 'package:apply_track/features/proposals/ui/proposal_detail_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_helpers.dart';
import '../support/fake_notification_scheduler.dart';

void main() {
  testWidgets('a tap on a reminder opens its proposal', (tester) async {
    final scheduler = FakeNotificationScheduler();
    await pumpApp(tester, signedInRepo(), notificationScheduler: scheduler);
    expect(find.byType(ProposalDetailScreen), findsNothing);

    scheduler.replayTap(routeTestId);
    await tester.pumpAndSettle();

    final screen = tester.widget<ProposalDetailScreen>(
      find.byType(ProposalDetailScreen),
    );
    expect(screen.proposalId, routeTestId);
  });
}
