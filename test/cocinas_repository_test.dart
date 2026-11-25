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
}
