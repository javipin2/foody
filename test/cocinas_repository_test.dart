import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealtimeCanalAdapter implements HttpClientAdapter {
  _RealtimeCanalAdapter(this.cuerpo);

  final Map<String, dynamic> cuerpo;
  RequestOptions? ultimaSolicitud;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaSolicitud = options;
    return ResponseBody.fromString(
      jsonEncode(cuerpo),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('solicita y persiste el canal firmado de la cocina elegida', () async {
    SharedPreferences.setMockInitialValues({
      'foody_staff_sesion': jsonEncode({'realtime_canales': {}}),
    });
    final adapter = _RealtimeCanalAdapter({
      'exito': true,
      'datos': {
        'realtime_canales': {
          'sucursal': 'sucursal_s-1_firma',
          'cocina': 'cocina_c-1_firma',
        },
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = CocinasRepository(dio: dio);

    await repository.prepararCanalRealtimeCocina(
      cocinaId: 'c-1',
      sucursalId: 's-1',
    );

    expect(adapter.ultimaSolicitud?.path, '/auth/realtime-canales');
    expect(adapter.ultimaSolicitud?.queryParameters, {
      'sucursal_id': 's-1',
      'cocina_id': 'c-1',
    });
    expect(await SesionStaffService.obtenerRealtimeCanales(), {
      'sucursal': 'sucursal_s-1_firma',
      'cocina': 'cocina_c-1_firma',
    });
  });

  test('rechaza respuesta sin canal cocina firmado', () async {
    SharedPreferences.setMockInitialValues({
      'foody_staff_sesion': jsonEncode({'realtime_canales': {}}),
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = _RealtimeCanalAdapter({
        'exito': true,
        'datos': {'realtime_canales': <String, String>{}},
      });
    final repository = CocinasRepository(dio: dio);

    await expectLater(
      repository.prepararCanalRealtimeCocina(cocinaId: 'c-1'),
      throwsA(isA<Exception>()),
    );
  });

  test('actualiza una tarea de combo por endpoint independiente', () async {
    final adapter = _RealtimeCanalAdapter({
      'exito': true,
      'datos': {'tarea_id': 't-1', 'estado_cocina': 'listo'},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = CocinasRepository(dio: dio);

    await repository.cambiarEstadoTareaCombo(
      tareaId: 't-1',
      estadoCocina: 'listo',
    );

    expect(adapter.ultimaSolicitud?.method, 'PATCH');
    expect(adapter.ultimaSolicitud?.path, '/cocina/combo-tareas/t-1/estado');
    expect(adapter.ultimaSolicitud?.data, {'estado_cocina': 'listo'});
  });

  test('reporta componente combo faltante sin usar fallo de preparación',
      () async {
    final adapter = _RealtimeCanalAdapter({
      'exito': true,
      'datos': {
        'tarea_id': 't-1',
        'decision_id': 'd-1',
        'estado_linea': 'preparando',
      },
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = CocinasRepository(dio: dio);

    await repository.marcarTareaComboNoDisponible(
      tareaId: 't-1',
      motivo: 'Se agotó el queso',
    );

    expect(adapter.ultimaSolicitud?.method, 'PATCH');
    expect(
      adapter.ultimaSolicitud?.path,
      '/cocina/combo-tareas/t-1/no-disponible',
    );
    expect(adapter.ultimaSolicitud?.data, {'motivo': 'Se agotó el queso'});
  });

  test('reimpresión del KDS limita la comanda a su cocina', () async {
    final adapter = _RealtimeCanalAdapter({
      'exito': true,
      'datos': {'pedido_id': 'p-1', 'encolado': true},
    });
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;
    final repository = CocinasRepository(dio: dio);

    await repository.reimprimirPedido(
      pedidoId: 'p-1',
      cocinaId: 'cocina-2',
      sucursalId: 'sucursal-1',
    );

    expect(adapter.ultimaSolicitud?.method, 'POST');
    expect(adapter.ultimaSolicitud?.path, '/impresion/reimprimir');
    expect(adapter.ultimaSolicitud?.data, {
      'pedido_id': 'p-1',
      'cocina_id': 'cocina-2',
      'sucursal_id': 'sucursal-1',
    });
  });
}
