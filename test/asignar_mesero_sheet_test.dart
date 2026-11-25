import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/asignar_mesero_sheet.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';

class _UsuariosFake extends UsuariosRepository {
  @override
  Future<List<Map<String, dynamic>>> listarMeserosActivos(
    String sucursalId,
  ) async =>
      [
        {'id': 'mesero-1', 'nombre': 'María Fernanda Pérez'},
      ];
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 600),
    const Size(1440, 700),
  ]) {
    testWidgets('asignación de mesero cabe en ${size.width}×${size.height}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ahora = DateTime(2026, 11, 22);
      final pedido = PedidoAdminModel(
        id: 'pedido-1',
        numeroPedido: 'P-001',
        tipo: 'mesa',
        estado: 'pendiente_aprobacion',
        mesaNombre: 'Mesa principal',
        total: 42000,
        creadoEn: ahora,
        estadoDesde: ahora,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => mostrarAsignarMeseroSheet(
                    context: context,
                    pedido: pedido,
                    sucursalId: 'sucursal-1',
                    usuariosRepository: _UsuariosFake(),
                  ),
                  child: const Text('Asignar'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Asignar'));
      await tester.pumpAndSettle();
      expect(find.text('Asignar mesero'), findsOneWidget);
      expect(find.text('María Fernanda Pérez'), findsOneWidget);
      expect(find.text('Confirmar y enviar a cocina'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
