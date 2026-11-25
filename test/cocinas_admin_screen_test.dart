import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/cocinas/presentation/cocinas_admin_screen.dart';

class _CocinasRepositoryFake extends CocinasRepository {
  _CocinasRepositoryFake({this.incluirCocina = false});

  final bool incluirCocina;

  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) async =>
      incluirCocina
          ? [
              {
                'id': 'c1',
                'nombre': 'Cocina principal',
                'activa': true,
                'impresoras': 0,
              },
            ]
          : [];

  @override
  Future<List<Map<String, dynamic>>> listarImpresoras(
    String sucursalId, {
    String? cocinaId,
  }) async =>
      [];
}

class _CocinasRepositoryConcurrente extends CocinasRepository {
  final iniciadas = <String>[];
  final cocinasPendientes = Completer<List<Map<String, dynamic>>>();
  final impresorasPendientes = Completer<List<Map<String, dynamic>>>();

  @override
  Future<List<Map<String, dynamic>>> listarCocinas(String sucursalId) {
    iniciadas.add('cocinas');
    return cocinasPendientes.future;
  }

  @override
  Future<List<Map<String, dynamic>>> listarImpresoras(
    String sucursalId, {
    String? cocinaId,
  }) {
    iniciadas.add('impresoras');
    return impresorasPendientes.future;
  }
}

void main() {
  testWidgets('carga cocinas e impresoras en paralelo', (tester) async {
    final repository = _CocinasRepositoryConcurrente();
    await tester.pumpWidget(
      MaterialApp(
        home: CocinasAdminScreen(
          sucursalId: 's1',
          repository: repository,
        ),
      ),
    );
    await tester.pump();

    expect(repository.iniciadas, ['cocinas', 'impresoras']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.cocinasPendientes.complete([]);
    repository.impresorasPendientes.complete([]);
    await tester.pumpAndSettle();

    expect(find.text('Cocinas e impresoras'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('diálogos de cocina e impresora caben en ${size.width}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: CocinasAdminScreen(
            sucursalId: 's1',
            repository: _CocinasRepositoryFake(incluirCocina: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Nueva').first);
      await tester.pumpAndSettle();
      expect(find.text('Cocina asados, Barra de bebidas…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Nueva').last);
      await tester.pumpAndSettle();
      expect(find.text('IP local (opcional)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
