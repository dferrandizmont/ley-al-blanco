/// The Spanish texts the scenarios look for, in one place. They are written
/// out (not read from the ARB) on purpose: a copy change in the app must be a
/// conscious edit here too, and a typo in the ARB shows up as a failure.
///
abstract final class T {
  // Inicio
  static const continuar = 'Continuar';
  static String continuarCount(int n) =>
      n == 1 ? '1 pregunta para hoy' : '$n preguntas para hoy';
  static const simulacro = 'Simulacro';
  static const fallos = 'Fallos';
  static const temasOverline = 'TEMAS';
  static const ajustes = 'Ajustes';
  static const legal = 'App independiente y no oficial';
  static const edicion = 'Cuestionario GC nov-2020';
  static const simulacroLibre = 'Un examen completo, como el real';
  static String fallosPendientes(int n) => switch (n) {
    0 => 'Sin fallos pendientes',
    1 => '1 fallo pendiente',
    _ => '$n fallos pendientes',
  };
  static String temaFallos(int n) => n == 1 ? '1 fallo' : '$n fallos';

  // Practica
  static const siguiente = 'Siguiente';
  static const terminar = 'Terminar';
  static const cerrar = 'Cerrar';
  static const correcto = 'Correcto';
  static const incorrecto = 'Incorrecto';
  static const respuestaCorrecta = 'Respuesta correcta';

  /// The neutral label on the back of a figures card.
  static const laRespuesta = 'La respuesta';
  static const explicacion = 'Explicación';
  static const sesionTerminada = 'Sesión terminada';
  static const volverAlInicio = 'Volver al inicio';
  static String ratio(int a, int b) => '$a / $b';

  /// The counter of the practice by tema: "1 de 67 pendientes".
  static String pendientes(int index, int count) =>
      '$index de $count ${count == 1 ? 'pendiente' : 'pendientes'}';

  // Simulacro
  static const empezar = 'Empezar';
  static const entregar = 'Entregar';
  static const seguir = 'Seguir';
  static const salir = 'Salir';
  static const preguntas = 'Preguntas';
  static const entregarTitulo = '¿Entregar el simulacro?';
  static const salirTitulo = '¿Salir del simulacro?';
  static const podrasRetomar = 'Podrás retomarlo desde Simulacro.';
  static const continuarSimulacro = 'Continuar simulacro';
  static const empezarOtro = 'Empezar otro';
  static const simulacroSinEntregar = 'Tienes uno sin entregar';
  static const tusSimulacros = 'TUS SIMULACROS';
  static const soloFalladas = 'Solo falladas';
  static const anterior = 'Anterior';
  static const entregarTodas = 'Has respondido todas las preguntas.';
  static String entregarSinResponder(int n) => n == 1
      ? 'Te queda 1 pregunta sin responder y contará como fallo.'
      : 'Te quedan $n preguntas sin responder y contarán como fallo.';
  static const apto = 'APTO';
  static const noApto = 'NO APTO';
  static const deVeinte = 'de 20';
  static const tiempoEmpleado = 'Tiempo empleado:';
  static const marcaAprobado = 'La marca indica el aprobado: 16 aciertos.';
  static const sinResponder = 'Sin responder';
  static const revision = 'Revisión';
  static String repasarFallos(int n) =>
      n == 1 ? 'Repasar el fallo' : 'Repasar los $n fallos';

  // Fallos
  static const todos = 'Todos';
  static const repasarTodos = 'Repasar todos';
  static const sinFallosTitulo = 'No tienes fallos pendientes';
  static const falladaUnaVez = 'Fallada 1 vez';

  // Tarjetas de cifras ("Cifras y plazos" en modo tarjeta)
  static const tarjetasTitulo = 'Tarjetas de cifras';
  static const verRespuesta = 'Ver respuesta';
  static const laSabia = 'La sabía';
  static const repasarOtraVez = 'Repasar otra vez';
  static const otraVez = 'Otra vez con las que repasé';
  static const volver = 'Volver';
  static String tarjetasSubtitulo(int count) =>
      '$count tarjetas: piensa la respuesta y dale la vuelta';
  static String tarjetasResumen(int known, int total) =>
      'Sabías $known de $total a la primera';
  // Ajustes (pantalla en construcción por otro agente: ver docs/qa.md)
  static const temaSistema = 'Sistema';
  static const temaClaro = 'Claro';
  static const temaOscuro = 'Oscuro';

  // Ajustes > Tus datos (exportar / importar el progreso)
  static const tusDatos = 'TUS DATOS';
  static const exportar = 'Exportar progreso';
  static const importar = 'Importar progreso';
  static const progresoGuardado = 'Progreso guardado.';
  static const progresoImportado = 'Progreso importado.';
  static const importarErrorTitulo = 'No se puede importar';
  static const importarConfirmarTitulo = '¿Reemplazar tu progreso?';
  static const importarReemplazar = 'Reemplazar';
  static const importarEntendido = 'Entendido';
}
