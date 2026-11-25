import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';

class _ResumenComisionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'exito': true,
        'datos': [
          {
            'id': 'repartidor-1',
            'nombre': 'Repartidor de prueba',
            'entregas': 4,
            'total_domicilios': '32000.00',
            'comision_foody': '4800.00',
            'ganancia_total': '27200.00',
            'por_pagar': '16000.00',
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('normaliza importes numeric serializados como texto', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = _ResumenComisionAdapter();
    final repository = DomiciliariosRepository(dio: dio);

    final [repartidor] = await repository.resumenComisionesIndependientes(
      'sucursal-prueba',
    );

    expect(repartidor['entregas'], 4);
    expect(repartidor['total_domicilios'], 32000.0);
    expect(repartidor['comision_foody'], 4800.0);
    expect(repartidor['ganancia_total'], 27200.0);
    expect(repartidor['por_pagar'], 16000.0);
  });
}
