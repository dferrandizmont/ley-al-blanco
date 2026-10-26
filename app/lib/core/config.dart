/// Build-time links, supplied with `--dart-define`.
class AppConfig {
  const AppConfig._();

  /// Empty hides the support row; opening it uses the user's mail app.
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// Empty hides the policy link; opening it uses the external browser.
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
}
