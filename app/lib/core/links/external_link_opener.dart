import 'package:url_launcher/url_launcher.dart';

/// Opens a web link outside the app (the system browser).
/// The UI depends on this interface, so tests never touch a plugin.
abstract interface class ExternalLinkOpener {
  /// True when the link was handed to the system. Never throws.
  /// Only `http` and `https` links are opened.
  Future<bool> open(Uri uri);
}

typedef UriLauncher = Future<bool> Function(Uri uri);

Future<bool> _launchInExternalApp(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// The real opener (`url_launcher`). It checks the scheme again, so no other
/// caller can open `javascript:`, `file:` or app links by mistake.
final class UrlLauncherLinkOpener implements ExternalLinkOpener {
  const new({this._launch = _launchInExternalApp});

  final UriLauncher _launch;

  @override
  Future<bool> open(Uri uri) async {
    if (!_isWebLink(uri)) {
      return false;
    }
    try {
      return await _launch(uri);
    } on Exception {
      return false;
    }
  }

  static bool _isWebLink(Uri uri) =>
      (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
}
