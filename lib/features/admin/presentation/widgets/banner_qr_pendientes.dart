import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';

/// Banner mesero: pedidos QR pendientes de aprobación (MES-012 / NAV-MS-14).
class BannerQrPendientes extends StatefulWidget {
  const BannerQrPendientes({
    super.key,
    required this.sucursalId,
    this.onRevisar,
  });

  final String sucursalId;
  /// NAV-MS-14: saltar a tab Mesas (o abrir QR).
  final VoidCallback? onRevisar;

  @override
  State<BannerQrPendientes> createState() => _BannerQrPendientesState();
}

class _BannerQrPendientesState extends State<BannerQrPendientes> {
  final _repo = MesasRepository();
  List<Map<String, dynamic>> _mesas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    try {
      final mesas = await _repo.listar(widget.sucursalId);
      if (mounted) {
        setState(() {
          _mesas = mesas;
          _cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  static int contarPendientes(List<Map<String, dynamic>> mesas) {
    return mesas
        .where((m) => m['pedido_estado'] == 'pendiente_aprobacion')
        .length;
  }

  static int contarUrgentes(List<Map<String, dynamic>> mesas) {
    final ahora = DateTime.now();
    var n = 0;
    for (final m in mesas) {
      if (m['pedido_estado'] != 'pendiente_aprobacion') continue;
      final creado = DateTime.tryParse('${m['pedido_creado_at']}');
      if (creado == null) continue;
      if (ahora.difference(creado.toLocal()).inMinutes >= 3) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    final pendientes = contarPendientes(_mesas);
    if (pendientes == 0) return const SizedBox.shrink();
    final urgentes = contarUrgentes(_mesas);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onRevisar,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: urgentes > 0
                ? Colors.orange.shade50
                : ColoresFoody.primario.withValues(alpha: 0.1),
            border: Border.all(
              color:
                  urgentes > 0 ? Colors.orange.shade700 : ColoresFoody.primario,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: urgentes > 0
                    ? Colors.orange.shade700
                    : ColoresFoody.primario,
                foregroundColor: Colors.white,
                child: Text(
                  '$pendientes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendientes == 1
                          ? '1 pedido QR por aprobar'
                          : '$pendientes pedidos QR por aprobar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      urgentes > 0
                          ? (urgentes == 1
                              ? '1 lleva más de 3 min — toca para ir a Mesas'
                              : '$urgentes llevan más de 3 min — toca para ir a Mesas')
                          : 'Toca para revisar en Mesas',
                      style: TextStyle(
                        fontSize: 12,
                        color: urgentes > 0
                            ? Colors.red.shade700
                            : Colors.grey.shade700,
                        fontWeight:
                            urgentes > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onRevisar != null)
                FilledButton(
                  onPressed: widget.onRevisar,
                  style: FilledButton.styleFrom(
                    backgroundColor: urgentes > 0
                        ? Colors.orange.shade700
                        : ColoresFoody.primario,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Revisar'),
                )
              else
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _cargar,
                  icon: const Icon(Icons.refresh_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
