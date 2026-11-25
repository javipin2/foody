import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/reportes/utils/reporte_export_foody.dart';

const _financial = <String, dynamic>{
  'resumen': {'ventas_total': 1200, 'pedidos': 1},
  'recaudo_periodo': {
    'total_neto': 1500,
    'nota':
        'Suma ventas menos devoluciones registradas dentro del rango; puede incluir pedidos creados antes. Las propinas voluntarias van aparte.',
  },
  'cuadre_caja': {
    'ventas_pedidos': 1200,
    'ventas_movimientos_caja': 900,
    'diferencia': 300,
    'nota_periodo_caja':
        'Los movimientos ligados a pedidos se atribuyen por fecha de creación del pedido, aunque el cobro ocurra después del rango; los movimientos sin pedido usan su propia fecha.',
    'nota_universos':
        'Ventas suma pedidos válidos creados en el rango, incluso si siguen abiertos o sin cobrar. Cobros netos suma ventas menos devoluciones asociados a esos pedidos; usa la fecha del pedido, aunque el pago ocurra después del rango. Los cobros posteriores pueden cambiar este saldo. No representa el efectivo recibido en el rango ni el descuadre físico de un turno.',
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el CSV conserva la etiqueta y la regla de fechas de caja', () {
    final bytes = ReporteExportFoody.generarCsv(
      desde: '2026-11-01',
      hasta: '2026-11-23',
      financiero: _financial,
      productos: null,
      pedidos: null,
    );
    final csv = utf8.decode(bytes.skip(3).toList());

    expect(csv, contains('cobros_netos_asociados'));
    expect(csv, contains('ventas_menos_cobros'));
    expect(csv, contains('recaudo_neto_rango'));
    expect(csv, contains('cobros posteriores pueden cambiar este saldo'));
    expect(csv, contains('descuadre físico de un turno'));
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
    expect(latin1.decode(pdf), contains('Roboto'));
  });
}
