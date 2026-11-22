import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_estado_pill.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Tabla / cards de últimos pedidos (dashboard Resumen).
class AnaliticaPedidosTabla extends StatelessWidget {
  const AnaliticaPedidosTabla({
    super.key,
    required this.pedidos,
    this.onVerMas,
  });

  final List<dynamic> pedidos;
  final VoidCallback? onVerMas;

  static final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return Container(
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r20),
        border: Border.all(color: AnaliticaTokens.borderSoft),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actividad reciente',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AnaliticaTokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Pedidos del periodo · vista operativa',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onVerMas != null)
                  IconButton(
                    tooltip: 'Ver más',
                    onPressed: onVerMas,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (pedidos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sin pedidos en el periodo',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          else if (compacto)
            ...pedidos.take(12).map(_cardMovil)
          else ...[
            _encabezado(),
            Divider(height: 1, color: AnaliticaTokens.borderSoft),
            ...pedidos.take(12).map(_filaDesktop),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _encabezado() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AnaliticaTokens.inkSoft,
      letterSpacing: 0.4,
    );
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text('#PEDIDO', style: style)),
          Expanded(flex: 2, child: Text('MESA / CANAL', style: style)),
          Expanded(flex: 2, child: Text('CLIENTE', style: style)),
          SizedBox(
            width: 96,
            child: Text('TOTAL', style: style, textAlign: TextAlign.right),
          ),
          SizedBox(width: 12),
          SizedBox(width: 120, child: Text('ESTADO', style: style)),
          SizedBox(
            width: 52,
            child: Text('HORA', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _filaDesktop(dynamic raw) {
    final p = raw as Map<String, dynamic>;
    final numero = '#${p['numero_pedido'] ?? '—'}';
    final mesa = p['mesa_nombre'] as String?;
    final tipo = p['tipo'] as String? ?? '';
    final canal = mesa != null && mesa.isNotEmpty
        ? 'Mesa $mesa'
        : _labelTipo(tipo);
    final cliente = (p['cliente_nombre'] as String?)?.trim();
    final total = p['total'];
    final totalN =
        total is num ? total.toDouble() : double.tryParse('$total') ?? 0;
    final hora = _hora(p['created_at'] as String?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AnaliticaTokens.surfaceMuted,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              numero,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AnaliticaTokens.ink,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              canal,
              style: const TextStyle(
                color: AnaliticaTokens.inkMuted,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (cliente == null || cliente.isEmpty) ? '—' : cliente,
              style: const TextStyle(
                color: AnaliticaTokens.inkMuted,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              _moneda.format(totalN),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AnaliticaTokens.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnaliticaEstadoPill.pedido(p['estado'] as String? ?? ''),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              hora,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: AnaliticaTokens.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardMovil(dynamic raw) {
    final p = raw as Map<String, dynamic>;
    final numero = '#${p['numero_pedido'] ?? '—'}';
    final mesa = p['mesa_nombre'] as String?;
    final tipo = p['tipo'] as String? ?? '';
    final canal =
        mesa != null && mesa.isNotEmpty ? 'Mesa $mesa' : _labelTipo(tipo);
    final total = p['total'];
    final totalN =
        total is num ? total.toDouble() : double.tryParse('$total') ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AnaliticaTokens.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AnaliticaTokens.borderSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    numero,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$canal · ${_hora(p['created_at'] as String?)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AnaliticaTokens.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _moneda.format(totalN),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                AnaliticaEstadoPill.pedido(p['estado'] as String? ?? ''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _labelTipo(String tipo) {
    return switch (tipo) {
      'mesa' => 'Mesa',
      'domicilio' => 'Domicilio',
      'para_llevar' => 'Para llevar',
      'encargo' => 'Encargo',
      _ => tipo.isEmpty ? '—' : tipo,
    };
  }

  static String _hora(String? iso) {
    if (iso == null || iso.length < 16) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return iso.length >= 16 ? iso.substring(11, 16) : '—';
    }
  }
}
