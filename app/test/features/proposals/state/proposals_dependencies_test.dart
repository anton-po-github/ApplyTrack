import 'package:apply_track/features/auth/state/auth_dependencies.dart';
import 'package:apply_track/features/proposals/state/proposals_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_api_client.dart';

void main() {
  test('both APIs use the shared ApiClient', () async {
    final client = FakeApiClient()
      ..json = <String, Object?>{'items': <Object?>[]};
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container.read(proposalsApiProvider).list();
    expect(client.last.path, '/api/proposals');

    client.json = <String, Object?>{
      'total': 0,
      'draft': 0,
      'sent': 0,
      'viewed': 0,
      'interview': 0,
      'won': 0,
      'lost': 0,
    };
    await container.read(statsApiProvider).getStats();
    expect(client.last.path, '/api/stats');
  });
}
