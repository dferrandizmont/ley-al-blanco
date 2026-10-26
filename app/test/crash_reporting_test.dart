import 'package:apto_armas/core/diagnostics/crash_reporting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'local handling preserves Flutter reporting and handles platform errors',
    () {
      final before = FlutterError.onError;
      final platform = PlatformDispatcher.instance.onError;
      final print = debugPrint;
      addTearDown(() {
        FlutterError.onError = before;
        PlatformDispatcher.instance.onError = platform;
        debugPrint = print;
      });
      final details = <FlutterErrorDetails>[];
      final lines = <String?>[];
      FlutterError.onError = details.add;
      debugPrint = (message, {wrapWidth}) => lines.add(message);
      installLocalErrorHandling();
      final error = StateError('local');
      final stack = StackTrace.current;
      FlutterError.onError!(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      expect(details.single.exception, same(error));
      expect(PlatformDispatcher.instance.onError!(error, stack), isTrue);
      expect(lines, contains('Unhandled StateError'));
    },
  );
}
