import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('la ruta del menú conserva el token QR para crear pedidos en la mesa',
      () async {
    await MesaSesionService.activar(
      mesaId: 'mesa-qa',
      mesaNombre: 'Mesa QA',
      sucursalId: 'sucursal-qa',
      sucursalNombre: 'Restaurante QA',
      qrToken: 'qr-token-qa',
    );

    final sesion = await MesaSesionService.obtener();

    expect(sesion?.qrToken, 'qr-token-qa');
    expect(sesion?.rutaMenu, contains('qr_token=qr-token-qa'));
  });
}
