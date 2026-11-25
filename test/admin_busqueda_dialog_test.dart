import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/admin_busqueda_dialog.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';

class _PedidosBusquedaFake extends PedidosRepository {
  _PedidosBusquedaFake({this.fallarPrimera = false});

  final bool fallarPrimera;
  int llamadas = 0;
  String? ultimaConsulta;
  String? ultimaSucursal;

  @override
  Future<List<PedidoAdminModel>> buscarActivos({
    required String sucursalId,
    required String consulta,
    int limit = 6,
  }) async {
    llamadas++;
    ultimaConsulta = consulta;
    ultimaSucursal = sucursalId;
    if (fallarPrimera && llamadas == 1) {
      throw Exception('Error de conexión');
    }
    return [
      PedidoAdminModel(
        id: 'pedido-101',
        numeroPedido: 'P-101',
        tipo: 'domicilio',
        estado: 'en_camino',
        clienteNombre: 'Ana Pérez',
        clienteTelefono: '3001234567',
        total: 25000,
        creadoEn: DateTime(2026, 11, 24),
        estadoDesde: DateTime(2026, 11, 24),
      ),
    ];
  }
}

class _MesasBusquedaFake extends MesasRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) async => [];
}

const _grupos = <({MenuAdminGrupo grupo, List<MenuAdminItem> items})>[];

Future<void> _abrirBusqueda(
  WidgetTester tester, {
  required PedidosRepository pedidos,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => mostrarBusquedaAdmin(
                context: context,
                sucursalId: 'sucursal-1',
                grupos: _grupos,
                onIrSeccion: (_) {},
                onIrMesa: (_) {},
                pedidosRepository: pedidos,
                mesasRepository: _MesasBusquedaFake(),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(820, 900),
    const Size(1440, 900),
  ]) {
    testWidgets('búsqueda se adapta a ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _abrirBusqueda(tester, pedidos: _PedidosBusquedaFake());

      expect(find.text('Buscar en Foody'), findsOneWidget);
      expect(find.text('Buscar módulos, pedidos o mesas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('busca pedidos por servidor y conserva el contexto de sede', (
    tester,
  ) async {
    final pedidos = _PedidosBusquedaFake();
    await _abrirBusqueda(tester, pedidos: pedidos);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(find.text('P-101'), findsOneWidget);
    expect(pedidos.ultimaConsulta, 'Ana');
    expect(pedidos.ultimaSucursal, 'sucursal-1');
    await tester.tap(find.text('P-101'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar en Foody'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error permite reintentar sin presentarlo como vacío', (
    tester,
  ) async {
    final pedidos = _PedidosBusquedaFake(fallarPrimera: true);
    await _abrirBusqueda(tester, pedidos: pedidos);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump(const Duration(milliseconds: 260));
    await tester.pumpAndSettle();

    expect(find.text('Sin resultados para «Ana».'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(pedidos.llamadas, 2);
    expect(find.text('P-101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('una letra no dispara búsqueda remota ni afirma vacío', (
    tester,
  ) async {
    final pedidos = _PedidosBusquedaFake();
    await _abrirBusqueda(tester, pedidos: pedidos);

    await tester.enterText(find.byType(TextField), 'Z');
    await tester.pumpAndSettle();

    expect(pedidos.llamadas, 0);
    expect(
      find.text('Escribe al menos 2 caracteres para buscar pedidos.'),
      findsOneWidget,
    );
    expect(find.text('Sin resultados para «Z».'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
