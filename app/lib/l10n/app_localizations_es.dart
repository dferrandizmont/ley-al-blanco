// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Ley al Blanco';

  @override
  String get legalDisclaimer =>
      'App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil.';

  @override
  String get retry => 'Reintentar';

  @override
  String get bootstrapLoading => 'Preparando la app…';

  @override
  String get bootstrapFailed => 'No se ha podido preparar la app';

  @override
  String get genericError => 'Algo ha fallado. Inténtalo de nuevo.';

  @override
  String get next => 'Siguiente';

  @override
  String get previous => 'Anterior';

  @override
  String get backToHome => 'Volver al inicio';

  @override
  String get cancel => 'Cancelar';

  @override
  String ratio(int a, int b) {
    return '$a / $b';
  }

  @override
  String progressSemantics(int current, int total) {
    return 'Pregunta $current de $total';
  }

  @override
  String correctOfSemantics(int correct, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      correct,
      locale: localeName,
      other: '$correct aciertos',
      one: '1 acierto',
    );
    return '$_temp0 de $total';
  }

  @override
  String semanticsTitleSubtitle(String title, String subtitle) {
    return '$title. $subtitle';
  }

  @override
  String temaLabel(int n) {
    return 'Tema $n';
  }

  @override
  String get loadErrorTitle => 'No se han podido cargar los datos';

  @override
  String get tema1 => 'Funcionamiento y seguridad';

  @override
  String get tema2 => 'Categorías de armas';

  @override
  String get tema3 => 'Circulación, revista y transferencia';

  @override
  String get tema4 => 'Documentación y licencias, Tarjeta Europea';

  @override
  String get tema5 => 'Régimen sancionador';

  @override
  String get tema6 => 'Reparación, prueba y depósito';

  @override
  String get tema7 =>
      'Armas de colección, definiciones, historia, calibres y munición';

  @override
  String get homePassProbability => 'Probabilidad de aprobar';

  @override
  String get homeContinue => 'Continuar';

  @override
  String homeContinueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preguntas para hoy',
      one: '1 pregunta para hoy',
    );
    return '$_temp0';
  }

  @override
  String get homeContinueDone =>
      'Has terminado el repaso de hoy. Puedes practicar un tema o hacer un simulacro.';

  @override
  String get homeMockTitle => 'Simulacro';

  @override
  String get homeMockSubtitle => 'Un examen completo, como el real';

  @override
  String get homeMistakesTitle => 'Fallos';

  @override
  String mistakesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallos pendientes',
      one: '1 fallo pendiente',
      zero: 'Sin fallos pendientes',
    );
    return '$_temp0';
  }

  @override
  String get homeTemasTitle => 'Temas';

  @override
  String temaCardMastery(String percent) {
    return 'Dominio $percent';
  }

  @override
  String temaCardMistakes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallos',
      one: '1 fallo',
    );
    return '$_temp0';
  }

  @override
  String bankEdition(String edition) {
    return 'Cuestionario $edition';
  }

  @override
  String scoreRingSemantics(String label, String percent) {
    return '$label: $percent';
  }

  @override
  String get scoreRingUnknown => 'Calculando';

  @override
  String optionSemantics(String letter, String text) {
    return 'Opción $letter: $text';
  }

  @override
  String get optionCorrect => 'Correcta';

  @override
  String get optionIncorrect => 'Incorrecta';

  @override
  String masteryBarSemantics(String percent) {
    return 'Dominio $percent';
  }

  @override
  String get explanationCorrect => 'Correcto';

  @override
  String get explanationIncorrect => 'Incorrecto';

  @override
  String get explanationCorrectAnswer => 'Respuesta correcta';

  @override
  String explanationAnswerLine(String letter, String text) {
    return '$letter. $text';
  }

  @override
  String get explanationHeading => 'Explicación';

  @override
  String get explanationPending => 'Explicación en preparación';

  @override
  String get noticeTitle => 'Aviso: cambio en la norma';

  @override
  String articleChipSemantics(String article) {
    return 'Fuente: $article';
  }

  @override
  String get practiceDailyTitle => 'Repaso del día';

  @override
  String get practiceMistakesTitle => 'Repasar fallos';

  @override
  String get practiceMockMistakesTitle => 'Fallos del simulacro';

  @override
  String practiceTemaTitle(String tema, String title) {
    return '$tema · $title';
  }

  @override
  String get practiceFinish => 'Terminar';

  @override
  String get practiceSaveError =>
      'No se ha podido guardar tu respuesta. Inténtalo de nuevo.';

  @override
  String get practiceEmptyDailyTitle => 'Hoy no quedan preguntas';

  @override
  String get practiceEmptyDailyMessage =>
      'Vuelve mañana, o practica un tema o haz un simulacro.';

  @override
  String get practiceEmptyMistakesTitle => 'No hay fallos que repasar';

  @override
  String get practiceEmptyMistakesMessage =>
      'Las preguntas que falles aparecerán aquí.';

  @override
  String get practiceSummaryTitle => 'Sesión terminada';

  @override
  String get practiceSummaryScore => 'Aciertos';

  @override
  String get mockTitle => 'Simulacro';

  @override
  String mockIntroBody(int size, int passMark) {
    return '$size preguntas de test con tres opciones, como en el examen. Se aprueba con $passMark aciertos.';
  }

  @override
  String get mockIntroNoFeedback =>
      'No verás si aciertas hasta entregar, y puedes cambiar una respuesta antes de entregar. Las preguntas sin responder cuentan como fallo.';

  @override
  String mockTimerSwitch(int minutes) {
    return 'Cronómetro orientativo ($minutes min)';
  }

  @override
  String get mockTimerHelp =>
      'El tiempo real del examen no consta en el BOE: es solo una guía y no corta el simulacro.';

  @override
  String get mockStart => 'Empezar';

  @override
  String get mockStartError =>
      'No se ha podido crear el simulacro. Inténtalo de nuevo.';

  @override
  String get mockStartAnother => 'Empezar otro';

  @override
  String get mockResumeTitle => 'Tienes un simulacro sin entregar';

  @override
  String mockResumeProgress(int answered, int total) {
    return '$answered de $total respondidas';
  }

  @override
  String get mockResume => 'Continuar simulacro';

  @override
  String get homeMockResumeSubtitle => 'Tienes uno sin entregar';

  @override
  String get mockReplaceTitle => '¿Empezar otro simulacro?';

  @override
  String get mockReplaceBody =>
      'El simulacro sin entregar se descartará y no podrás retomarlo.';

  @override
  String get mockHistoryTitle => 'Tus simulacros';

  @override
  String mockHistoryScore(int correct, int total) {
    return '$correct de $total';
  }

  @override
  String mockHistoryRowSemantics(String date, String score, String verdict) {
    return 'Simulacro del $date. $score. $verdict';
  }

  @override
  String mockTimerRemaining(String time) {
    return 'Quedan $time';
  }

  @override
  String get mockTimerExpired => 'Tiempo orientativo agotado';

  @override
  String get mockQuestions => 'Preguntas';

  @override
  String get mockNavigatorTitle => 'Ir a la pregunta';

  @override
  String navigatorCellAnswered(int number) {
    return 'Pregunta $number, respondida';
  }

  @override
  String navigatorCellBlank(int number) {
    return 'Pregunta $number, sin responder';
  }

  @override
  String get mockSubmit => 'Entregar';

  @override
  String get mockSubmitTitle => '¿Entregar el simulacro?';

  @override
  String mockSubmitUnanswered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te quedan $count preguntas sin responder y contarán como fallo.',
      one: 'Te queda 1 pregunta sin responder y contará como fallo.',
      zero: 'Has respondido todas las preguntas.',
    );
    return '$_temp0';
  }

  @override
  String get mockSubmitKeep => 'Seguir';

  @override
  String get mockLeaveTitle => '¿Salir del simulacro?';

  @override
  String get mockLeaveBody =>
      'Si sales ahora, el simulacro queda sin entregar. Podrás retomarlo desde Simulacro.';

  @override
  String get mockLeaveConfirm => 'Salir';

  @override
  String mockResultElapsedTime(String duration) {
    return 'Tiempo empleado: $duration';
  }

  @override
  String elapsedMinutesSeconds(int minutes, int seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String get mockResultPassed => 'APTO';

  @override
  String get mockResultFailed => 'NO APTO';

  @override
  String mockResultPassMarkHint(int passMark) {
    return 'La marca indica el aprobado: $passMark aciertos.';
  }

  @override
  String mockResultOutOf(int total) {
    return 'de $total';
  }

  @override
  String get mockResultPerTema => 'Aciertos por tema';

  @override
  String get mockResultQuestionsTitle => 'Preguntas';

  @override
  String get mockResultOnlyFailed => 'Solo falladas';

  @override
  String get mockResultRowCorrect => 'Acertada';

  @override
  String get mockResultRowFailed => 'Fallada';

  @override
  String mockResultHeaderSemantics(String tema, String title, String score) {
    return '$tema. $title. $score';
  }

  @override
  String mockResultRowSemantics(
    int number,
    String stem,
    String status,
    String answer,
  ) {
    return '$number. $stem. $status. $answer';
  }

  @override
  String mockResultRowTitle(int number, String stem) {
    return '$number. $stem';
  }

  @override
  String get mockResultNoFailed => 'No has fallado ninguna pregunta.';

  @override
  String mockResultReviewMistakesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los $count fallos',
      one: 'el fallo',
    );
    return 'Repasar $_temp0';
  }

  @override
  String get mockResultNotFinished => 'Este simulacro no se ha entregado.';

  @override
  String get mockResultUnanswered => 'Sin responder';

  @override
  String get mockReviewTitle => 'Revisión';

  @override
  String mockReviewPosition(int current, int total) {
    return 'Pregunta $current de $total';
  }

  @override
  String mockReviewYourAnswer(String letter) {
    return 'Tu respuesta: $letter';
  }

  @override
  String get mistakesFilterAll => 'Todos';

  @override
  String get mistakesReviewAll => 'Repasar todos';

  @override
  String get mistakesEmptyTitle => 'No tienes fallos pendientes';

  @override
  String get mistakesEmptyMessage =>
      'Las preguntas que falles aparecerán aquí hasta que las aciertes dos veces seguidas.';

  @override
  String get mistakesRowHint => 'Toca para ver la ficha de este fallo';

  @override
  String mistakeSheetLastAnswer(String letter) {
    return 'Tu última respuesta: $letter';
  }

  @override
  String mistakeSheetTheory(int n) {
    return 'Ver la teoría del tema $n';
  }

  @override
  String get mistakeSheetPractice => 'Practicar esta pregunta';

  @override
  String mistakesWrongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fallada $count veces',
      one: 'Fallada 1 vez',
    );
    return '$_temp0';
  }

  @override
  String get close => 'Cerrar';

  @override
  String get homeStatusLine => 'Estimación según tus respuestas';

  @override
  String get homeSettings => 'Ajustes';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAppearanceSection => 'Apariencia';

  @override
  String get settingsThemeGroup => 'Tema de la app';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsDataSection => 'Tus datos';

  @override
  String get settingsExportTitle => 'Exportar progreso';

  @override
  String get settingsExportSubtitle =>
      'Guarda tus respuestas, fallos y simulacros en un archivo para cambiar de móvil. Tú eliges dónde.';

  @override
  String get settingsImportTitle => 'Importar progreso';

  @override
  String get settingsImportSubtitle =>
      'Recupera un archivo exportado antes. Reemplaza el progreso de este móvil.';

  @override
  String get settingsExportDone => 'Progreso guardado.';

  @override
  String get settingsExportTooLarge =>
      'Tu progreso ocupa más de 10 MB y no se puede exportar. No se ha guardado nada.';

  @override
  String get settingsTransferWorking => 'Procesando el archivo…';

  @override
  String get settingsExportFailed => 'No se ha podido guardar el archivo.';

  @override
  String get settingsImportConfirmTitle => '¿Reemplazar tu progreso?';

  @override
  String get settingsImportConfirmBody =>
      'Reemplaza tu progreso actual por el del archivo. No se puede deshacer. El archivo trae:';

  @override
  String settingsImportSummaryAnswers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count respuestas',
      one: '1 respuesta',
    );
    return '$_temp0';
  }

  @override
  String settingsImportSummaryWrong(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count falladas',
      one: '1 fallada',
      zero: 'ninguna fallada',
    );
    return '$_temp0';
  }

  @override
  String settingsImportSummaryAnswersWrong(String answers, String wrong) {
    return '$answers, de ellas $wrong';
  }

  @override
  String settingsImportSummaryMocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count simulacros',
      one: '1 simulacro',
      zero: 'Ningún simulacro',
    );
    return '$_temp0';
  }

  @override
  String settingsImportSummaryReview(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count preguntas en el repaso diario',
      one: '1 pregunta en el repaso diario',
      zero: 'Ninguna pregunta en el repaso diario',
    );
    return '$_temp0';
  }

  @override
  String settingsImportSummaryDate(String date) {
    return 'Exportado el $date';
  }

  @override
  String settingsImportDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se ignorarán $count datos que no se pueden usar (de preguntas que ya no existen o con una fecha imposible).',
      one: 'Se ignorará 1 dato que no se puede usar (de una pregunta que ya no existe o con una fecha imposible).',
    );
    return '$_temp0';
  }

  @override
  String get settingsImportReplace => 'Reemplazar';

  @override
  String get settingsImportDone => 'Progreso importado.';

  @override
  String get settingsImportErrorTitle => 'No se puede importar';

  @override
  String get settingsImportErrorTooLarge =>
      'El archivo es demasiado grande para ser un progreso de Ley al Blanco (máximo 10 MB). No se ha cambiado nada.';

  @override
  String get settingsImportErrorNotJson =>
      'El archivo está dañado o no es un archivo de progreso. No se ha cambiado nada.';

  @override
  String get settingsImportErrorWrongFormat =>
      'Este archivo no es un progreso exportado por Ley al Blanco. No se ha cambiado nada.';

  @override
  String get settingsImportErrorNewerVersion =>
      'Este archivo es de una versión más nueva de Ley al Blanco. Actualiza la app e inténtalo de nuevo. No se ha cambiado nada.';

  @override
  String get settingsImportErrorWrongEdition =>
      'Este archivo es de otra edición del banco de preguntas y sus respuestas no coincidirían con las de esta app. No se ha cambiado nada.';

  @override
  String get settingsImportErrorInvalid =>
      'El archivo tiene datos que no son válidos. No se ha cambiado nada y tu progreso sigue igual.';

  @override
  String get settingsImportErrorFailed =>
      'No se ha podido importar el archivo. Tu progreso sigue igual.';

  @override
  String get settingsImportErrorOk => 'Entendido';

  @override
  String get settingsBankSection => 'Banco de preguntas';

  @override
  String get settingsBankEdition => 'Edición';

  @override
  String settingsBankEditionValue(String edition) {
    return 'Cuestionario $edition';
  }

  @override
  String get settingsBankQuestions => 'Preguntas';

  @override
  String get settingsBankRetrieved => 'Consultado';

  @override
  String get settingsBankSource => 'Ver la fuente original';

  @override
  String get settingsHelpSection => 'Ayuda';

  @override
  String get settingsSupportTitle => 'Escribir a soporte';

  @override
  String get settingsSupportSubtitle => 'Respondemos en menos de 48 h';

  @override
  String settingsSupportMailSubject(String version) {
    return 'Ley al Blanco $version';
  }

  @override
  String settingsSupportMailBody(String version, String platform) {
    return '\n\n---\nApp: Ley al Blanco $version\nSistema: $platform';
  }

  @override
  String get explanationReport => '¿Ves un error? Avísanos';

  @override
  String explanationReportMailSubject(String id, String version) {
    return 'Error en la pregunta $id · Ley al Blanco $version';
  }

  @override
  String explanationReportMailBody(
    String id,
    String edition,
    int tema,
    String stem,
    String letter,
    String explanation,
    String article,
    String version,
    String platform,
  ) {
    return 'Pregunta: $id\nEdición: $edition\nTema: $tema\nEnunciado: $stem\nRespuesta oficial: $letter\nExplicación actual: $explanation\nArtículo: $article\nApp: Ley al Blanco $version\nSistema: $platform\n\nCuéntanos qué está mal:\n';
  }

  @override
  String get settingsPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsOpenFailed => 'No se ha podido abrir el enlace.';

  @override
  String settingsLegal(String date) {
    return 'App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil (consultado el $date). Las explicaciones son de redacción propia y no constituyen asesoramiento jurídico.';
  }

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get homeTheoryTitle => 'Teoría';

  @override
  String get homeTheorySubtitle => 'Resúmenes y prueba práctica';

  @override
  String get theoryTitle => 'Teoría';

  @override
  String get theoryIntro =>
      'Repasa lo que entra en cada tema antes de practicar, o después de fallar. No sustituye al Reglamento: lo ordena y cita el artículo de cada dato.';

  @override
  String get theoryPracticaTitle => 'La prueba práctica';

  @override
  String get theoryTemasTitle => 'Resúmenes por tema';

  @override
  String theoryRead(int minutes) {
    return '$minutes min de lectura';
  }

  @override
  String theoryTemaOverline(int n) {
    return 'Tema $n · Teoría';
  }

  @override
  String get theoryPracticaOverline => 'Teoría · Prueba práctica';

  @override
  String get theoryPracticeThisTema => 'Practicar este tema';

  @override
  String get theoryExtrasTitle => 'Para completar';

  @override
  String get theoryAemOverline => 'Teoría · Menores (AEM)';

  @override
  String get theoryGlosarioOverline => 'Teoría · Glosario';

  @override
  String get theoryGlossarySearchHint => 'Buscar un término';

  @override
  String get theoryGlossarySearchClear => 'Borrar la búsqueda';

  @override
  String theoryGlossaryResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count términos',
      one: '1 término',
    );
    return '$_temp0';
  }

  @override
  String get theoryGlossaryNoResultsTitle => 'Ningún término coincide';

  @override
  String get theoryGlossaryNoResultsMessage =>
      'Prueba con otra palabra o con menos letras.';

  @override
  String get theoryKeyTitle => 'Clave para el examen';

  @override
  String get theorySectionExpandHint => 'Toca para desplegar';

  @override
  String get theorySectionCollapseHint => 'Toca para plegar';

  @override
  String theoryTableSemantics(int rows, int columns) {
    return 'Tabla de $rows filas y $columns columnas';
  }

  @override
  String theoryTableCell(String header, String value) {
    return '$header: $value';
  }

  @override
  String get theoryDiagramGaleria =>
      'Esquema de la galería de tiro: el puesto de tiro está detrás de la línea de tiro y la diana está a 25 metros; la zona entre la línea y la diana es la zona segura.';

  @override
  String get theoryDiagramZonaSegura =>
      'Esquema del sector de tiro: desde el puesto, el cañón apunta siempre hacia la dirección segura, dentro del sector de tiro.';

  @override
  String theoryDiagramSecuencia(int count) {
    return 'Secuencia de $count pasos';
  }

  @override
  String theoryDiagramStep(int n, String text) {
    return 'Paso $n: $text';
  }

  @override
  String get theoryDiagramPuesto => 'Puesto';

  @override
  String get theoryDiagramFiringLine => 'Línea de tiro';

  @override
  String get theoryDiagramTarget => 'Diana';

  @override
  String get theoryDiagramDistance => '25 m';

  @override
  String get theoryDiagramSafeZone => 'Zona segura';

  @override
  String get theoryDiagramSector => 'Sector de tiro';

  @override
  String get theoryDiagramSafeDirection => 'Dirección segura';

  @override
  String get theoryUnavailableTitle => 'La teoría no está disponible';

  @override
  String get theoryUnavailableMessage =>
      'Esta versión de la app no incluye los resúmenes. Actualiza la app para verlos.';

  @override
  String get mockFlagAction => 'Marcar como dudosa';

  @override
  String get mockFlagActive => 'Marcada como dudosa';

  @override
  String mockFlagCellAnswered(int number) {
    return 'Pregunta $number, respondida, dudosa';
  }

  @override
  String mockFlagCellBlank(int number) {
    return 'Pregunta $number, sin responder, dudosa';
  }

  @override
  String get mockFlagLegendAnswered => 'Respondida';

  @override
  String get mockFlagLegendBlank => 'Sin responder';

  @override
  String get mockFlagLegendDoubtful => 'Dudosa';

  @override
  String mockFlagSummary(int doubtful, int blank) {
    String _temp0 = intl.Intl.pluralLogic(
      doubtful,
      locale: localeName,
      other: '$doubtful dudosas',
      one: '1 dudosa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      blank,
      locale: localeName,
      other: '$blank sin responder',
      one: '1 sin responder',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String mockFlagSubmitBoth(int doubtful, int blank) {
    String _temp0 = intl.Intl.pluralLogic(
      doubtful,
      locale: localeName,
      other: '$doubtful dudosas',
      one: '1 dudosa',
    );
    String _temp1 = intl.Intl.pluralLogic(
      blank,
      locale: localeName,
      other: '$blank sin responder',
      one: '1 sin responder',
    );
    return 'Tienes $_temp0 y $_temp1. Las preguntas sin responder contarán como fallo.';
  }

  @override
  String mockFlagSubmitDoubtful(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Tienes $count preguntas dudosas. Puedes revisarlas antes de entregar.',
      one: 'Tienes 1 pregunta dudosa. Puedes revisarla antes de entregar.',
    );
    return '$_temp0';
  }

  @override
  String get searchTooltip => 'Buscar en las preguntas';

  @override
  String get searchTitle => 'Buscar preguntas';

  @override
  String get searchHint => 'Buscar en enunciados y opciones';

  @override
  String get searchClear => 'Borrar la búsqueda';

  @override
  String get searchPromptTitle => 'Busca en el banco de preguntas';

  @override
  String get searchPromptMessage =>
      'Escribe dos letras o más, o varias palabras del enunciado o de las opciones. No importan las tildes ni las mayúsculas.';

  @override
  String get searchNoResultsTitle => 'Sin resultados';

  @override
  String get searchNoResultsMessage =>
      'Prueba con otras palabras o con menos palabras.';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resultados',
      one: '1 resultado',
    );
    return '$_temp0';
  }

  @override
  String searchResultsTruncated(int shown) {
    return 'Se muestran las $shown primeras. Añade palabras para afinar la búsqueda.';
  }

  @override
  String searchResultSemantics(String tema, String stem) {
    return '$tema. $stem';
  }

  @override
  String get practiceFiguresTitle => 'Cifras y plazos';

  @override
  String get practiceDailyQuestionTitle => 'Pregunta del día';

  @override
  String get figuresEmptyTitle => 'No hay preguntas de cifras y plazos';

  @override
  String get figuresEmptyMessage =>
      'Este banco no contiene preguntas de cifras y plazos.';

  @override
  String get dailyEmptyTitle => 'Hoy no hay pregunta del día';

  @override
  String get dailyEmptyMessage => 'Vuelve mañana, o practica un tema.';

  @override
  String get homeFiguresTitle => 'Cifras y plazos';

  @override
  String homeFiguresSubtitle(int count) {
    return '$count preguntas de plazos, edades e importes';
  }

  @override
  String get homeFiguresCardsTitle => 'Tarjetas de cifras';

  @override
  String homeFiguresCardsSubtitle(int count) {
    return '$count tarjetas: piensa la respuesta y dale la vuelta';
  }

  @override
  String get figuresCardsReveal => 'Ver respuesta';

  @override
  String get figuresCardsKnown => 'La sabía';

  @override
  String get figuresCardsAgain => 'Repasar otra vez';

  @override
  String figuresCardsSummary(int known, int total) {
    return 'Sabías $known de $total a la primera';
  }

  @override
  String get figuresCardsRestart => 'Otra vez con las que repasé';

  @override
  String get figuresCardsBack => 'Volver';

  @override
  String get dailyTitle => 'Pregunta del día';

  @override
  String dailyStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Racha de $count días',
      one: 'Racha de 1 día',
    );
    return '$_temp0';
  }

  @override
  String get dailyAnswer => 'Responder';

  @override
  String get dailyDone => 'Respondida hoy';

  @override
  String get dailyDoneHint => 'Vuelve mañana para seguir con tu racha.';

  @override
  String get settingsOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get theoryPracticaSubtitle =>
      'Cómo es, qué se valora y qué te elimina';

  @override
  String theoryGlossarySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count términos explicados',
      one: '1 término explicado',
    );
    return '$_temp0';
  }
}
