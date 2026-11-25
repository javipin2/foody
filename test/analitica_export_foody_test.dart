import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/analitica/utils/analitica_export_foody.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el PDF de análisis incrusta una fuente compatible con español',
      () async {
    final pdf = await AnaliticaExportFoody.generarPdf(
      periodoLabel: 'Últimos 7 días',
      filtrosLabel: 'Sucursal principal',
      resumen: {
        'kpis': {
          'ventas_netas': 125000,
          'pedidos': 3,
          'ticket_promedio': 41666,
          'margen_bruto_estimado': 65000,
          'margen_bruto_pct': 52,
          'pct_cancelacion': 0,
          'alertas_abiertas': 1,
        },
      },
      topProductos: [
        {'nombre': 'Arepa con queso', 'cantidad': 2, 'ventas': 25000},
      ],
      porTipo: [
        {'tipo': 'domicilio', 'pedidos': 1, 'ventas': 15000},
      ],
    );

    expect(utf8.decode(pdf.take(4).toList()), '%PDF');
    expect(latin1.decode(pdf), contains('Roboto'));
  });
}
