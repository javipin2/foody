/// Wrapper integration_test (dispositivo) sobre contratos en test/e2e/.
///
/// VM (recomendado CI local): `flutter test test/e2e/flujos_criticos_api_test.dart`
/// Dispositivo: `flutter test integration_test/flujos_criticos_e2e_test.dart -d windows|chrome`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/e2e/flujos_criticos_api_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registrarFlujosCriticosE2e();
}
