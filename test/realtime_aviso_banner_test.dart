import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/red/salud_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/realtime_aviso_banner.dart';

class _SaludRepositoryFake extends SaludRepository {
  _SaludRepositoryFake(this.respuestas);

  final List<Future<({bool configurado, bool conectado, String? detalle})>
      Function()> respuestas;
  int llamadas = 0;

  @override
  Future<({bool configurado, bool conectado, String? detalle})>
      verificarRealtime() async {
    final respuesta = respuestas[llamadas++];
    return respuesta();
  }
}

void main() {
  testWidgets('oculta el detalle del servidor y explica el respaldo por sondeo',
      (tester) async {
    final repository = _SaludRepositoryFake([
      () async => (
            configurado: true,
            conectado: false,
            detalle: 'secreto interno de infraestructura',
          ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RealtimeAvisoBanner(repository: repository)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('no están disponibles temporalmente'),
        findsOneWidget);
    expect(find.textContaining('45–90 s'), findsOneWidget);
    expect(find.textContaining('secreto interno'), findsNothing);
  });

  testWidgets('fallo de red usa mensaje genérico y permite reintentar',
      (tester) async {
    final repository = _SaludRepositoryFake([
      () async => throw DioException(
            requestOptions: RequestOptions(path: '/health/realtime'),
            message: 'detalle técnico que no debe aparecer',
          ),
      () async => (
            configurado: true,
            conectado: true,
            detalle: null,
          ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RealtimeAvisoBanner(repository: repository)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo comprobar'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('detalle técnico'), findsNothing);
    await tester.tap(find.byTooltip('Reverificar Realtime'));
    await tester.pumpAndSettle();
    expect(repository.llamadas, 2);
    expect(find.textContaining('No se pudo comprobar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
