import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';

/// Modal para asignar mesero al confirmar un pedido QR.
Future<String?> mostrarAsignarMeseroSheet({
  required BuildContext context,
  required PedidoAdminModel pedido,
  required String sucursalId,
  String? meseraPreseleccionadaId,
}) {
  final ancho = MediaQuery.sizeOf(context).width;
  if (FoodyBreakpoints.esExpanded(ancho)) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: _AsignarMeseroContenido(
            pedido: pedido,
            sucursalId: sucursalId,
            meseraPreseleccionadaId: meseraPreseleccionadaId,
            onCerrar: () => Navigator.pop(ctx),
            onConfirmar: (id) => Navigator.pop(ctx, id),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _AsignarMeseroContenido(
        pedido: pedido,
        sucursalId: sucursalId,
        meseraPreseleccionadaId: meseraPreseleccionadaId,
        onCerrar: () => Navigator.pop(ctx),
        onConfirmar: (id) => Navigator.pop(ctx, id),
      ),
    ),
  );
}

class _AsignarMeseroContenido extends StatefulWidget {
  const _AsignarMeseroContenido({
    required this.pedido,
    required this.sucursalId,
    required this.onCerrar,
    required this.onConfirmar,
    this.meseraPreseleccionadaId,
  });

  final PedidoAdminModel pedido;
  final String sucursalId;
  final String? meseraPreseleccionadaId;
  final VoidCallback onCerrar;
  final ValueChanged<String> onConfirmar;

  @override
  State<_AsignarMeseroContenido> createState() => _AsignarMeseroContenidoState();
}

class _AsignarMeseroContenidoState extends State<_AsignarMeseroContenido> {
  final _repo = UsuariosRepository();
  late Future<List<Map<String, dynamic>>> _future;
  String? _seleccion;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _seleccion = widget.meseraPreseleccionadaId;
    _future = _repo.listarMeserosActivos(widget.sucursalId);
  }

  @override
  Widget build(BuildContext context) {
    final mesa = widget.pedido.mesaNombre?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Asignar mesero',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ColoresFoody.texto,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            mesa != null && mesa.isNotEmpty
                ? 'Pedido ${widget.pedido.numeroPedido} · Mesa $mesa'
                : 'Pedido ${widget.pedido.numeroPedido}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4ED),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF5C4A3)),
            ),
            child: const Text(
              'El mesero queda a cargo de esta mesa: atiende al cliente, '
              'cobra la cuenta y evita que se retire sin pagar. '
              'Al confirmar, el pedido pasa a cocina y se imprime la comanda.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Text(
                  'No se pudieron cargar los meseros',
                  style: TextStyle(color: ColoresFoody.error),
                );
              }
              final lista = snap.data ?? [];
              if (lista.isEmpty) {
                return const Text(
                  'No hay meseros activos en esta sucursal. '
                  'Créalos en Usuarios antes de confirmar pedidos QR.',
                );
              }
              _seleccion ??= lista.first['id'] as String?;
              return DropdownButtonFormField<String>(
                initialValue: lista.any((m) => m['id'] == _seleccion)
                    ? _seleccion
                    : lista.first['id'] as String,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Mesero responsable',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in lista)
                    DropdownMenuItem(
                      value: m['id'] as String,
                      child: Text(m['nombre'] as String? ?? '—'),
                    ),
                ],
                onChanged: _enviando
                    ? null
                    : (v) => setState(() => _seleccion = v),
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton(
                onPressed: _enviando ? null : widget.onCerrar,
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _enviando || _seleccion == null
                    ? null
                    : () {
                        setState(() => _enviando = true);
                        widget.onConfirmar(_seleccion!);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                ),
                child: const Text('Confirmar y a cocina'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
