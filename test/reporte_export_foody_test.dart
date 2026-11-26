import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:reserva_canchas/features/reportes/utils/reporte_export_foody.dart';

const _financial = <String, dynamic>{
  'resumen': {
    'ventas_total': 1200,
    'pedidos': 1,
    'costo_domicilio': 200,
  },
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
        'El valor total suma pedidos e incluye el cargo de domicilio; este se desglosa aparte y no debe sumarse dos veces. No representa ingreso reconocido.',
  },
  'por_tipo': [
    {
      'tipo': 'domicilio',
      'pedidos': 1,
      'ventas': 1200,
      'costo_domicilio': 200,
    },
  ],
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
    expect(csv, contains('valor_pedidos_menos_cobros'));
    expect(csv, contains('valor_total_pedidos_incluye_domicilio'));
    expect(csv, contains('cargo_domicilio_incluido_referencia'));
    expect(csv, contains('domicilio_incluido'));
    expect(csv, contains('recaudo_neto_rango'));
    expect(csv, contains('no debe sumarse dos veces'));
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
