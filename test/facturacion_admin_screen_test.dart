import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/features/facturacion/data/facturacion_repository.dart';
import 'package:reserva_canchas/features/facturacion/presentation/facturacion_admin_screen.dart';

class _FacturacionRepositoryFake extends FacturacionRepository {
  _FacturacionRepositoryFake({this.facturas = const []});

  final List<Map<String, dynamic>> facturas;

  @override
  Future<Map<String, dynamic>?> obtenerConfig(String sucursalId) async => null;

  @override
  Future<List<Map<String, dynamic>>> listarFacturas(
    String sucursalId, {
    String? estado,
  }) async => facturas;
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  for (final width in [320.0, 390.0, 820.0, 1440.0]) {
    testWidgets('facturación se adapta a ${width}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: FacturacionAdminScreen(
              sucursalId: 'sucursal-1',
              repository: _FacturacionRepositoryFake(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Facturas internas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Facturas (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Sin facturas aún'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('facturación lista compacta en móvil y tabla en escritorio',
      (tester) async {
    final facturas = [
      {
        'id': 'factura-1',
        'pedido_id': 'pedido-1',
        'numero_factura': 'FE-2026-0001',
        'nombre_fiscal_cliente': 'Cliente de prueba',
        'created_at': '2026-06-01T12:00:00Z',
        'total': 50000,
        'estado': 'emitida',
      },
    ];
    for (final width in [390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: FacturacionAdminScreen(
              sucursalId: 'sucursal-1',
              repository: _FacturacionRepositoryFake(facturas: facturas),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Facturas (1)'));
      await tester.pumpAndSettle();
      expect(find.text('FE-2026-0001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
