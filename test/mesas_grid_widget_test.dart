import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';

class _MesasRepositoryFake extends MesasRepository {
  @override
  Future<List<Map<String, dynamic>>> listar(String sucursalId) async => [
        for (var i = 1; i <= 6; i++)
          {
            'id': 'mesa-$i',
            'nombre': 'Mesa de prueba $i',
            'pedido_id': null,
            'pedido_estado': null,
            'estado_operativo': 'libre',
          },
      ];

  @override
  Future<Map<String, dynamic>> obtenerQr({
    required String mesaId,
    required String sucursalId,
    String? baseUrl,
  }) async =>
      {'url': 'https://foodyy.store/mesa/token-de-prueba'};
}

void main() {
  testWidgets('tarjetas de mesas caben en móvil estrecho', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    AppBackend.supabaseReady = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MesasGridWidget(
              sucursalId: 'sucursal-1',
              mesasRepository: _MesasRepositoryFake(),
              verificarBackend: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Mesa de prueba 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grilla mide columnas por el ancho real del panel',
      (tester) async {
    tester.view.physicalSize = const Size(820, 900);
    tester.view.devicePixelRatio = 1;
    AppBackend.supabaseReady = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 520,
                  child: MesasGridWidget(
                    sucursalId: 'sucursal-1',
                    mesasRepository: _MesasRepositoryFake(),
                    verificarBackend: () async => true,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final first = tester.getTopLeft(find.text('Mesa de prueba 1'));
    final second = tester.getTopLeft(find.text('Mesa de prueba 2'));
    final third = tester.getTopLeft(find.text('Mesa de prueba 3'));
    expect(second.dy, closeTo(first.dy, 2));
    expect(third.dy, greaterThan(second.dy));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('renombrar mesa cabe con teclado en ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      AppBackend.supabaseReady = false;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: MesasGridWidget(
                sucursalId: 'sucursal-1',
                mesasRepository: _MesasRepositoryFake(),
                verificarBackend: () async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Opciones (QR, unir, renombrar…)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).last);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();

      expect(find.text('Guardar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('crear mesa cabe con teclado en ${size.width}px',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      AppBackend.supabaseReady = false;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: MesasGridWidget(
                sucursalId: 'sucursal-1',
                mesasRepository: _MesasRepositoryFake(),
                verificarBackend: () async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Nueva mesa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).last);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();

      expect(find.text('Crear'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('diálogo unir mesas cabe en ${size.width}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      AppBackend.supabaseReady = false;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => AppBackend.supabaseReady = false);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: Scaffold(
              body: MesasGridWidget(
                sucursalId: 'sucursal-1',
                mesasRepository: _MesasRepositoryFake(),
                verificarBackend: () async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Opciones (QR, unir, renombrar…)').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unir con otra mesa'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unir con'), findsOneWidget);
      expect(find.text('Unir mesas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('formulario de reserva de mesa se desplaza con teclado',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    AppBackend.supabaseReady = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(() => AppBackend.supabaseReady = false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MesasGridWidget(
              sucursalId: 'sucursal-1',
              mesasRepository: _MesasRepositoryFake(),
              verificarBackend: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Opciones (QR, unir, renombrar…)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reservar mesa'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();

    expect(find.text('Nombre cliente'), findsOneWidget);
    expect(find.text('Reservar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diálogo QR de mesa se adapta a móvil bajo', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    AppBackend.supabaseReady = false;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => AppBackend.supabaseReady = false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: MesasGridWidget(
              sucursalId: 'sucursal-1',
              mesasRepository: _MesasRepositoryFake(),
              verificarBackend: () async => true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Opciones (QR, unir, renombrar…)').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver enlace QR'));
    await tester.pumpAndSettle();

    expect(find.textContaining('QR — Mesa de prueba'), findsOneWidget);
    expect(find.text('Copiar enlace'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
  });
}
