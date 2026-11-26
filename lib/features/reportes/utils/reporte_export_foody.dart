import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _notaPeriodoMovimientosCaja =
    'Los movimientos ligados a pedidos usan la fecha del pedido, aunque el cobro ocurra después del rango. Los cobros posteriores pueden cambiar el saldo; no representa el efectivo recibido en el rango ni el descuadre físico de un turno.';

/// Export PDF/CSV de reportes admin (P2-16). Solo formatea datos del API.
class ReporteExportFoody {
  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static String _fmt(dynamic v) => _moneda.format(_num(v));

  static Future<Uint8List> generarPdf({
    required String desde,
    required String hasta,
    required Map<String, dynamic>? financiero,
    required Map<String, dynamic>? productos,
    required Map<String, dynamic>? pedidos,
    String? tituloSucursal,
  }) async {
    final temaPdf = pw.ThemeData.withFont(
      base:
          pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-regular.ttf')),
      bold: pw.Font.ttf(await rootBundle.load('assets/fonts/roboto-bold.ttf')),
    );
    final doc = pw.Document(theme: temaPdf);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Foody - Reportes',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (tituloSucursal != null && tituloSucursal.isNotEmpty)
            pw.Text(tituloSucursal, style: const pw.TextStyle(fontSize: 12)),
          pw.Text('Período: $desde a $hasta'),
          pw.SizedBox(height: 16),
          ..._seccionFinancieroPdf(financiero),
          pw.SizedBox(height: 12),
          ..._seccionProductosPdf(productos),
          pw.SizedBox(height: 12),
          ..._seccionPedidosPdf(pedidos),
          pw.SizedBox(height: 24),
          pw.Text(
            'Generado ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static List<pw.Widget> _seccionFinancieroPdf(Map<String, dynamic>? data) {
    if (data == null) {
      return [pw.Text('Financiero: sin datos')];
    }
    final r = data['resumen'] as Map<String, dynamic>? ?? {};
    final cuadre = data['cuadre_caja'] as Map<String, dynamic>? ?? {};
    final recaudoPeriodo = data['recaudo_periodo'] as Map<String, dynamic>?;
    final porTipo = data['por_tipo'] as List<dynamic>? ?? [];
    final porMetodo = cuadre['por_metodo_caja'] as List<dynamic>? ?? [];

    return [
      pw.Text(
        'Financiero',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Métrica', 'Valor'],
        data: [
          ['Valor total pedidos (incluye domicilio)', _fmt(r['ventas_total'])],
          ['Pedidos', '${r['pedidos'] ?? 0}'],
          ['Ticket promedio', _fmt(r['ticket_promedio'])],
          ['Cargo domicilio incluido (referencia)', _fmt(r['costo_domicilio'])],
          ['Descuentos', _fmt(r['descuentos'])],
          ['Valor total de pedidos', _fmt(cuadre['ventas_pedidos'])],
          ['Cobros netos asociados', _fmt(cuadre['ventas_movimientos_caja'])],
          ['Valor de pedidos menos cobros', _fmt(cuadre['diferencia'])],
          if (recaudoPeriodo != null)
            [
              'Recaudo neto del rango (fecha de movimiento)',
              _fmt(recaudoPeriodo['total_neto']),
            ],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellAlignment: pw.Alignment.centerLeft,
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(
          '${cuadre['nota_periodo_caja'] ?? _notaPeriodoMovimientosCaja}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      if (recaudoPeriodo?['nota'] != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            recaudoPeriodo!['nota'].toString(),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      if (cuadre['nota_universos'] != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            cuadre['nota_universos'].toString(),
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
      if (porMetodo.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('Cobros asociados por método',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ['Método', 'Total'],
          data: porMetodo.map((e) {
            final m = e as Map<String, dynamic>;
            return ['${m['metodo_pago']}', _fmt(m['total'])];
          }).toList(),
        ),
      ],
      if (porTipo.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('Por tipo de pedido',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: [
            'Tipo',
            'Pedidos',
            'Valor total pedido',
            'Domicilio incluido'
          ],
          data: porTipo.map((e) {
            final m = e as Map<String, dynamic>;
            return [
              '${m['tipo']}',
              '${m['pedidos']}',
              _fmt(m['ventas']),
              _fmt(m['costo_domicilio']),
            ];
          }).toList(),
        ),
      ],
    ];
  }

  static List<pw.Widget> _seccionProductosPdf(Map<String, dynamic>? data) {
    final ranking = data?['ranking'] as List<dynamic>? ?? [];
    if (ranking.isEmpty) {
      return [
        pw.Text(
          'Productos',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Sin ventas en el período'),
      ];
    }
    return [
      pw.Text(
        'Top productos',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['#', 'Producto', 'Cantidad', 'Ventas'],
        data: [
          for (var i = 0; i < ranking.length; i++)
            () {
              final p = ranking[i] as Map<String, dynamic>;
              return [
                '${i + 1}',
                '${p['nombre']}',
                '${p['cantidad']}',
                _fmt(p['ventas']),
              ];
            }(),
        ],
      ),
    ];
  }

  static List<pw.Widget> _seccionPedidosPdf(Map<String, dynamic>? data) {
    if (data == null) {
      return [pw.Text('Pedidos: sin datos')];
    }
    final porEstado = data['por_estado'] as List<dynamic>? ?? [];
    final porDia = data['por_dia'] as List<dynamic>? ?? [];
    return [
      pw.Text(
        'Pedidos',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      if (porEstado.isNotEmpty)
        pw.TableHelper.fromTextArray(
          headers: ['Estado', 'Total'],
          data: porEstado.map((e) {
            final m = e as Map<String, dynamic>;
            return ['${m['estado']}', '${m['total']}'];
          }).toList(),
        ),
      if (porDia.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text('Por día', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: [
            'Día',
            'Pedidos',
            'Valor total pedidos',
            'Domicilio incluido'
          ],
          data: porDia.map((e) {
            final m = e as Map<String, dynamic>;
            return [
              '${m['dia']}',
              '${m['pedidos']}',
              _fmt(m['ventas']),
              _fmt(m['costo_domicilio']),
            ];
          }).toList(),
        ),
      ],
    ];
  }

  /// CSV compatible con Excel (UTF-8 BOM).
  static Uint8List generarCsv({
    required String desde,
    required String hasta,
    required Map<String, dynamic>? financiero,
    required Map<String, dynamic>? productos,
    required Map<String, dynamic>? pedidos,
  }) {
    final filas = <List<dynamic>>[
      ['Foody - Reportes'],
      ['Periodo', desde, hasta],
      [],
    ];

    void bloque(String titulo, List<List<dynamic>> data) {
      filas.add(['# $titulo']);
      filas.addAll(data);
      filas.add([]);
    }

    if (financiero != null) {
      final r = financiero['resumen'] as Map<String, dynamic>? ?? {};
      final cuadre = financiero['cuadre_caja'] as Map<String, dynamic>? ?? {};
      final recaudoPeriodo =
          financiero['recaudo_periodo'] as Map<String, dynamic>?;
      bloque('Financiero - resumen', [
        ['metrica', 'valor'],
        ['valor_total_pedidos_incluye_domicilio', _num(r['ventas_total'])],
        ['pedidos', r['pedidos'] ?? 0],
        ['ticket_promedio', _num(r['ticket_promedio'])],
        ['cargo_domicilio_incluido_referencia', _num(r['costo_domicilio'])],
        ['descuentos', _num(r['descuentos'])],
        ['valor_total_de_pedidos', _num(cuadre['ventas_pedidos'])],
        ['cobros_netos_asociados', _num(cuadre['ventas_movimientos_caja'])],
        ['valor_pedidos_menos_cobros', _num(cuadre['diferencia'])],
        if (recaudoPeriodo != null) ...[
          ['recaudo_neto_rango', _num(recaudoPeriodo['total_neto'])],
          ['nota_recaudo_rango', recaudoPeriodo['nota']],
        ],
        [
          'nota_periodo_caja',
          cuadre['nota_periodo_caja'] ?? _notaPeriodoMovimientosCaja,
        ],
        if (cuadre['nota_universos'] != null)
          ['nota_universos', cuadre['nota_universos']],
      ]);
      final porTipo = financiero['por_tipo'] as List<dynamic>? ?? [];
      if (porTipo.isNotEmpty) {
        bloque('Financiero - por tipo', [
          ['tipo', 'pedidos', 'valor_total_pedido', 'domicilio_incluido'],
          ...porTipo.map((e) {
            final m = e as Map<String, dynamic>;
            return [
              m['tipo'],
              m['pedidos'],
              _num(m['ventas']),
              _num(m['costo_domicilio']),
            ];
          }),
        ]);
      }
    }

    final ranking = productos?['ranking'] as List<dynamic>? ?? [];
    if (ranking.isNotEmpty) {
      bloque('Productos', [
        ['producto', 'cantidad', 'ventas'],
        ...ranking.map((e) {
          final p = e as Map<String, dynamic>;
          return [p['nombre'], p['cantidad'], _num(p['ventas'])];
        }),
      ]);
    }

    if (pedidos != null) {
      final porEstado = pedidos['por_estado'] as List<dynamic>? ?? [];
      if (porEstado.isNotEmpty) {
        bloque('Pedidos - por estado', [
          ['estado', 'total'],
          ...porEstado.map((e) {
            final m = e as Map<String, dynamic>;
            return [m['estado'], m['total']];
          }),
        ]);
      }
      final porDia = pedidos['por_dia'] as List<dynamic>? ?? [];
      if (porDia.isNotEmpty) {
        bloque('Pedidos - por dia', [
          ['dia', 'pedidos', 'valor_total_pedidos', 'domicilio_incluido'],
          ...porDia.map((e) {
            final m = e as Map<String, dynamic>;
            return [
              m['dia'],
              m['pedidos'],
              _num(m['ventas']),
              _num(m['costo_domicilio']),
            ];
          }),
        ]);
      }
    }

    final csv = const ListToCsvConverter().convert(filas);
    // BOM para Excel en Windows
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
  }
}
