import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/costeo_ui_bloques.dart';
import 'package:reserva_canchas/features/costeo/presentation/widgets/receta_producto_panel.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';

class _RecetaApiAdapter implements HttpClientAdapter {
  final solicitudes = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    solicitudes.add(options);
    final datos = options.method == 'GET'
        ? {
            'items': [
              {
                'tipo_item': 'ingrediente',
                'ingrediente_id': 'insumo-1',
                'cantidad': 100,
                'unidad': 'g',
              },
            ],
            'margen_error': 0.05,
          }
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode({'exito': true, 'datos': datos}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecetaRepositoryFallaUnaVez extends InventarioRepository {
  _RecetaRepositoryFallaUnaVez() : super(dio: Dio());

  bool fallar = true;
  List<Map<String, dynamic>> itemsIniciales = const [];
  List<Map<String, dynamic>>? itemsGuardados;
  double? margenGuardado;
  String? tipoEntidadGuardado;

  @override
  Future<Map<String, dynamic>> recetaProducto(
    String productoId, {
    String tipoEntidad = 'producto',
  }) async {
    if (fallar) throw Exception('fallo de conexión simulado');
    return {'items': itemsIniciales, 'margen_error': 0.05};
  }

  @override
  Future<void> configurarReceta({
    required String productoId,
    required List<Map<String, dynamic>> items,
    double? margenError,
    String tipoEntidad = 'producto',
  }) async {
    itemsGuardados = items;
    margenGuardado = margenError;
    tipoEntidadGuardado = tipoEntidad;
  }
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('flujo de receta se adapta a ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CosteoFlujoReceta()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ingredientes'), findsOneWidget);
      expect(find.text('Preparaciones'), findsOneWidget);
      expect(find.text('Empaques'), findsOneWidget);
      expect(find.text('Acompañamientos'), findsOneWidget);
      expect(find.text('Costo y margen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('grupo de costo permite plegar y desplegar', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CosteoGrupoReceta(
            numero: 1,
            titulo: 'Ingredientes',
            subtitulo: 'Componentes del plato',
            colorBadge: Colors.orange,
            lineas: const [Text('Carne')],
          ),
        ),
      ),
    );

    expect(find.text('Carne'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('alternar-grupo-costeo-1')));
    await tester.pumpAndSettle();
    expect(find.text('Carne'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('alternar-grupo-costeo-1')));
    await tester.pumpAndSettle();
    expect(find.text('Carne'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor móvil inicia compacto y permite abrir preparaciones',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _RecetaRepositoryFallaUnaVez()
      ..fallar = false
      ..itemsIniciales = [
        {
          'tipo_item': 'ingrediente',
          'ingrediente_id': 'insumo-1',
          'cantidad': 100,
          'unidad': 'g',
        },
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecetaProductoPanel(
              productoId: 'producto-1',
              nombreProducto: 'Arroz de prueba',
              ingredientes: const [
                {
                  'id': 'insumo-1',
                  'nombre': 'Arroz',
                  'unidad_base': 'g',
                  'categoria_insumo': 'alimento',
                },
              ],
              subrecetas: const [],
              onGuardado: () {},
              repositorio: repository,
              scrollExterno: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar receta'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agregar-receta-ingredientes')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('agregar-receta-preparaciones')),
        findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('alternar-editor-receta-preparaciones')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agregar-receta-preparaciones')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error al cargar no abre editor y permite reintentar',
      (tester) async {
    final repository = _RecetaRepositoryFallaUnaVez();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecetaProductoPanel(
            productoId: 'producto-1',
            nombreProducto: 'Arroz de prueba',
            ingredientes: const [
              {
                'id': 'insumo-1',
                'nombre': 'Arroz',
                'unidad_base': 'g',
                'categoria_insumo': 'alimento',
              },
            ],
            subrecetas: const [],
            onGuardado: () {},
            repositorio: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Guardar receta'), findsNothing);
    expect(find.text('Editar receta'), findsNothing);

    repository.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Guardar receta'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(820, 1180),
    const Size(1440, 900),
  ]) {
    testWidgets('edición guarda receta a ${size.width}px', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final adapter = _RecetaApiAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://foody.test/api/v1'))
        ..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final repository = InventarioRepository(dio: dio);
      var guardados = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecetaProductoPanel(
                productoId: 'producto-1',
                nombreProducto: 'Arroz de prueba',
                ingredientes: const [
                  {
                    'id': 'insumo-1',
                    'nombre': 'Arroz',
                    'unidad_base': 'g',
                    'categoria_insumo': 'alimento',
                  },
                ],
                subrecetas: const [],
                onGuardado: () => guardados++,
                repositorio: repository,
                scrollExterno: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar receta'));
      await tester.pumpAndSettle();
      final cantidad = find.byKey(const ValueKey('cant-insumo-1-0'));
      expect(cantidad, findsOneWidget);
      await tester.enterText(cantidad, '150');
      await tester.tap(find.text('Guardar receta'));
      await tester.pumpAndSettle();

      expect(adapter.solicitudes, hasLength(2));
      final lectura = adapter.solicitudes.first;
      final guardado = adapter.solicitudes.last;
      expect(lectura.method, 'GET');
      expect(
        lectura.uri.path,
        '/api/v1/inventario/producto-ingredientes/producto-1',
      );
      expect(guardado.method, 'POST');
      expect(guardado.uri.path, '/api/v1/inventario/producto-ingredientes');
      final payload = Map<String, dynamic>.from(guardado.data as Map);
      expect(payload['producto_id'], 'producto-1');
      expect(payload['margen_error'], 0.05);
      expect(payload['items'], [
        {
          'tipo_item': 'ingrediente',
          'ingrediente_id': 'insumo-1',
          'cantidad': 150.0,
          'unidad': 'g',
        },
      ]);
      expect(guardados, 1);
      expect(find.text('Receta guardada'), findsOneWidget);
      expect(find.text('Editar receta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
