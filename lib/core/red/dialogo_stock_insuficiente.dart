import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Muestra diálogo detallado si el error es STOCK_INSUFICIENTE; devuelve true si lo mostró.
Future<bool> mostrarDialogoStockSiAplica(
  BuildContext context,
  Object error,
) async {
  if (error is! DioException) return false;
  final data = error.response?.data;
  if (data is! Map || data['error'] != 'STOCK_INSUFICIENTE') return false;

  final detalles = data['detalles'];
  final lineas = <String>[];
  if (detalles is List) {
    for (final d in detalles) {
      if (d is! Map) continue;
      final nombre = d['nombre'] ?? 'Insumo';
      final necesita = d['necesita'];
      final disponible = d['disponible'];
      final unidad = d['unidad'] ?? '';
      lineas.add('• $nombre: necesitas $necesita $unidad, hay $disponible');
    }
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.inventory_2_outlined, color: ColoresFoody.error, size: 36),
      title: const Text('Stock insuficiente'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['mensaje']?.toString() ??
                  'No hay insumos suficientes para este pedido.',
            ),
            if (lineas.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...lineas.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
  return true;
}
