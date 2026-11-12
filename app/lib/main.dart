import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'core/bootstrap/startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  await startApp();
}

/// Adds the bundled font's SIL OFL notice to the licences page.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/PublicSans-OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Public Sans'], text);
  });
}
