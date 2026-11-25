import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/tema/tema_foody.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliarios_admin_screen.dart';

class _DomiciliariosDePrueba extends DomiciliariosRepository {
  Completer<List<Map<String, dynamic>>>? siguienteListado;

  @override
  Future<List<Map<String, dynamic>>> listarDisponibles(
    String sucursalId,
  ) async {
    final pendiente = siguienteListado;
    siguienteListado = null;
    if (pendiente != null) return pendiente.future;
    return [
      {
        'id': 'domi-planta-1',
        'nombre': 'Repartidor de prueba con nombre largo',
        'telefono': '300 000 0000',
        'ocupado': false,
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> resumenComisionesIndependientes(
    String sucursalId,
  ) async =>
      [
        {
          'id': 'domi-independiente-1',
          'nombre': 'Independiente de prueba',
          'entregas': '4',
          'total_domicilios': '32000',
          'comision_foody': '4800',
          'ganancia_total': '27200',
          'por_pagar': '16000',
        },
      ];

  @override
  Future<Map<String, dynamic>> resumenLiquidacion(String sucursalId) async => {
        'permite_fiado_domiciliario': true,
        'domiciliarios': <Map<String, dynamic>>[
          {
            'domiciliario_planta_id': 'domi-planta-1',
            'nombre': 'Repartidor de prueba',
            'total_pendiente': '12500',
            'pedidos': '2',
          },
        ],
      };

  @override
  Future<Map<String, dynamic>> resumenDomicilios(String sucursalId) async => {
        'domicilio_ingresa_a_caja': true,
        'domiciliarios': <Map<String, dynamic>>[],
      };
}

class _LecturasParalelas extends _DomiciliariosDePrueba {
  final llamadasResumen = <String>[];
  final liquidacion = Completer<Map<String, dynamic>>();
  final domicilios = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> resumenLiquidacion(String sucursalId) {
    llamadasResumen.add('liquidacion');
    return liquidacion.future;
  }

  @override
  Future<Map<String, dynamic>> resumenDomicilios(String sucursalId) {
    llamadasResumen.add('domicilios');
    return domicilios.future;
  }
}

void main() {
  testWidgets('refresh conserva datos y los muestra si falla la red',
      (tester) async {
    final repository = _DomiciliariosDePrueba();
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaFoody.claro(),
        home: Scaffold(
          body: DomiciliariosAdminScreen(
            sucursalId: 'sucursal-prueba',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Repartidor de prueba con nombre largo'), findsOneWidget);

    final pendiente = Completer<List<Map<String, dynamic>>>();
    repository.siguienteListado = pendiente;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pump();
    expect(find.text('Repartidor de prueba con nombre largo'), findsOneWidget);
    expect(find.text('Cargando…'), findsNothing);

    pendiente.completeError(Exception('Sin conexión de prueba'));
    await tester.pumpAndSettle();

    expect(find.text('Repartidor de prueba con nombre largo'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicia en paralelo los dos resúmenes de domicilio',
      (tester) async {
    final repository = _LecturasParalelas();
    await tester.pumpWidget(
      MaterialApp(
        theme: TemaFoody.claro(),
        home: Scaffold(
          body: DomiciliariosAdminScreen(
            sucursalId: 'sucursal-prueba',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(repository.llamadasResumen, ['liquidacion', 'domicilios']);
    repository.liquidacion.complete({
      'permite_fiado_domiciliario': true,
      'domiciliarios': <Map<String, dynamic>>[],
    });
    repository.domicilios.complete({
      'domicilio_ingresa_a_caja': true,
      'domiciliarios': <Map<String, dynamic>>[],
    });
    await tester.pumpAndSettle();

    expect(find.text('Fiado por cobrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(320, 640),
    Size(390, 844),
    Size(820, 1180),
    Size(1440, 1000),
  ]) {
    testWidgets('resumen de domiciliarios se adapta a ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: TemaFoody.claro(),
          home: Scaffold(
            body: DomiciliariosAdminScreen(
              sucursalId: 'sucursal-prueba',
              repository: _DomiciliariosDePrueba(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fiado por cobrar'), findsOneWidget);
      expect(find.text('Pago a independientes'), findsOneWidget);
      final resumen = find.text('Resumen de independientes');
      await tester.scrollUntilVisible(
        resumen,
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(resumen, findsOneWidget);
      expect(find.textContaining('Comisión estimada Foody'), findsOneWidget);
      expect(find.textContaining('4 asignaciones'), findsOneWidget);
      expect(
        find.text(
          'Saldos registrados al aceptar ofertas; no confirman entregas ni pagos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Por pagar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
