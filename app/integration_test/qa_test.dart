import 'package:integration_test/integration_test.dart';

import 'scenarios/accesibilidad.dart';
import 'scenarios/ajustes.dart';
import 'scenarios/busqueda.dart';
import 'scenarios/cifras_tarjetas.dart';
import 'scenarios/datos.dart';
import 'scenarios/inicio_y_practica.dart';
import 'scenarios/simulacro.dart';
import 'scenarios/simulacro_dudosas.dart';
import 'scenarios/teoria.dart';

/// Entry point of the end-to-end battery (docs/qa.md). Run it on the
/// Apto_Armas emulator with `tool/qa/run_battery.sh`, or by hand:
///
///     cd app
///     flutter test integration_test -d <serial>
///     flutter test integration_test -d <serial> --dart-define=QA_ONLY=arranque,ajustes
///     flutter test integration_test -d <serial> --dart-define=QA_SKIP=ajustes
///
/// Every scenario boots the real app over a fresh database and cleared
/// preferences; only the store, the random seed and the clock are replaced.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerInicioYPractica();
  registerSimulacro();
  registerSimulacroDudosas();
  registerCifrasTarjetas();
  registerAccesibilidad();
  registerAjustes();
  registerDatos();
  registerTeoria();
  registerBusqueda();
}
