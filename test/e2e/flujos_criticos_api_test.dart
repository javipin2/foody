/// Contratos API de los 5 flujos críticos (+ VIE-01).
/// Runnable en VM: `flutter test test/e2e/flujos_criticos_api_test.dart`
/// Wrapper dispositivo: `integration_test/flujos_criticos_e2e_test.dart`
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const e2eHost = String.fromEnvironment(
  'E2E_HOST',
  defaultValue: 'http://127.0.0.1:3000',
);
const e2eBase = '$e2eHost/api/v1';
const e2eSid = 'c0000000-0000-4000-8000-000000000001';
const e2eProducto = 'f0000000-0000-4000-8000-000000000002';
const e2ePrecio = 8000;
const e2eQr = 'demo-mesa-1';
const e2ePass = '123456';

Future<Map<String, dynamic>> e2eJson(
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final uri = Uri.parse('$e2eBase$path');
  final h = <String, String>{
    'Content-Type': 'application/json',
    ...?headers,
  };
  late http.Response r;
  switch (method) {
    case 'GET':
      r = await http.get(uri, headers: h).timeout(const Duration(seconds: 30));
      break;
    case 'POST':
      r = await http
          .post(uri, headers: h, body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      break;
    case 'PATCH':
      r = await http
          .patch(uri, headers: h, body: body == null ? null : jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      break;
    default:
      throw UnsupportedError(method);
  }
  final decoded = jsonDecode(utf8.decode(r.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Respuesta no-objeto ${r.statusCode}');
  }
  return decoded;
}

Future<Map<String, String>> e2eLogin(String email) async {
  final r = await e2eJson('POST', '/auth/login', body: {
    'email': email,
    'contrasena': e2ePass,
  });
  expect(r['exito'], isTrue, reason: 'login $email');
  final token = (r['datos'] as Map)['token'] as String;
  return {'Authorization': 'Bearer $token'};
}

Future<void> e2eLimpiar(Map<String, String> auth) async {
  final lista =
      await e2eJson('GET', '/pedidos?sucursal_id=$e2eSid', headers: auth);
  if (lista['exito'] != true) return;
  final datos = lista['datos'];
  if (datos is! List) return;
  for (final p in datos) {
    final m = p as Map;
    final est = m['estado'] as String?;
    if (est == null ||
        ['cancelado', 'rechazado', 'pagado'].contains(est)) {
      continue;
    }
    await e2eJson(
      'PATCH',
      '/pedidos/${m['id']}/estado?sucursal_id=$e2eSid',
      headers: auth,
      body: {'estado': 'cancelado', 'motivo': 'QA flutter e2e'},
    );
  }
}

Future<void> e2eEnsureCaja(Map<String, String> auth) async {
  final a = await e2eJson('GET', '/caja/activa/$e2eSid', headers: auth);
  if (a['exito'] == true && a['datos'] != null) return;
  await e2eJson(
    'POST',
    '/caja/abrir?sucursal_id=$e2eSid',
    headers: auth,
    body: {'sucursal_id': e2eSid, 'monto_inicial': 50000},
  );
}

Future<String> e2eMesaLibre(Map<String, String> auth) async {
  final mesas = await e2eJson('GET', '/mesas/$e2eSid', headers: auth);
  expect(mesas['exito'], isTrue);
  final list = mesas['datos'] as List;
  final libre = list.cast<Map>().firstWhere(
        (m) => m['pedido_id'] == null,
        orElse: () => <String, dynamic>{},
      );
  expect(libre['id'], isNotNull, reason: 'sin mesa libre');
  return libre['id'] as String;
}

String e2ePedidoId(Map<String, dynamic> r) {
  final d = r['datos'] as Map;
  return (d['pedido_id'] ?? d['id']) as String;
}

/// Registra los 5 flujos + VIE-01. Usar desde test/ o integration_test/.
void registrarFlujosCriticosE2e() {
  group('Foody flujos críticos (API)', () {
    late Map<String, String> admin;
    late Map<String, String> cajero;

    setUpAll(() async {
      final salud = await e2eJson('GET', '/salud');
      expect(salud['exito'], isTrue, reason: 'API debe estar en :3000');
      admin = await e2eLogin('admin@foody.demo');
      cajero = await e2eLogin('cajero.test@foody.demo');
    });

    setUp(() async {
      await e2eLimpiar(admin);
      await e2eEnsureCaja(cajero);
    });

    test('mesa: crear → listo → pagando → cobro', () async {
      final mesa = await e2eMesaLibre(cajero);
      final crear = await e2eJson(
        'POST',
        '/pedidos/staff',
        headers: cajero,
        body: {
          'sucursal_id': e2eSid,
          'mesa_id': mesa,
          'tipo': 'mesa',
          'device_id': 'flt-mesa-${Random().nextInt(99999)}',
          'metodo_pago': 'efectivo',
          'items': [
            {'producto_id': e2eProducto, 'cantidad': 1, 'precio': e2ePrecio},
          ],
        },
      );
      expect(crear['exito'], isTrue);
      final id = e2ePedidoId(crear);
      expect(
        (await e2eJson(
          'PATCH',
          '/pedidos/$id/estado?sucursal_id=$e2eSid',
          headers: cajero,
          body: {'estado': 'listo'},
        ))['exito'],
        isTrue,
      );
      expect(
        (await e2eJson(
          'PATCH',
          '/pedidos/$id/estado?sucursal_id=$e2eSid',
          headers: cajero,
          body: {'estado': 'pagando'},
        ))['exito'],
        isTrue,
      );
      final cobrar = await e2eJson(
        'POST',
        '/pedidos/$id/cobrar?sucursal_id=$e2eSid',
        headers: cajero,
        body: {'metodo_pago': 'efectivo'},
      );
      expect(cobrar['exito'], isTrue);
    });

    test('QR: menú público + pedido pendiente_aprobacion', () async {
      final menu = await e2eJson('GET', '/menu/mesa/$e2eQr');
      expect(menu['exito'], isTrue);
      final datos = menu['datos'] as Map;
      final mesaMap = (datos['mesa'] as Map?) ?? datos;
      final mesaId = mesaMap['id'] as String? ??
          '30000000-0000-4000-8000-000000000001';

      final crear = await e2eJson(
        'POST',
        '/pedidos',
        body: {
          'sucursal_id': e2eSid,
          'mesa_id': mesaId,
          'device_id': 'flt-qr-${Random().nextInt(99999)}',
          'tipo': 'mesa',
          'metodo_pago': 'pendiente',
          'idempotency_key':
              '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}',
          'items': [
            {'producto_id': e2eProducto, 'cantidad': 1, 'precio': e2ePrecio},
          ],
        },
      );
      expect(crear['exito'], isTrue);
      expect((crear['datos'] as Map)['estado'], 'pendiente_aprobacion');
    });

    test('domicilio: bloqueo listo→entregado', () async {
      final crear = await e2eJson(
        'POST',
        '/pedidos/staff',
        headers: admin,
        body: {
          'sucursal_id': e2eSid,
          'tipo': 'domicilio',
          'device_id': 'flt-domi-${Random().nextInt(99999)}',
          'cliente_nombre': 'Flt Domi',
          'cliente_telefono': '3001112233',
          'direccion_entrega': 'Calle Flutter 1',
          'metodo_pago': 'pendiente',
          'items': [
            {'producto_id': e2eProducto, 'cantidad': 1, 'precio': e2ePrecio},
          ],
        },
      );
      expect(crear['exito'], isTrue);
      final id = e2ePedidoId(crear);
      await e2eJson(
        'PATCH',
        '/pedidos/$id/estado?sucursal_id=$e2eSid',
        headers: admin,
        body: {'estado': 'en_cocina'},
      );
      await e2eJson(
        'PATCH',
        '/pedidos/$id/estado?sucursal_id=$e2eSid',
        headers: admin,
        body: {'estado': 'listo'},
      );
      final saltar = await e2eJson(
        'PATCH',
        '/pedidos/$id/estado?sucursal_id=$e2eSid',
        headers: admin,
        body: {'estado': 'entregado'},
      );
      expect(saltar['exito'], isNot(true));
    });

    test('cocina: GET tickets responde', () async {
      final cocina = await e2eLogin('cocina@foody.demo');
      final cocinas = await e2eJson('GET', '/cocina/cocinas', headers: cocina);
      expect(cocinas['exito'], isTrue);
      final lista = cocinas['datos'] as List;
      expect(lista, isNotEmpty);
      final cocinaId = (lista.first as Map)['id'] as String;
      final tickets =
          await e2eJson('GET', '/cocina/tickets/$cocinaId', headers: cocina);
      expect(tickets['exito'], isTrue);
    });

    test('caja + VIE-01: add en listo mantiene estado listo', () async {
      final caja = await e2eJson('GET', '/caja/activa/$e2eSid', headers: cajero);
      expect(caja['exito'], isTrue);
      expect(caja['datos'], isNotNull);

      final mesa = await e2eMesaLibre(cajero);
      final crear = await e2eJson(
        'POST',
        '/pedidos/staff',
        headers: cajero,
        body: {
          'sucursal_id': e2eSid,
          'mesa_id': mesa,
          'tipo': 'mesa',
          'device_id': 'flt-vie01-${Random().nextInt(99999)}',
          'metodo_pago': 'efectivo',
          'items': [
            {'producto_id': e2eProducto, 'cantidad': 1, 'precio': e2ePrecio},
          ],
        },
      );
      final id = e2ePedidoId(crear);
      await e2eJson(
        'PATCH',
        '/pedidos/$id/estado?sucursal_id=$e2eSid',
        headers: cajero,
        body: {'estado': 'listo'},
      );
      final add = await e2eJson(
        'POST',
        '/pedidos/$id/items?sucursal_id=$e2eSid',
        headers: cajero,
        body: {
          'items': [
            {'producto_id': e2eProducto, 'cantidad': 1, 'precio': e2ePrecio},
          ],
        },
      );
      expect(add['exito'], isTrue);
      final det = await e2eJson(
        'GET',
        '/pedidos/$id/detalle?sucursal_id=$e2eSid',
        headers: cajero,
      );
      final datos = det['datos'] as Map;
      final estado = (datos['estado'] ?? (datos['pedido'] as Map?)?['estado'])
          as String?;
      expect(estado, 'listo');
    });
  });
}

void main() {
  registrarFlujosCriticosE2e();
}
