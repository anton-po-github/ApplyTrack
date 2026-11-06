import 'package:apply_track/core/links/external_link_opener.dart';

/// A fake [ExternalLinkOpener]. It records every link and answers [result].
final class FakeExternalLinkOpener implements ExternalLinkOpener {
  final List<Uri> opened = <Uri>[];
  bool result = true;

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return result;
  }
}
