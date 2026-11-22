import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Genera PDF imprimible con QR de mesa (P2-01).
class MesaQrPdfFoody {
  static Future<Uint8List> generar({
    required String nombreMesa,
    required String urlQr,
    String? restaurante,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (restaurante != null && restaurante.isNotEmpty) ...[
              pw.Text(
                restaurante,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 8),
            ],
            pw.Text(
              nombreMesa,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Escanea para ver el menú y pedir',
              style: const pw.TextStyle(fontSize: 11),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 24),
            pw.BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: urlQr,
              width: 180,
              height: 180,
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              urlQr,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
