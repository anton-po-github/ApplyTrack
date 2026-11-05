import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The button drawn by the Google SDK. It is the only way to get an
/// ID token on web.
Widget buildGoogleRenderedButton() => web.renderButton();
