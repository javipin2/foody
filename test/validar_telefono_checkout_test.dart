import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/pedidos/presentation/validar_telefono_checkout.dart';

void main() {
  group('validarTelefonoCheckout', () {
    test('requires a callable phone for delivery', () {
      expect(
        validarTelefonoCheckout('   ', domicilio: true),
        'El teléfono es obligatorio para coordinar la entrega',
      );
      expect(validarTelefonoCheckout('abc1234567', domicilio: true), isNotNull);
      expect(validarTelefonoCheckout('1234', domicilio: true), isNotNull);
    });

    test('accepts national and formatted international numbers', () {
      expect(validarTelefonoCheckout('3001234567', domicilio: true), isNull);
      expect(
        validarTelefonoCheckout('+57 (300) 123-4567', domicilio: true),
        isNull,
      );
    });

    test('does not require contact phone for non-delivery orders', () {
      expect(validarTelefonoCheckout(null, domicilio: false), isNull);
    });
  });
}
