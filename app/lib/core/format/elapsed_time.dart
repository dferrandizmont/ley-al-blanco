import '../../l10n/app_localizations.dart';

/// Formatea la duración con minutos totales y segundos completos restantes.
String formatElapsedTime(Duration elapsed, AppLocalizations l10n) {
  return l10n.elapsedMinutesSeconds(
    elapsed.inMinutes,
    elapsed.inSeconds.remainder(60),
  );
}
