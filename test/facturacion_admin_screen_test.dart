import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:reserva_canchas/core/tema/tema_foody.dart';
import 'package:reserva_canchas/features/facturacion/data/facturacion_repository.dart';
import 'package:reserva_canchas/features/facturacion/presentation/facturacion_admin_screen.dart';

class _FacturasDePrueba extends FacturacionRepository {
  bool emitirFalla = true;
  String estado = 'emitida';
  String? motivoGuardado;

  @override
  Future<Map<String, dynamic>?> obtenerConfig(String sucursalId) async => null;

  @override
  Future<List<Map<String, dynamic>>> listarFacturas(
    String sucursalId, {
    String? estado,
  }) async =>
      [
        {
          'id': 'factura',
          'pedido_id': 'pedido',
          'numero_factura': 'QA-1',
          'estado': this.estado,
          'total': 8000,
        },
      ];

  @override
  Future<Map<String, dynamic>> emitir(
    String pedidoId,
    String sucursalId,
  ) async {
    if (emitirFalla) throw StateError('Pedido pendiente de pago');
    estado = 'emitida';
    return {};
  }

  @override
  Future<Map<String, dynamic>> anular({
    required String facturaId,
    required String sucursalId,
    required String motivo,
  }) async {
    motivoGuardado = motivo;
    estado = 'anulada';
    return {};
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  testWidgets('mantiene el acceso a emitir hasta que la API acepta', (
    tester,
  ) async {
    final repo = _FacturasDePrueba()..estado = 'borrador';
    var sugerenciasResueltas = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaFoody.claro(),
        home: Scaffold(
          body: FacturacionAdminScreen(
            sucursalId: 'sucursal',
            pedidoIdInicial: 'pedido',
            onPedidoSugeridoUsado: () => sugerenciasResueltas++,
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Emitir'));
    await tester.pumpAndSettle();
    expect(sugerenciasResueltas, 0);
    expect(find.widgetWithText(FilledButton, 'Emitir'), findsOneWidget);

    repo.emitirFalla = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Emitir'));
    await tester.pumpAndSettle();
    expect(sugerenciasResueltas, 1);
    expect(repo.estado, 'emitida');
  });

  testWidgets('valida y confirma la anulación en móvil oscuro', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _FacturasDePrueba();

    await tester.pumpWidget(
      MaterialApp(
        theme: TemaFoody.oscuro(),
        home: Scaffold(
          body: FacturacionAdminScreen(
            sucursalId: 'sucursal',
            repository: repo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Facturas (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Acciones de factura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anular'));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(FilledButton, 'Anular');
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    expect(find.text('Escribe al menos 3 caracteres'), findsOneWidget);
    expect(repo.motivoGuardado, isNull);

    await tester.enterText(find.byType(TextFormField), '  Duplicada  ');
    await tester.tap(confirmar);
    await tester.pumpAndSettle();
    expect(repo.motivoGuardado, 'Duplicada');
    expect(find.text('anulada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
