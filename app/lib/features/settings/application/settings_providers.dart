import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config.dart';

/// Opens a link outside the app (the browser, the mail app). A wrapper over
/// `url_launcher` so tests never reach the platform.
abstract class UrlLauncher {
  /// Opens [uri] in the external application; false when nothing could.
  Future<bool> open(Uri uri);
}

/// The real launcher: always an external application (never an in-app web
/// view, so nothing about the visit stays inside Ley al Blanco).
class SystemUrlLauncher implements UrlLauncher {
  const SystemUrlLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

final urlLauncherProvider = Provider<UrlLauncher>(
  (ref) => const SystemUrlLauncher(),
);

/// Name and build of the running app.
class AppInfo {
  const AppInfo({required this.version, this.buildNumber = ''});

  /// `0.1.0`.
  final String version;

  /// `1` (may be empty).
  final String buildNumber;

  /// `0.1.0 (1)`, or just the version when there is no build number.
  String get label => buildNumber.isEmpty ? version : '$version ($buildNumber)';
}

/// The version of the running app (`package_info_plus`); tests override it.
final appInfoProvider = FutureProvider<AppInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppInfo(version: info.version, buildNumber: info.buildNumber);
});

/// The platform name for the support e-mail ("Android", "iOS"...).
final platformNameProvider = Provider<String>(
  (ref) => kIsWeb
      ? 'Web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'Android',
          TargetPlatform.iOS => 'iOS',
          TargetPlatform.macOS => 'macOS',
          TargetPlatform.windows => 'Windows',
          TargetPlatform.linux => 'Linux',
          TargetPlatform.fuchsia => 'Fuchsia',
        },
);

/// The operating system for the support e-mail: the platform name and its
/// version ("Android 16", "iOS 18.2"), never the phone model. Falls back to
/// the plain name when the version cannot be read.
final systemLabelProvider = FutureProvider<String>((ref) async {
  final name = ref.watch(platformNameProvider);
  final platform = kIsWeb ? null : defaultTargetPlatform;
  String? version;
  try {
    version = switch (platform) {
      TargetPlatform.android => await const MethodChannel(
        kSystemChannel,
      ).invokeMethod<String>('osVersion'),
      TargetPlatform.iOS => iosVersionOf(Platform.operatingSystemVersion),
      _ => null,
    };
  } on Object {
    // No channel (a test, an old build): the name alone still helps.
  }
  return systemLabel(name, version);
});

/// [systemLabelProvider]'s value, or the plain platform name when it cannot be
/// obtained: the mail must open either way.
Future<String> readSystemLabel(WidgetRef ref) async {
  try {
    return await ref.read(systemLabelProvider.future);
  } on Object {
    return ref.read(platformNameProvider);
  }
}

/// The Android side of [systemLabelProvider] (see `MainActivity.kt`): answers
/// `osVersion` with `Build.VERSION.RELEASE`.
const String kSystemChannel = 'es.leyalblanco/system';

/// `Android 16` from the platform [name] and the raw [version] the system
/// reports; just [name] when the version is missing or does not look like one
/// (it ends up in an e-mail the user reads, so nothing odd is written).
String systemLabel(String name, String? version) {
  final clean = version?.trim() ?? '';
  return RegExp(r'^\d{1,3}(\.\d{1,3}){0,3}$').hasMatch(clean)
      ? '$name $clean'
      : name;
}

/// The version out of `Platform.operatingSystemVersion` on iOS
/// ("Version 18.2 (Build 22C150)" gives "18.2"); null when it is not there.
String? iosVersionOf(String operatingSystemVersion) =>
    RegExp(r'(\d+(?:\.\d+)*)').firstMatch(operatingSystemVersion)?.group(1);

/// The two outside links Ajustes may show. A value that is empty or does not
/// look right is simply absent, so a build without them shows no broken row.
class SettingsLinks {
  const SettingsLinks({this.supportEmail = '', this.privacyUrl = ''});

  /// `--dart-define=SUPPORT_EMAIL`.
  final String supportEmail;

  /// `--dart-define=PRIVACY_URL`.
  final String privacyUrl;

  /// The support address, or null when unset or not an address.
  String? get support {
    final value = supportEmail.trim();
    return RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(value) ? value : null;
  }

  /// The privacy-policy page, or null when unset or not an http(s) URL.
  Uri? get privacy {
    final uri = Uri.tryParse(privacyUrl.trim());
    if (uri == null || !uri.hasAuthority) return null;
    return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
  }

  bool get hasAny => support != null || privacy != null;
}

final settingsLinksProvider = Provider<SettingsLinks>(
  (ref) => const SettingsLinks(
    supportEmail: AppConfig.supportEmail,
    privacyUrl: AppConfig.privacyUrl,
  ),
);

/// `mailto:` for [address] with [subject] and [body] percent-encoded (spaces
/// as `%20`, which every mail app reads; `Uri.queryParameters` would write
/// `+`).
Uri supportMailUri(
  String address, {
  required String subject,
  required String body,
}) => Uri.parse(
  'mailto:${Uri.encodeComponent(address).replaceAll('%40', '@')}'
  '?subject=${Uri.encodeComponent(subject)}'
  '&body=${Uri.encodeComponent(body)}',
);
