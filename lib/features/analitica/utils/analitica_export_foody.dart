import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Export PDF del snapshot de analítica (solo formatea datos del API).
class AnaliticaExportFoody {
  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static double _num(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  static String _fmt(dynamic v) => _moneda.format(_num(v));

  static Future<Uint8List> generarPdf({
    required String periodoLabel,
    required String filtrosLabel,
    required Map<String, dynamic>? resumen,
    required List<dynamic> topProductos,
    required List<dynamic> porTipo,
  }) async {
    final kpis = resumen?['kpis'] as Map<String, dynamic>? ?? {};
    final comp = resumen?['comparativa'] as Map<String, dynamic>?;
    final delta = comp?['delta'] as Map<String, dynamic>?;

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Foody — Centro de Análisis',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Text('Período: $periodoLabel'),
          pw.Text('Filtros: $filtrosLabel'),
          pw.SizedBox(height: 16),
          pw.Text(
            'KPIs',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Métrica', 'Valor'],
            data: [
              ['Ventas netas', _fmt(kpis['ventas_netas'])],
              ['Pedidos', '${kpis['pedidos'] ?? 0}'],
              ['Ticket promedio', _fmt(kpis['ticket_promedio'])],
              [
                'Margen bruto',
                '${_fmt(kpis['margen_bruto_estimado'])} (${_num(kpis['margen_bruto_pct']).toStringAsFixed(1)}%)',
              ],
              ['Cancelación', '${_num(kpis['pct_cancelacion']).toStringAsFixed(1)}%'],
              ['Alertas abiertas', '${kpis['alertas_abiertas'] ?? 0}'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          if (delta != null) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'vs periodo anterior: ${delta['ventas_netas_pct']}% (${delta['tendencia']})',
            ),
          ],
          pw.SizedBox(height: 12),
          if (topProductos.isNotEmpty) ...[
            pw.Text(
              'Top productos',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['#', 'Producto', 'Cantidad', 'Ventas'],
              data: [
                for (var i = 0; i < topProductos.length; i++)
                  () {
                    final p = topProductos[i] as Map<String, dynamic>;
                    return [
                      '${i + 1}',
                      '${p['nombre']}',
                      '${p['cantidad']}',
                      _fmt(p['ventas']),
                    ];
                  }(),
              ],
            ),
            pw.SizedBox(height: 12),
          ],
          if (porTipo.isNotEmpty) ...[
            pw.Text(
              'Ventas por tipo',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Tipo', 'Pedidos', 'Ventas'],
              data: porTipo
                  .map((e) {
                    final m = e as Map<String, dynamic>;
                    return ['${m['tipo']}', '${m['pedidos']}', _fmt(m['ventas'])];
                  })
                  .toList(),
            ),
          ],
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
}
