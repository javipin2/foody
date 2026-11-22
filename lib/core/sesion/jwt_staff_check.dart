// Self-check: dart run lib/core/sesion/jwt_staff_check.dart
// ponytail: falla si el parseo de exp se rompe.
import 'dart:convert';

import 'jwt_staff.dart';

void main() {
  final futuro = DateTime.now().toUtc().add(const Duration(hours: 1));
  final pasado = DateTime.now().toUtc().subtract(const Duration(hours: 1));
  final ok = _jwtConExp(futuro);
  final malo = _jwtConExp(pasado);

  assert(!JwtStaff.expirado(ok), 'token futuro debe ser válido');
  assert(JwtStaff.expirado(malo), 'token pasado debe estar expirado');
  assert(JwtStaff.expirado('no-es-jwt'), 'basura debe contar como expirado');
  assert(
    JwtStaff.porExpirar(ok, ventana: const Duration(hours: 2)),
    'token a 1h debe porExpirar con ventana 2h',
  );
  assert(
    !JwtStaff.porExpirar(ok, ventana: const Duration(minutes: 5)),
    'token a 1h no debe porExpirar con ventana 5m',
  );
  // ignore: avoid_print
  print('jwt_staff_check OK');
}

String _jwtConExp(DateTime exp) {
  final header = base64Url.encode(utf8.encode('{"alg":"none"}'));
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': exp.millisecondsSinceEpoch ~/ 1000})),
  );
  return '$header.$payload.sig';
}
