import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/data/super_admin_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/foody_control_repartidores_vista.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/foody_control_ui.dart';

class _RepartidoresRepoFake extends SuperAdminRepository {
  @override
  Future<List<Map<String, dynamic>>> domiciliarios() async => [
        {
          'id': 'domi-1',
          'nombre': 'Repartidor QA',
          'email': 'repartidor@example.test',
          'ciudad_nombre': 'Bogotá',
          'estado_cuenta': 'activo',
          'total_entregas': 7,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> documentosPendientes() async => [];
}

void main() {
  testWidgets('Super Admin rotula aceptaciones de oferta, no entregas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodyControlRepartidoresVista(repo: _RepartidoresRepoFake()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ofertas aceptadas (histórico): 7'),
      findsOneWidget,
    );
    expect(find.textContaining('Entregas: 7'), findsNothing);
  });

  testWidgets('KPI puede explicar que una cifra es estimada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FoodyControlTarjetaKpi(
            titulo: 'Comisión estimada hoy',
            valor: 'COP 12.000',
            icono: Icons.payments_outlined,
            descripcion:
                'Se registra al aceptar la oferta; no confirma recaudo.',
          ),
        ),
      ),
    );

    expect(find.text('Comisión estimada hoy'), findsOneWidget);
    expect(find.text('Se registra al aceptar la oferta; no confirma recaudo.'),
        findsOneWidget);
    expect(find.text('COP 12.000'), findsOneWidget);
  });
}
