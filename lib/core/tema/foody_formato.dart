import 'package:intl/intl.dart';

/// Formato visual centralizado (ponytail: una fuente de verdad para moneda).
class FoodyFormato {
  FoodyFormato._();

  static final NumberFormat moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static String monedaDe(num valor) => moneda.format(valor);
}
