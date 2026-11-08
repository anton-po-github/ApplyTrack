import 'package:apply_track/core/links/external_link_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Uri> launched;

  UrlLauncherLinkOpener openerAnswering(
    Future<bool> Function(Uri uri) answer,
  ) => UrlLauncherLinkOpener(
    launch: (uri) {
      launched.add(uri);
      return answer(uri);
    },
  );

  setUp(() {
    launched = <Uri>[];
  });

  group('UrlLauncherLinkOpener', () {
    test('opens http and https links', () async {
      final opener = openerAnswering((uri) async => true);

      expect(await opener.open(Uri.parse('https://acme.io/job')), isTrue);
      expect(await opener.open(Uri.parse('http://acme.io')), isTrue);
      expect(launched, hasLength(2));
    });

    test('never opens another scheme', () async {
      final opener = openerAnswering((uri) async => true);

      for (final text in <String>[
        'javascript:alert(1)',
        'file:///etc/passwd',
        'mailto:a@b.com',
        'tel:123',
        'intent://x#Intent;scheme=app;end',
        '//acme.io/no-scheme',
      ]) {
        expect(await opener.open(Uri.parse(text)), isFalse, reason: text);
      }
      expect(launched, isEmpty);
    });

    test('never opens a link without a host', () async {
      final opener = openerAnswering((uri) async => true);

      expect(await opener.open(Uri.parse('https://')), isFalse);
      expect(launched, isEmpty);
    });

    test('false from the system is passed on', () async {
      final opener = openerAnswering((uri) async => false);

      expect(await opener.open(Uri.parse('https://acme.io')), isFalse);
    });

    test('an exception from the plugin becomes false', () async {
      final opener = openerAnswering(
        (uri) async => throw Exception('no browser'),
      );

      expect(await opener.open(Uri.parse('https://acme.io')), isFalse);
    });
  });
}
