import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/reportes/utils/reporte_export_foody.dart';

const _financial = <String, dynamic>{
  'resumen': {'ventas_total': 1200, 'pedidos': 1},
  'cuadre_caja': {
    'ventas_pedidos': 1200,
    'ventas_movimientos_caja': 900,
    'diferencia': 300,
    'nota_periodo_caja':
        'En movimientos ligados a un pedido se usa la fecha de creación del pedido; si no tienen pedido, la fecha del movimiento.',
    'nota_universos': 'Tickets y caja son universos distintos.',
  },
};

void main() {
  test('el CSV conserva la etiqueta y la regla de fechas de caja', () {
    final bytes = ReporteExportFoody.generarCsv(
      desde: '2026-11-01',
      hasta: '2026-11-23',
      financiero: _financial,
      productos: null,
      pedidos: null,
    );
    final csv = utf8.decode(bytes.skip(3).toList());

    expect(csv, contains('movimientos_netos_caja'));
    expect(csv, contains('fecha de creación del pedido'));
    expect(csv, contains('Tickets y caja son universos distintos'));
  });

  test('el PDF financiero se genera con contexto de fechas presente', () async {
    final pdf = await ReporteExportFoody.generarPdf(
      desde: '2026-11-01',
      hasta: '2026-11-23',
      financiero: _financial,
      productos: null,
      pedidos: null,
    );

    expect(utf8.decode(pdf.take(4).toList()), '%PDF');
  });
}
