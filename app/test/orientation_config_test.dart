import 'dart:io';

import 'package:apto_armas/features/settings/application/settings_providers.dart'
    show kSystemChannel;
import 'package:flutter_test/flutter_test.dart';

/// Native configuration pinned by tests (nothing here runs on the host):
/// decision 7.4 (portrait only on phones, free rotation on tablets, decided in
/// the native projects because Dart never sees the phone before the first
/// frame) and decision 7.8 (the Android channel that gives the system version
/// for the support e-mail).
void main() {
  /// The strings of the array that follows [key] in Info.plist.
  List<String> orientations(String plist, String key) {
    final match = RegExp(
      '<key>${RegExp.escape(key)}</key>'
      r'\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull, reason: key);
    return RegExp(r'<string>(\w+)</string>')
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
  }

  test('iOS: iPhone supports portrait only, iPad every orientation', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(orientations(plist, 'UISupportedInterfaceOrientations'), [
      'UIInterfaceOrientationPortrait',
    ]);
    expect(
      orientations(plist, 'UISupportedInterfaceOrientations~ipad'),
      unorderedEquals([
        'UIInterfaceOrientationPortrait',
        'UIInterfaceOrientationPortraitUpsideDown',
        'UIInterfaceOrientationLandscapeLeft',
        'UIInterfaceOrientationLandscapeRight',
      ]),
      reason: 'Apple requires all four on iPad for apps that support it',
    );
  });

  test('Android: portrait below a smallest width of 600 dp, free above', () {
    final activity = File(
      'android/app/src/main/kotlin/es/leyalblanco/app/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('smallestScreenWidthDp < TABLET_MIN_WIDTH_DP'));
    expect(activity, contains('TABLET_MIN_WIDTH_DP = 600'));
    expect(activity, contains('SCREEN_ORIENTATION_PORTRAIT'));
    expect(activity, contains('SCREEN_ORIENTATION_UNSPECIFIED'));
    // Set before the first frame, so a phone never flashes in landscape.
    expect(
      activity.indexOf('requestedOrientation'),
      lessThan(activity.indexOf('super.onCreate')),
    );
  });

  test('Android: the manifest does not pin one orientation for tablets', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, isNot(contains('android:screenOrientation')));
    // The activity handles the rotation itself (no restart, no lost state).
    expect(manifest, contains('orientation'));
  });

  test('Android: the support-mail channel only answers the release number', () {
    final activity = File(
      'android/app/src/main/kotlin/es/leyalblanco/app/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('SYSTEM_CHANNEL = "$kSystemChannel"'));
    expect(
      activity,
      contains('"osVersion" -> result.success(Build.VERSION.RELEASE)'),
    );
    expect(activity, isNot(contains('Build.MODEL')));
    expect(activity, isNot(contains('Build.MANUFACTURER')));
    expect(activity, isNot(contains('Build.SERIAL')));
  });
}
