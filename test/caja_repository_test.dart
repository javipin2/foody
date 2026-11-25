import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';

class _PaginasCajaAdapter implements HttpClientAdapter {
  final List<RequestOptions> solicitudes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    solicitudes.add(options);
    final page = int.parse(options.queryParameters['page'].toString());
    final items = List.generate(
      50,
      (i) => {'id': 'p$page-${i + 1}'},
    );
    return ResponseBody.fromString(
      jsonEncode({
        'exito': true,
        'datos': {
          'items': items,
          'total': 120,
          'page': page,
          'limit': 50,
          'totalPages': 3,
        },
      }),
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
  test('carga solo las páginas necesarias para mostrar los 80 recientes',
      () async {
    final adapter = _PaginasCajaAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://foody.test'))
      ..httpClientAdapter = adapter;

    final movimientos = await CajaRepository(dio: dio).movimientos('caja-1');

    expect(movimientos, hasLength(80));
    expect(adapter.solicitudes, hasLength(2));
    expect(
      adapter.solicitudes.map((r) => r.queryParameters['page']),
      [1, 2],
    );
    expect(adapter.solicitudes.first.queryParameters['limit'], 50);
  });
}
