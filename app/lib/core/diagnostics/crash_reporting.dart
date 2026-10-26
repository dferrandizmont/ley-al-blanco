import 'package:flutter/foundation.dart';

/// Installs only local error handling. Nothing is collected or sent.
/// The old SharedPreferences key `privacy.crash_reports.v1` is left untouched
/// on existing devices for compatibility and is no longer read or written.
void installLocalErrorHandling() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled ${error.runtimeType}');
    debugPrintStack(stackTrace: stack);
    return true;
  };
}
