import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// Nombre de la app: título de la barra superior y de la tarea en el sistema.
  ///
  /// In es, this message translates to:
  /// **'Ley al Blanco'**
  String get appTitle;

  /// Aviso legal fijo: la app no es oficial y cita la fuente del cuestionario. Se muestra en Inicio y en Ajustes.
  ///
  /// In es, this message translates to:
  /// **'App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil.'**
  String get legalDisclaimer;

  /// Botón para repetir una operación que ha fallado.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// Texto bajo el indicador de carga mientras arranca la app.
  ///
  /// In es, this message translates to:
  /// **'Preparando la app…'**
  String get bootstrapLoading;

  /// Título del error de arranque (base de datos o banco de preguntas).
  ///
  /// In es, this message translates to:
  /// **'No se ha podido preparar la app'**
  String get bootstrapFailed;

  /// Mensaje de error genérico, sin detalles técnicos.
  ///
  /// In es, this message translates to:
  /// **'Algo ha fallado. Inténtalo de nuevo.'**
  String get genericError;

  /// Botón para pasar a la pregunta siguiente (hoja de explicación y simulacro).
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get next;

  /// Botón para volver a la pregunta anterior en el simulacro.
  ///
  /// In es, this message translates to:
  /// **'Anterior'**
  String get previous;

  /// Botón que lleva a la pantalla de Inicio al terminar una sesión o un simulacro.
  ///
  /// In es, this message translates to:
  /// **'Volver al inicio'**
  String get backToHome;

  /// Botón para cerrar un diálogo sin hacer nada.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// Dos números separados por una barra: posición en la sesión ("3 / 20") o aciertos sobre total ("16 / 20"). Se muestran con cifras tabulares.
  ///
  /// In es, this message translates to:
  /// **'{a} / {b}'**
  String ratio(int a, int b);

  /// Lo que lee el lector de pantalla en la barra de progreso de una sesión o un simulacro (el texto visible es "5 / 68").
  ///
  /// In es, this message translates to:
  /// **'Pregunta {current} de {total}'**
  String progressSemantics(int current, int total);

  /// Contador de la práctica por tema: la posición dentro de la sesión y cuántas preguntas quedan por responder ("1 de 67 pendientes").
  ///
  /// In es, this message translates to:
  /// **'{index} de {count, plural, =1{1 pendiente} other{{count} pendientes}}'**
  String progressPendingCount(int index, int count);

  /// Lo que lee el lector de pantalla en la barra de progreso de la práctica por tema (el texto visible es "1 de 67 pendientes").
  ///
  /// In es, this message translates to:
  /// **'Pregunta {index} de {count, plural, =1{1 pendiente} other{{count} pendientes}}'**
  String progressPendingSemantics(int index, int count);

  /// Lo que lee el lector de pantalla en lugar de "16 / 20" (anillo del resultado, fila de un tema, resumen de la sesión).
  ///
  /// In es, this message translates to:
  /// **'{correct, plural, =1{1 acierto} other{{correct} aciertos}} de {total}'**
  String correctOfSemantics(int correct, int total);

  /// Lo que lee el lector de pantalla en una fila con título y subtítulo (un punto los separa).
  ///
  /// In es, this message translates to:
  /// **'{title}. {subtitle}'**
  String semanticsTitleSubtitle(String title, String subtitle);

  /// Etiqueta corta de un tema con su número, por ejemplo "Tema 3".
  ///
  /// In es, this message translates to:
  /// **'Tema {n}'**
  String temaLabel(int n);

  /// Título del estado de error cuando una pantalla no consigue leer los datos del dispositivo.
  ///
  /// In es, this message translates to:
  /// **'No se han podido cargar los datos'**
  String get loadErrorTitle;

  /// Nombre oficial del tema 1 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Funcionamiento y seguridad'**
  String get tema1;

  /// Nombre oficial del tema 2 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Categorías de armas'**
  String get tema2;

  /// Nombre oficial del tema 3 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Circulación, revista y transferencia'**
  String get tema3;

  /// Nombre oficial del tema 4 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Documentación y licencias, Tarjeta Europea'**
  String get tema4;

  /// Nombre oficial del tema 5 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Régimen sancionador'**
  String get tema5;

  /// Nombre oficial del tema 6 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Reparación, prueba y depósito'**
  String get tema6;

  /// Nombre oficial del tema 7 del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Armas de colección, definiciones, historia, calibres y munición'**
  String get tema7;

  /// Pie del anillo de Inicio: estimación de aprobar un simulacro hoy.
  ///
  /// In es, this message translates to:
  /// **'Probabilidad de aprobar'**
  String get homePassProbability;

  /// Botón principal de Inicio: empieza el repaso del día.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get homeContinue;

  /// Bajo el botón Continuar: cuántas preguntas tiene el repaso del día.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 pregunta para hoy} other{{count} preguntas para hoy}}'**
  String homeContinueCount(int count);

  /// Mensaje de Inicio cuando el repaso del día no tiene preguntas; el botón Continuar queda desactivado.
  ///
  /// In es, this message translates to:
  /// **'Has terminado el repaso de hoy. Puedes practicar un tema o hacer un simulacro.'**
  String get homeContinueDone;

  /// Título del acceso al simulacro en Inicio.
  ///
  /// In es, this message translates to:
  /// **'Simulacro'**
  String get homeMockTitle;

  /// Subtítulo del acceso al simulacro en Inicio.
  ///
  /// In es, this message translates to:
  /// **'Un examen completo, como el real'**
  String get homeMockSubtitle;

  /// Título del acceso a la lista de fallos en Inicio y de su pantalla.
  ///
  /// In es, this message translates to:
  /// **'Fallos'**
  String get homeMistakesTitle;

  /// Subtítulo del acceso a Fallos: cuántas preguntas siguen en la lista.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Sin fallos pendientes} =1{1 fallo pendiente} other{{count} fallos pendientes}}'**
  String mistakesCount(int count);

  /// Título de la sección con las siete tarjetas de tema en Inicio.
  ///
  /// In es, this message translates to:
  /// **'Temas'**
  String get homeTemasTitle;

  /// Texto de la tarjeta de tema: nivel de dominio ya formateado ("Dominio 45 %").
  ///
  /// In es, this message translates to:
  /// **'Dominio {percent}'**
  String temaCardMastery(String percent);

  /// Texto de la tarjeta de tema: fallos pendientes del tema (solo si hay alguno).
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 fallo} other{{count} fallos}}'**
  String temaCardMistakes(int count);

  /// Línea bajo la barra de dominio de la tarjeta de tema: el dominio es 0 % y el tema ya tiene intentos, así que el usuario está por debajo del azar.
  ///
  /// In es, this message translates to:
  /// **'Por debajo del azar: repasa la teoría'**
  String get temaCardBelowChance;

  /// Pie de Inicio con la edición del banco de preguntas, por ejemplo "Cuestionario GC nov-2020".
  ///
  /// In es, this message translates to:
  /// **'Cuestionario {edition}'**
  String bankEdition(String edition);

  /// Descripción para lector de pantalla del anillo de puntuación.
  ///
  /// In es, this message translates to:
  /// **'{label}: {percent}'**
  String scoreRingSemantics(String label, String percent);

  /// Descripción para lector de pantalla del anillo mientras aún no hay valor.
  ///
  /// In es, this message translates to:
  /// **'Calculando'**
  String get scoreRingUnknown;

  /// Descripción para lector de pantalla de una opción de respuesta (letra y texto).
  ///
  /// In es, this message translates to:
  /// **'Opción {letter}: {text}'**
  String optionSemantics(String letter, String text);

  /// Etiqueta accesible de la opción correcta (junto al icono de verificación).
  ///
  /// In es, this message translates to:
  /// **'Correcta'**
  String get optionCorrect;

  /// Etiqueta accesible de la opción elegida que es incorrecta (junto al icono de cruz).
  ///
  /// In es, this message translates to:
  /// **'Incorrecta'**
  String get optionIncorrect;

  /// Descripción para lector de pantalla de la barra de dominio.
  ///
  /// In es, this message translates to:
  /// **'Dominio {percent}'**
  String masteryBarSemantics(String percent);

  /// Veredicto en la hoja de explicación cuando se acierta.
  ///
  /// In es, this message translates to:
  /// **'Correcto'**
  String get explanationCorrect;

  /// Veredicto en la hoja de explicación cuando se falla.
  ///
  /// In es, this message translates to:
  /// **'Incorrecto'**
  String get explanationIncorrect;

  /// Encabezado que precede a la respuesta correcta en la hoja de explicación.
  ///
  /// In es, this message translates to:
  /// **'Respuesta correcta'**
  String get explanationCorrectAnswer;

  /// Letra y texto de una opción mostrados como respuesta.
  ///
  /// In es, this message translates to:
  /// **'{letter}. {text}'**
  String explanationAnswerLine(String letter, String text);

  /// Encabezado del texto explicativo de una pregunta.
  ///
  /// In es, this message translates to:
  /// **'Explicación'**
  String get explanationHeading;

  /// Texto provisional cuando la pregunta aún no tiene explicación propia.
  ///
  /// In es, this message translates to:
  /// **'Explicación en preparación'**
  String get explanationPending;

  /// Título del recuadro de aviso que precede a la explicación cuando la normativa vigente puede discrepar de la respuesta oficial del cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Aviso: cambio en la norma'**
  String get noticeTitle;

  /// Descripción para lector de pantalla de la ficha del artículo citado.
  ///
  /// In es, this message translates to:
  /// **'Fuente: {article}'**
  String articleChipSemantics(String article);

  /// Título de la pantalla de práctica cuando es el repaso del día.
  ///
  /// In es, this message translates to:
  /// **'Repaso del día'**
  String get practiceDailyTitle;

  /// Título de la pantalla de práctica cuando se repasan los fallos.
  ///
  /// In es, this message translates to:
  /// **'Repasar fallos'**
  String get practiceMistakesTitle;

  /// Título de la pantalla de práctica cuando se repasan solo los fallos de un simulacro.
  ///
  /// In es, this message translates to:
  /// **'Fallos del simulacro'**
  String get practiceMockMistakesTitle;

  /// Título de la pantalla de práctica de un tema: su etiqueta con el número y el nombre oficial.
  ///
  /// In es, this message translates to:
  /// **'{tema} · {title}'**
  String practiceTemaTitle(String tema, String title);

  /// Botón de la hoja de explicación en la última pregunta de la sesión.
  ///
  /// In es, this message translates to:
  /// **'Terminar'**
  String get practiceFinish;

  /// Aviso breve cuando falla el guardado de una respuesta en el dispositivo.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido guardar tu respuesta. Inténtalo de nuevo.'**
  String get practiceSaveError;

  /// Título cuando el repaso del día está vacío.
  ///
  /// In es, this message translates to:
  /// **'Hoy no quedan preguntas'**
  String get practiceEmptyDailyTitle;

  /// Mensaje cuando el repaso del día está vacío.
  ///
  /// In es, this message translates to:
  /// **'Vuelve mañana, o practica un tema o haz un simulacro.'**
  String get practiceEmptyDailyMessage;

  /// Título cuando se abre el repaso de fallos sin ninguno.
  ///
  /// In es, this message translates to:
  /// **'No hay fallos que repasar'**
  String get practiceEmptyMistakesTitle;

  /// Mensaje cuando se abre el repaso de fallos sin ninguno.
  ///
  /// In es, this message translates to:
  /// **'Las preguntas que falles aparecerán aquí.'**
  String get practiceEmptyMistakesMessage;

  /// Título del resumen al acabar una sesión de práctica.
  ///
  /// In es, this message translates to:
  /// **'Sesión terminada'**
  String get practiceSummaryTitle;

  /// Etiqueta junto al número de aciertos del resumen de la sesión.
  ///
  /// In es, this message translates to:
  /// **'Aciertos'**
  String get practiceSummaryScore;

  /// Título de las pantallas del simulacro.
  ///
  /// In es, this message translates to:
  /// **'Simulacro'**
  String get mockTitle;

  /// Explicación del simulacro en su pantalla de introducción.
  ///
  /// In es, this message translates to:
  /// **'{size} preguntas de test con tres opciones, como en el examen. Se aprueba con {passMark} aciertos.'**
  String mockIntroBody(int size, int passMark);

  /// Segunda frase de la introducción del simulacro: cómo funciona la corrección.
  ///
  /// In es, this message translates to:
  /// **'No verás si aciertas hasta entregar, y puedes cambiar una respuesta antes de entregar. Las preguntas sin responder cuentan como fallo.'**
  String get mockIntroNoFeedback;

  /// Interruptor opcional para activar el cronómetro del simulacro.
  ///
  /// In es, this message translates to:
  /// **'Cronómetro orientativo ({minutes} min)'**
  String mockTimerSwitch(int minutes);

  /// Aclaración bajo el interruptor del cronómetro.
  ///
  /// In es, this message translates to:
  /// **'El tiempo real del examen no consta en el BOE: es solo una guía y no corta el simulacro.'**
  String get mockTimerHelp;

  /// Botón que crea el simulacro y lo abre.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get mockStart;

  /// Aviso cuando falla la creación del simulacro.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido crear el simulacro. Inténtalo de nuevo.'**
  String get mockStartError;

  /// Botón de la introducción del simulacro que crea uno nuevo cuando hay otro sin entregar.
  ///
  /// In es, this message translates to:
  /// **'Empezar otro'**
  String get mockStartAnother;

  /// Título de la tarjeta de la introducción que ofrece retomar el simulacro que se dejó a medias.
  ///
  /// In es, this message translates to:
  /// **'Tienes un simulacro sin entregar'**
  String get mockResumeTitle;

  /// Progreso del simulacro sin entregar: preguntas respondidas sobre el total.
  ///
  /// In es, this message translates to:
  /// **'{answered} de {total} respondidas'**
  String mockResumeProgress(int answered, int total);

  /// Botón que reabre el simulacro sin entregar donde se dejó.
  ///
  /// In es, this message translates to:
  /// **'Continuar simulacro'**
  String get mockResume;

  /// Subtítulo del acceso al simulacro en Inicio cuando hay un simulacro a medias que se puede retomar.
  ///
  /// In es, this message translates to:
  /// **'Tienes uno sin entregar'**
  String get homeMockResumeSubtitle;

  /// Título del diálogo que avisa de que empezar otro simulacro descarta el que está sin entregar.
  ///
  /// In es, this message translates to:
  /// **'¿Empezar otro simulacro?'**
  String get mockReplaceTitle;

  /// Cuerpo del diálogo de empezar otro simulacro.
  ///
  /// In es, this message translates to:
  /// **'El simulacro sin entregar se descartará y no podrás retomarlo.'**
  String get mockReplaceBody;

  /// No description provided for @mockHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has entregado ninguno.'**
  String get mockHistoryEmpty;

  /// No description provided for @mockHistoryDateTime.
  ///
  /// In es, this message translates to:
  /// **'{date} · {time}'**
  String mockHistoryDateTime(String date, String time);

  /// No description provided for @settingsImportErrorDateTime.
  ///
  /// In es, this message translates to:
  /// **'El archivo contiene una fecha u hora no válida. No se ha cambiado nada.'**
  String get settingsImportErrorDateTime;

  /// No description provided for @settingsImportErrorTooDeep.
  ///
  /// In es, this message translates to:
  /// **'El archivo está demasiado anidado o dañado. No se ha cambiado nada.'**
  String get settingsImportErrorTooDeep;

  /// Encabezado de la lista de simulacros entregados en la introducción del simulacro.
  ///
  /// In es, this message translates to:
  /// **'Tus simulacros'**
  String get mockHistoryTitle;

  /// Aciertos de un simulacro en la lista de simulacros ("16 de 20"), con cifras tabulares.
  ///
  /// In es, this message translates to:
  /// **'{correct} de {total}'**
  String mockHistoryScore(int correct, int total);

  /// Lo que lee el lector de pantalla en una fila de la lista de simulacros: fecha, aciertos y veredicto.
  ///
  /// In es, this message translates to:
  /// **'Simulacro del {date}. {score}. {verdict}'**
  String mockHistoryRowSemantics(String date, String score, String verdict);

  /// Cuenta atrás del simulacro con el tiempo restante ya formateado ("12:05").
  ///
  /// In es, this message translates to:
  /// **'Quedan {time}'**
  String mockTimerRemaining(String time);

  /// Aviso cuando la cuenta atrás llega a cero; no se entrega solo.
  ///
  /// In es, this message translates to:
  /// **'Tiempo orientativo agotado'**
  String get mockTimerExpired;

  /// Botón que abre el navegador con las 20 preguntas del simulacro.
  ///
  /// In es, this message translates to:
  /// **'Preguntas'**
  String get mockQuestions;

  /// Título de la hoja con el navegador de preguntas del simulacro.
  ///
  /// In es, this message translates to:
  /// **'Ir a la pregunta'**
  String get mockNavigatorTitle;

  /// Descripción accesible de una celda del navegador con respuesta.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {number}, respondida'**
  String navigatorCellAnswered(int number);

  /// Descripción accesible de una celda del navegador sin respuesta.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {number}, sin responder'**
  String navigatorCellBlank(int number);

  /// Botón para entregar el simulacro.
  ///
  /// In es, this message translates to:
  /// **'Entregar'**
  String get mockSubmit;

  /// Título del diálogo de confirmación al entregar.
  ///
  /// In es, this message translates to:
  /// **'¿Entregar el simulacro?'**
  String get mockSubmitTitle;

  /// Cuerpo del diálogo de entrega: cuántas preguntas quedan en blanco.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Has respondido todas las preguntas.} =1{Te queda 1 pregunta sin responder y contará como fallo.} other{Te quedan {count} preguntas sin responder y contarán como fallo.}}'**
  String mockSubmitUnanswered(int count);

  /// Botón del diálogo de entrega para volver al simulacro.
  ///
  /// In es, this message translates to:
  /// **'Seguir'**
  String get mockSubmitKeep;

  /// Título del diálogo al pulsar atrás durante el simulacro.
  ///
  /// In es, this message translates to:
  /// **'¿Salir del simulacro?'**
  String get mockLeaveTitle;

  /// Cuerpo del diálogo al pulsar atrás durante el simulacro: se puede retomar.
  ///
  /// In es, this message translates to:
  /// **'Si sales ahora, el simulacro queda sin entregar. Podrás retomarlo desde Simulacro.'**
  String get mockLeaveBody;

  /// Botón que abandona el simulacro.
  ///
  /// In es, this message translates to:
  /// **'Salir'**
  String get mockLeaveConfirm;

  /// Tiempo transcurrido entre el inicio y la entrega del simulacro; solo se muestra si consta la hora de entrega.
  ///
  /// In es, this message translates to:
  /// **'Tiempo empleado: {duration}'**
  String mockResultElapsedTime(String duration);

  /// Duración en minutos totales y segundos restantes, sin límite de minutos ni conversión a horas.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min {seconds} s'**
  String elapsedMinutesSeconds(int minutes, int seconds);

  /// Resultado del simulacro cuando se llega al mínimo de aciertos.
  ///
  /// In es, this message translates to:
  /// **'APTO'**
  String get mockResultPassed;

  /// Resultado del simulacro cuando no se llega al mínimo de aciertos.
  ///
  /// In es, this message translates to:
  /// **'NO APTO'**
  String get mockResultFailed;

  /// Pie del anillo del resultado: explica la marca del anillo (el mínimo de aciertos para aprobar).
  ///
  /// In es, this message translates to:
  /// **'La marca indica el aprobado: {passMark} aciertos.'**
  String mockResultPassMarkHint(int passMark);

  /// Bajo la puntuación grande del resultado: "de 20".
  ///
  /// In es, this message translates to:
  /// **'de {total}'**
  String mockResultOutOf(int total);

  /// Encabezado de la tabla de aciertos por tema.
  ///
  /// In es, this message translates to:
  /// **'Aciertos por tema'**
  String get mockResultPerTema;

  /// Encabezado de la lista de las preguntas del simulacro en el resultado (todas, o solo las falladas con el filtro).
  ///
  /// In es, this message translates to:
  /// **'Preguntas'**
  String get mockResultQuestionsTitle;

  /// Filtro del resultado del simulacro: activo muestra solo las preguntas falladas, inactivo las veinte.
  ///
  /// In es, this message translates to:
  /// **'Solo falladas'**
  String get mockResultOnlyFailed;

  /// Lo que lee el lector de pantalla en la fila de una pregunta acertada del resultado.
  ///
  /// In es, this message translates to:
  /// **'Acertada'**
  String get mockResultRowCorrect;

  /// Lo que lee el lector de pantalla en la fila de una pregunta fallada del resultado.
  ///
  /// In es, this message translates to:
  /// **'Fallada'**
  String get mockResultRowFailed;

  /// Lo que lee el lector de pantalla en la cabecera del resultado del simulacro (tema, título y aciertos).
  ///
  /// In es, this message translates to:
  /// **'{tema}. {title}. {score}'**
  String mockResultHeaderSemantics(String tema, String title, String score);

  /// Lo que lee el lector de pantalla en la fila de una pregunta del resultado del simulacro (número, enunciado, acierto o fallo y respuesta del usuario).
  ///
  /// In es, this message translates to:
  /// **'{number}. {stem}. {status}. {answer}'**
  String mockResultRowSemantics(
    int number,
    String stem,
    String status,
    String answer,
  );

  /// Título de la fila de una pregunta del resultado del simulacro: su número y su enunciado.
  ///
  /// In es, this message translates to:
  /// **'{number}. {stem}'**
  String mockResultRowTitle(int number, String stem);

  /// Texto cuando el simulacro no tiene fallos.
  ///
  /// In es, this message translates to:
  /// **'No has fallado ninguna pregunta.'**
  String get mockResultNoFailed;

  /// Botón del resultado que abre el repaso de los fallos del simulacro, con su número.
  ///
  /// In es, this message translates to:
  /// **'Repasar {count, plural, =1{el fallo} other{los {count} fallos}}'**
  String mockResultReviewMistakesCount(int count);

  /// Mensaje si se abre el resultado de un simulacro sin entregar.
  ///
  /// In es, this message translates to:
  /// **'Este simulacro no se ha entregado.'**
  String get mockResultNotFinished;

  /// Texto de la respuesta del usuario cuando dejó la pregunta en blanco.
  ///
  /// In es, this message translates to:
  /// **'Sin responder'**
  String get mockResultUnanswered;

  /// Título de la pantalla de revisión de una pregunta fallada.
  ///
  /// In es, this message translates to:
  /// **'Revisión'**
  String get mockReviewTitle;

  /// Posición de la pregunta que se revisa dentro del simulacro, sobre la tarjeta de la pregunta.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {current} de {total}'**
  String mockReviewPosition(int current, int total);

  /// Respuesta elegida por el usuario en la revisión: la letra de la opción que marcó.
  ///
  /// In es, this message translates to:
  /// **'Tu respuesta: {letter}'**
  String mockReviewYourAnswer(String letter);

  /// Filtro de la lista de fallos que no limita por tema.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get mistakesFilterAll;

  /// Botón que empieza el repaso de los fallos mostrados.
  ///
  /// In es, this message translates to:
  /// **'Repasar todos'**
  String get mistakesReviewAll;

  /// Título del estado vacío de la lista de fallos.
  ///
  /// In es, this message translates to:
  /// **'No tienes fallos pendientes'**
  String get mistakesEmptyTitle;

  /// Mensaje del estado vacío de la lista de fallos.
  ///
  /// In es, this message translates to:
  /// **'Las preguntas que falles aparecerán aquí hasta que las aciertes dos veces seguidas.'**
  String get mistakesEmptyMessage;

  /// Pista de accesibilidad de cada fila de Fallos: al tocarla se abre la ficha del fallo (respuesta, explicación y accesos a la teoría y a la práctica).
  ///
  /// In es, this message translates to:
  /// **'Toca para ver la ficha de este fallo'**
  String get mistakesRowHint;

  /// Ficha de un fallo: qué opción marcó el usuario la última vez que falló la pregunta.
  ///
  /// In es, this message translates to:
  /// **'Tu última respuesta: {letter}'**
  String mistakeSheetLastAnswer(String letter);

  /// Ficha de un fallo: botón que abre el resumen de teoría del tema de la pregunta.
  ///
  /// In es, this message translates to:
  /// **'Ver la teoría del tema {n}'**
  String mistakeSheetTheory(int n);

  /// Ficha de un fallo: botón que abre el repaso de fallos empezando por esta pregunta.
  ///
  /// In es, this message translates to:
  /// **'Practicar esta pregunta'**
  String get mistakeSheetPractice;

  /// Cuántas veces se ha fallado una pregunta de la lista.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Fallada 1 vez} other{Fallada {count} veces}}'**
  String mistakesWrongCount(int count);

  /// Etiqueta (lector de pantalla y ayuda) del botón redondo que cierra una sesión o un resultado.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get close;

  /// Frase de estado bajo la etiqueta de la probabilidad de aprobar en la tarjeta de Inicio.
  ///
  /// In es, this message translates to:
  /// **'Estimación según tus respuestas'**
  String get homeStatusLine;

  /// Etiqueta (lector de pantalla y ayuda) del botón redondo de Inicio que abre Ajustes.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get homeSettings;

  /// Título de la pantalla de Ajustes.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// Etiqueta de la sección de apariencia en Ajustes (se muestra en mayúsculas).
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get settingsAppearanceSection;

  /// Nombre leído por el lector de pantalla del selector Sistema / Claro / Oscuro.
  ///
  /// In es, this message translates to:
  /// **'Tema de la app'**
  String get settingsThemeGroup;

  /// Opción de apariencia: sigue el modo claro u oscuro del móvil.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get settingsThemeSystem;

  /// Opción de apariencia: siempre claro.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get settingsThemeLight;

  /// Opción de apariencia: siempre oscuro.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get settingsThemeDark;

  /// Encabezado de la sección de Ajustes para exportar e importar el progreso.
  ///
  /// In es, this message translates to:
  /// **'Tus datos'**
  String get settingsDataSection;

  /// Título de la fila que guarda el progreso en un archivo.
  ///
  /// In es, this message translates to:
  /// **'Exportar progreso'**
  String get settingsExportTitle;

  /// Subtítulo de la fila de exportar.
  ///
  /// In es, this message translates to:
  /// **'Guarda tus respuestas, fallos y simulacros en un archivo para cambiar de móvil. Tú eliges dónde.'**
  String get settingsExportSubtitle;

  /// Título de la fila que recupera el progreso de un archivo.
  ///
  /// In es, this message translates to:
  /// **'Importar progreso'**
  String get settingsImportTitle;

  /// Subtítulo de la fila de importar.
  ///
  /// In es, this message translates to:
  /// **'Recupera un archivo exportado antes. Reemplaza el progreso de este móvil.'**
  String get settingsImportSubtitle;

  /// Aviso cuando el archivo de progreso se ha guardado.
  ///
  /// In es, this message translates to:
  /// **'Progreso guardado.'**
  String get settingsExportDone;

  /// Error al exportar: el archivo superaría el tamaño máximo que la app sabe importar.
  ///
  /// In es, this message translates to:
  /// **'Tu progreso ocupa más de 10 MB y no se puede exportar. No se ha guardado nada.'**
  String get settingsExportTooLarge;

  /// Texto (lector de pantalla) del indicador de progreso mientras se prepara o se lee un archivo de progreso.
  ///
  /// In es, this message translates to:
  /// **'Procesando el archivo…'**
  String get settingsTransferWorking;

  /// Aviso cuando falla el guardado del archivo de progreso.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido guardar el archivo.'**
  String get settingsExportFailed;

  /// Título del diálogo de confirmación de la importación.
  ///
  /// In es, this message translates to:
  /// **'¿Reemplazar tu progreso?'**
  String get settingsImportConfirmTitle;

  /// Texto del diálogo de confirmación antes de la lista de lo que trae el archivo.
  ///
  /// In es, this message translates to:
  /// **'Reemplaza tu progreso actual por el del archivo. No se puede deshacer. El archivo trae:'**
  String get settingsImportConfirmBody;

  /// Respuestas que trae el archivo de progreso.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 respuesta} other{{count} respuestas}}'**
  String settingsImportSummaryAnswers(int count);

  /// Cuántas de las respuestas del archivo eran fallos; va detrás de «de ellas».
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{ninguna fallada} =1{1 fallada} other{{count} falladas}}'**
  String settingsImportSummaryWrong(int count);

  /// Une el número de respuestas y el de falladas en una línea (p. ej. «120 respuestas, de ellas 30 falladas»).
  ///
  /// In es, this message translates to:
  /// **'{answers}, de ellas {wrong}'**
  String settingsImportSummaryAnswersWrong(String answers, String wrong);

  /// Simulacros que trae el archivo de progreso.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ningún simulacro} =1{1 simulacro} other{{count} simulacros}}'**
  String settingsImportSummaryMocks(int count);

  /// Preguntas con repaso espaciado que trae el archivo.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Ninguna pregunta en el repaso diario} =1{1 pregunta en el repaso diario} other{{count} preguntas en el repaso diario}}'**
  String settingsImportSummaryReview(int count);

  /// Fecha en que se exportó el archivo, con el formato de fechas de la app (por ejemplo, 20 oct 2026).
  ///
  /// In es, this message translates to:
  /// **'Exportado el {date}'**
  String settingsImportSummaryDate(String date);

  /// Aviso de lo que se descarta porque su pregunta no está en el banco o su fecha es imposible.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Se ignorará 1 dato que no se puede usar (de una pregunta que ya no existe o con una fecha imposible).} other{Se ignorarán {count} datos que no se pueden usar (de preguntas que ya no existen o con una fecha imposible).}}'**
  String settingsImportDiscarded(int count);

  /// Botón que confirma la importación.
  ///
  /// In es, this message translates to:
  /// **'Reemplazar'**
  String get settingsImportReplace;

  /// Aviso cuando la importación ha terminado.
  ///
  /// In es, this message translates to:
  /// **'Progreso importado.'**
  String get settingsImportDone;

  /// Título del diálogo de error de importación.
  ///
  /// In es, this message translates to:
  /// **'No se puede importar'**
  String get settingsImportErrorTitle;

  /// Error: el archivo supera el tamaño máximo.
  ///
  /// In es, this message translates to:
  /// **'El archivo es demasiado grande para ser un progreso de Ley al Blanco (máximo 10 MB). No se ha cambiado nada.'**
  String get settingsImportErrorTooLarge;

  /// Error: el archivo no se puede leer como JSON.
  ///
  /// In es, this message translates to:
  /// **'El archivo está dañado o no es un archivo de progreso. No se ha cambiado nada.'**
  String get settingsImportErrorNotJson;

  /// Error: el JSON no es un archivo de progreso de la app.
  ///
  /// In es, this message translates to:
  /// **'Este archivo no es un progreso exportado por Ley al Blanco. No se ha cambiado nada.'**
  String get settingsImportErrorWrongFormat;

  /// Error: el archivo es de una versión posterior del formato.
  ///
  /// In es, this message translates to:
  /// **'Este archivo es de una versión más nueva de Ley al Blanco. Actualiza la app e inténtalo de nuevo. No se ha cambiado nada.'**
  String get settingsImportErrorNewerVersion;

  /// Error: el archivo se hizo con otra edición del banco de preguntas.
  ///
  /// In es, this message translates to:
  /// **'Este archivo es de otra edición del banco de preguntas y sus respuestas no coincidirían con las de esta app. No se ha cambiado nada.'**
  String get settingsImportErrorWrongEdition;

  /// Error: algún campo del archivo tiene un tipo o un valor incorrecto.
  ///
  /// In es, this message translates to:
  /// **'El archivo tiene datos que no son válidos. No se ha cambiado nada y tu progreso sigue igual.'**
  String get settingsImportErrorInvalid;

  /// Error: falló la lectura del archivo o la escritura en la base de datos.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido importar el archivo. Tu progreso sigue igual.'**
  String get settingsImportErrorFailed;

  /// Botón que cierra el diálogo de error.
  ///
  /// In es, this message translates to:
  /// **'Entendido'**
  String get settingsImportErrorOk;

  /// Etiqueta de la sección con la fuente del banco en Ajustes (se muestra en mayúsculas).
  ///
  /// In es, this message translates to:
  /// **'Banco de preguntas'**
  String get settingsBankSection;

  /// Fila: edición del cuestionario incluida en la app.
  ///
  /// In es, this message translates to:
  /// **'Edición'**
  String get settingsBankEdition;

  /// Valor de la fila Edición, p. ej. «Cuestionario GC nov-2020».
  ///
  /// In es, this message translates to:
  /// **'Cuestionario {edition}'**
  String settingsBankEditionValue(String edition);

  /// Fila: número de preguntas del banco.
  ///
  /// In es, this message translates to:
  /// **'Preguntas'**
  String get settingsBankQuestions;

  /// Fila: fecha en que se descargó el cuestionario de la fuente.
  ///
  /// In es, this message translates to:
  /// **'Consultado'**
  String get settingsBankRetrieved;

  /// Enlace a la página de la Guardia Civil donde se publica el cuestionario.
  ///
  /// In es, this message translates to:
  /// **'Ver la fuente original'**
  String get settingsBankSource;

  /// Etiqueta de la sección de ayuda en Ajustes (se muestra en mayúsculas).
  ///
  /// In es, this message translates to:
  /// **'Ayuda'**
  String get settingsHelpSection;

  /// Fila que abre el correo hacia soporte.
  ///
  /// In es, this message translates to:
  /// **'Escribir a soporte'**
  String get settingsSupportTitle;

  /// Promesa de respuesta de soporte (spec: menos de 48 h).
  ///
  /// In es, this message translates to:
  /// **'Respondemos en menos de 48 h'**
  String get settingsSupportSubtitle;

  /// Asunto del correo a soporte.
  ///
  /// In es, this message translates to:
  /// **'Ley al Blanco {version}'**
  String settingsSupportMailSubject(String version);

  /// Cuerpo precargado del correo a soporte: solo versión de la app y plataforma, nunca datos personales ni del progreso.
  ///
  /// In es, this message translates to:
  /// **'\n\n---\nApp: Ley al Blanco {version}\nSistema: {platform}'**
  String settingsSupportMailBody(String version, String platform);

  /// Acción discreta bajo la explicación de una pregunta: abre el correo a soporte para avisar de un posible error. Solo aparece si la compilación tiene un correo de soporte válido.
  ///
  /// In es, this message translates to:
  /// **'¿Ves un error? Avísanos'**
  String get explanationReport;

  /// Asunto del correo de aviso de error en una pregunta.
  ///
  /// In es, this message translates to:
  /// **'Error en la pregunta {id} · Ley al Blanco {version}'**
  String explanationReportMailSubject(String id, String version);

  /// Cuerpo precargado del aviso de error: datos de la pregunta (id, edición, tema, enunciado recortado, letra oficial, explicación y artículo actuales) y versión y plataforma de la app; nunca datos personales ni del progreso. Termina con la línea donde el usuario cuenta qué está mal.
  ///
  /// In es, this message translates to:
  /// **'Pregunta: {id}\nEdición: {edition}\nTema: {tema}\nEnunciado: {stem}\nRespuesta oficial: {letter}\nExplicación actual: {explanation}\nArtículo: {article}\nApp: Ley al Blanco {version}\nSistema: {platform}\n\nCuéntanos qué está mal:\n'**
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
  );

  /// Enlace a la política de privacidad publicada.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get settingsPrivacyPolicy;

  /// Aviso cuando el sistema no puede abrir un enlace o el correo.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido abrir el enlace.'**
  String get settingsOpenFailed;

  /// Aviso legal fijo del pie de Ajustes (spec §3.2).
  ///
  /// In es, this message translates to:
  /// **'App independiente y no oficial. Preguntas basadas en el cuestionario publicado por la Dirección General de la Guardia Civil (consultado el {date}). Las explicaciones son de redacción propia y no constituyen asesoramiento jurídico.'**
  String settingsLegal(String date);

  /// Versión de la app en el pie de Ajustes.
  ///
  /// In es, this message translates to:
  /// **'Versión {version}'**
  String settingsVersion(String version);

  /// Título de la tesela de Inicio que abre los resúmenes de teoría.
  ///
  /// In es, this message translates to:
  /// **'Teoría'**
  String get homeTheoryTitle;

  /// Subtítulo de la tesela Teoría de Inicio.
  ///
  /// In es, this message translates to:
  /// **'Resúmenes y prueba práctica'**
  String get homeTheorySubtitle;

  /// Título de la barra superior de la lista de teoría.
  ///
  /// In es, this message translates to:
  /// **'Teoría'**
  String get theoryTitle;

  /// Texto de introducción de la lista de teoría.
  ///
  /// In es, this message translates to:
  /// **'Repasa lo que entra en cada tema antes de practicar, o después de fallar. No sustituye al Reglamento: lo ordena y cita el artículo de cada dato.'**
  String get theoryIntro;

  /// Título de la tarjeta destacada (y del documento) de la prueba práctica de tiro.
  ///
  /// In es, this message translates to:
  /// **'La prueba práctica'**
  String get theoryPracticaTitle;

  /// Encabezado de la tarjeta con los siete resúmenes de tema.
  ///
  /// In es, this message translates to:
  /// **'Resúmenes por tema'**
  String get theoryTemasTitle;

  /// Tiempo de lectura del resumen de un tema.
  ///
  /// In es, this message translates to:
  /// **'{minutes} min de lectura'**
  String theoryRead(int minutes);

  /// Etiqueta sobre el título del resumen de un tema.
  ///
  /// In es, this message translates to:
  /// **'Tema {n} · Teoría'**
  String theoryTemaOverline(int n);

  /// Etiqueta sobre el título de la prueba práctica.
  ///
  /// In es, this message translates to:
  /// **'Teoría · Prueba práctica'**
  String get theoryPracticaOverline;

  /// Botón inferior del resumen de un tema: abre la práctica de ese tema.
  ///
  /// In es, this message translates to:
  /// **'Practicar este tema'**
  String get theoryPracticeThisTema;

  /// Encabezado de la tarjeta con los documentos gratuitos que no son de un tema (AEM y glosario) en la lista de teoría.
  ///
  /// In es, this message translates to:
  /// **'Para completar'**
  String get theoryExtrasTitle;

  /// Etiqueta sobre el título del documento de la autorización especial para menores.
  ///
  /// In es, this message translates to:
  /// **'Teoría · Menores (AEM)'**
  String get theoryAemOverline;

  /// Etiqueta sobre el título del glosario.
  ///
  /// In es, this message translates to:
  /// **'Teoría · Glosario'**
  String get theoryGlosarioOverline;

  /// Texto de ayuda del campo de búsqueda del glosario.
  ///
  /// In es, this message translates to:
  /// **'Buscar en el glosario'**
  String get theoryGlossarySearchHint;

  /// Etiqueta del botón que borra el texto del campo de búsqueda del glosario.
  ///
  /// In es, this message translates to:
  /// **'Borrar la búsqueda'**
  String get theoryGlossarySearchClear;

  /// Número de términos del glosario que coinciden con la búsqueda; se anuncia a los lectores de pantalla.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 término} other{{count} términos}}'**
  String theoryGlossaryResults(int count);

  /// Título cuando la búsqueda del glosario no encuentra nada.
  ///
  /// In es, this message translates to:
  /// **'Ningún término coincide'**
  String get theoryGlossaryNoResultsTitle;

  /// Texto cuando la búsqueda del glosario no encuentra nada.
  ///
  /// In es, this message translates to:
  /// **'Prueba con otra palabra o con menos letras.'**
  String get theoryGlossaryNoResultsMessage;

  /// Título del recuadro de lo que más aparece en el examen.
  ///
  /// In es, this message translates to:
  /// **'Clave para el examen'**
  String get theoryKeyTitle;

  /// Pista de lector de pantalla de una sección plegada.
  ///
  /// In es, this message translates to:
  /// **'Toca para desplegar'**
  String get theorySectionExpandHint;

  /// Pista de lector de pantalla de una sección desplegada.
  ///
  /// In es, this message translates to:
  /// **'Toca para plegar'**
  String get theorySectionCollapseHint;

  /// Descripción de una tabla para lector de pantalla.
  ///
  /// In es, this message translates to:
  /// **'Tabla de {rows} filas y {columns} columnas'**
  String theoryTableSemantics(int rows, int columns);

  /// Una celda de tabla leída con el nombre de su columna.
  ///
  /// In es, this message translates to:
  /// **'{header}: {value}'**
  String theoryTableCell(String header, String value);

  /// Descripción para lector de pantalla del esquema de la galería de tiro.
  ///
  /// In es, this message translates to:
  /// **'Esquema de la galería de tiro: el puesto de tiro está detrás de la línea de tiro y la diana está a 25 metros; la zona entre la línea y la diana es la zona segura.'**
  String get theoryDiagramGaleria;

  /// Descripción para lector de pantalla del esquema del sector de tiro.
  ///
  /// In es, this message translates to:
  /// **'Esquema del sector de tiro: desde el puesto, el cañón apunta siempre hacia la dirección segura, dentro del sector de tiro.'**
  String get theoryDiagramZonaSegura;

  /// Descripción de una secuencia de pasos numerados para lector de pantalla.
  ///
  /// In es, this message translates to:
  /// **'Secuencia de {count} pasos'**
  String theoryDiagramSecuencia(int count);

  /// Un paso de una secuencia leído con su número.
  ///
  /// In es, this message translates to:
  /// **'Paso {n}: {text}'**
  String theoryDiagramStep(int n, String text);

  /// Etiqueta del puesto de tiro en el esquema de la galería.
  ///
  /// In es, this message translates to:
  /// **'Puesto'**
  String get theoryDiagramPuesto;

  /// Etiqueta de la línea de tiro en el esquema de la galería.
  ///
  /// In es, this message translates to:
  /// **'Línea de tiro'**
  String get theoryDiagramFiringLine;

  /// Etiqueta de la diana en el esquema de la galería.
  ///
  /// In es, this message translates to:
  /// **'Diana'**
  String get theoryDiagramTarget;

  /// Cota de la distancia entre la línea de tiro y la diana.
  ///
  /// In es, this message translates to:
  /// **'25 m'**
  String get theoryDiagramDistance;

  /// Etiqueta de la zona segura en los esquemas.
  ///
  /// In es, this message translates to:
  /// **'Zona segura'**
  String get theoryDiagramSafeZone;

  /// Etiqueta del sector de tiro en el esquema.
  ///
  /// In es, this message translates to:
  /// **'Sector de tiro'**
  String get theoryDiagramSector;

  /// Etiqueta de la dirección segura del cañón en el esquema.
  ///
  /// In es, this message translates to:
  /// **'Dirección segura'**
  String get theoryDiagramSafeDirection;

  /// Título cuando los resúmenes de teoría no se han podido cargar.
  ///
  /// In es, this message translates to:
  /// **'La teoría no está disponible'**
  String get theoryUnavailableTitle;

  /// Mensaje cuando los resúmenes de teoría no se han podido cargar.
  ///
  /// In es, this message translates to:
  /// **'Esta versión de la app no incluye los resúmenes. Actualiza la app para verlos.'**
  String get theoryUnavailableMessage;

  /// Simulacro: botón que marca la pregunta actual como dudosa para revisarla antes de entregar.
  ///
  /// In es, this message translates to:
  /// **'Marcar como dudosa'**
  String get mockFlagAction;

  /// Simulacro: el mismo botón con la pregunta ya marcada; al tocarlo se quita la marca.
  ///
  /// In es, this message translates to:
  /// **'Marcada como dudosa'**
  String get mockFlagActive;

  /// Descripción accesible de una celda del navegador con respuesta y marcada como dudosa.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {number}, respondida, dudosa'**
  String mockFlagCellAnswered(int number);

  /// Descripción accesible de una celda del navegador sin respuesta y marcada como dudosa.
  ///
  /// In es, this message translates to:
  /// **'Pregunta {number}, sin responder, dudosa'**
  String mockFlagCellBlank(int number);

  /// Leyenda del navegador de preguntas: pregunta con respuesta.
  ///
  /// In es, this message translates to:
  /// **'Respondida'**
  String get mockFlagLegendAnswered;

  /// Leyenda del navegador de preguntas: pregunta sin respuesta.
  ///
  /// In es, this message translates to:
  /// **'Sin responder'**
  String get mockFlagLegendBlank;

  /// Leyenda del navegador de preguntas: pregunta marcada como dudosa.
  ///
  /// In es, this message translates to:
  /// **'Dudosa'**
  String get mockFlagLegendDoubtful;

  /// Resumen sobre el navegador de preguntas: cuántas dudosas y cuántas sin responder.
  ///
  /// In es, this message translates to:
  /// **'{doubtful, plural, =1{1 dudosa} other{{doubtful} dudosas}} · {blank, plural, =1{1 sin responder} other{{blank} sin responder}}'**
  String mockFlagSummary(int doubtful, int blank);

  /// Diálogo de entrega con preguntas dudosas y sin responder a la vez.
  ///
  /// In es, this message translates to:
  /// **'Tienes {doubtful, plural, =1{1 dudosa} other{{doubtful} dudosas}} y {blank, plural, =1{1 sin responder} other{{blank} sin responder}}. Las preguntas sin responder contarán como fallo.'**
  String mockFlagSubmitBoth(int doubtful, int blank);

  /// Diálogo de entrega con preguntas dudosas y todas respondidas.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Tienes 1 pregunta dudosa. Puedes revisarla antes de entregar.} other{Tienes {count} preguntas dudosas. Puedes revisarlas antes de entregar.}}'**
  String mockFlagSubmitDoubtful(int count);

  /// Icono de lupa de las cabeceras de Teoría y Fallos que abre el buscador.
  ///
  /// In es, this message translates to:
  /// **'Buscar en las preguntas'**
  String get searchTooltip;

  /// Título de la pantalla del buscador del banco de preguntas.
  ///
  /// In es, this message translates to:
  /// **'Buscar preguntas'**
  String get searchTitle;

  /// Texto de ayuda del campo de búsqueda del banco de preguntas.
  ///
  /// In es, this message translates to:
  /// **'Buscar en enunciados y opciones'**
  String get searchHint;

  /// Botón para vaciar el campo de búsqueda del banco de preguntas.
  ///
  /// In es, this message translates to:
  /// **'Borrar la búsqueda'**
  String get searchClear;

  /// Estado inicial del buscador, antes de escribir.
  ///
  /// In es, this message translates to:
  /// **'Busca en el banco de preguntas'**
  String get searchPromptTitle;

  /// Explicación del estado inicial del buscador.
  ///
  /// In es, this message translates to:
  /// **'Escribe dos letras o más, o varias palabras del enunciado o de las opciones. No importan las tildes ni las mayúsculas.'**
  String get searchPromptMessage;

  /// Título cuando la búsqueda en el banco de preguntas no encuentra nada.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados'**
  String get searchNoResultsTitle;

  /// Mensaje cuando la búsqueda no encuentra nada.
  ///
  /// In es, this message translates to:
  /// **'Prueba con otras palabras o con menos palabras.'**
  String get searchNoResultsMessage;

  /// Número de preguntas encontradas por el buscador.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 resultado} other{{count} resultados}}'**
  String searchResultsCount(int count);

  /// Aviso cuando hay más resultados de los que se listan.
  ///
  /// In es, this message translates to:
  /// **'Se muestran las {shown} primeras. Añade palabras para afinar la búsqueda.'**
  String searchResultsTruncated(int shown);

  /// Descripción accesible de una fila de resultado del buscador (tema y enunciado).
  ///
  /// In es, this message translates to:
  /// **'{tema}. {stem}'**
  String searchResultSemantics(String tema, String stem);

  /// Título de la pantalla de práctica del modo Cifras y plazos (también el título de su acceso en Inicio).
  ///
  /// In es, this message translates to:
  /// **'Cifras y plazos'**
  String get practiceFiguresTitle;

  /// Título de la pantalla de práctica cuando se responde la pregunta del día.
  ///
  /// In es, this message translates to:
  /// **'Pregunta del día'**
  String get practiceDailyQuestionTitle;

  /// Título cuando se abre el modo Cifras y plazos sin ninguna pregunta disponible en el banco.
  ///
  /// In es, this message translates to:
  /// **'No hay preguntas de cifras y plazos'**
  String get figuresEmptyTitle;

  /// Mensaje cuando el modo Cifras y plazos no tiene preguntas disponibles.
  ///
  /// In es, this message translates to:
  /// **'Este banco no contiene preguntas de cifras y plazos.'**
  String get figuresEmptyMessage;

  /// Título cuando no se puede mostrar la pregunta del día.
  ///
  /// In es, this message translates to:
  /// **'Hoy no hay pregunta del día'**
  String get dailyEmptyTitle;

  /// Mensaje cuando no se puede mostrar la pregunta del día.
  ///
  /// In es, this message translates to:
  /// **'Vuelve mañana, o practica un tema.'**
  String get dailyEmptyMessage;

  /// Título de la tesela de Inicio que abre el modo Cifras y plazos.
  ///
  /// In es, this message translates to:
  /// **'Cifras y plazos'**
  String get homeFiguresTitle;

  /// Subtítulo de la tesela Cifras y plazos de Inicio: cuántas preguntas tiene.
  ///
  /// In es, this message translates to:
  /// **'{count} preguntas de plazos, edades e importes'**
  String homeFiguresSubtitle(int count);

  /// Título de las tarjetas de repaso de cifras y de su acceso en Inicio.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas de cifras'**
  String get homeFiguresCardsTitle;

  /// Subtítulo de las tarjetas de cifras en Inicio.
  ///
  /// In es, this message translates to:
  /// **'{count} tarjetas: piensa la respuesta y dale la vuelta'**
  String homeFiguresCardsSubtitle(int count);

  /// Rótulo neutro del reverso de una tarjeta, antes de valorar si se sabía la respuesta.
  ///
  /// In es, this message translates to:
  /// **'La respuesta'**
  String get figuresCardAnswerLabel;

  /// Botón que revela el reverso de una tarjeta de cifras.
  ///
  /// In es, this message translates to:
  /// **'Ver respuesta'**
  String get figuresCardsReveal;

  /// Botón que retira del mazo la tarjeta de cifras actual.
  ///
  /// In es, this message translates to:
  /// **'La sabía'**
  String get figuresCardsKnown;

  /// Botón que envía al final del mazo la tarjeta de cifras actual.
  ///
  /// In es, this message translates to:
  /// **'Repasar otra vez'**
  String get figuresCardsAgain;

  /// Resumen de la ronda de tarjetas de cifras: preguntas conocidas en su primera aparición.
  ///
  /// In es, this message translates to:
  /// **'Sabías {known} de {total} a la primera'**
  String figuresCardsSummary(int known, int total);

  /// Botón del resumen que empieza una ronda solo con las tarjetas repetidas.
  ///
  /// In es, this message translates to:
  /// **'Otra vez con las que repasé'**
  String get figuresCardsRestart;

  /// Botón que sale del resumen de tarjetas de cifras.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get figuresCardsBack;

  /// Etiqueta de la tarjeta de la pregunta del día en Inicio.
  ///
  /// In es, this message translates to:
  /// **'Pregunta del día'**
  String get dailyTitle;

  /// Días seguidos respondiendo la pregunta del día (insignia de la tarjeta).
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{Racha de 1 día} other{Racha de {count} días}}'**
  String dailyStreak(int count);

  /// Botón de la tarjeta de la pregunta del día que abre la pregunta.
  ///
  /// In es, this message translates to:
  /// **'Responder'**
  String get dailyAnswer;

  /// Estado de la tarjeta de la pregunta del día cuando ya se ha respondido.
  ///
  /// In es, this message translates to:
  /// **'Respondida hoy'**
  String get dailyDone;

  /// Texto bajo «Respondida hoy» en la tarjeta de la pregunta del día.
  ///
  /// In es, this message translates to:
  /// **'Vuelve mañana para seguir con tu racha.'**
  String get dailyDoneHint;

  /// Abre las licencias de las dependencias de la app.
  ///
  /// In es, this message translates to:
  /// **'Licencias de código abierto'**
  String get settingsOpenSourceLicenses;

  /// Subtítulo de la lectura sobre la prueba práctica.
  ///
  /// In es, this message translates to:
  /// **'Cómo es, qué se valora y qué te elimina'**
  String get theoryPracticaSubtitle;

  /// Número de términos explicados del glosario.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =1{1 término explicado} other{{count} términos explicados}}'**
  String theoryGlossarySubtitle(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
