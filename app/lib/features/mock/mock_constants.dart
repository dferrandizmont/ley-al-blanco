/// Keys of the `settings` table written by the mock feature.
abstract final class MockSettingKeys {
  /// `1` / `0`: the user's last choice for the indicative countdown switch
  /// on the mock intro. Absent until they flip it (the default is on).
  static const timerEnabled = 'mock.timer_enabled';
}
