import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';

/// Búsqueda global admin: módulos + pedidos activos + mesas (AR-28).
Future<void> mostrarBusquedaAdmin({
  required BuildContext context,
  required String sucursalId,
  required List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> grupos,
  required ValueChanged<String> onIrSeccion,
  required ValueChanged<String> onIrMesa,
  ValueChanged<String>? onIrPedido,
  PedidosRepository? pedidosRepository,
  MesasRepository? mesasRepository,
}) async {
  // Incluye módulos bloqueados por plan (preview borroso + upgrade).
  final modulos = <({MenuAdminItem item, String grupo})>[];
  for (final g in grupos) {
    for (final item in g.items) {
      modulos.add((item: item, grupo: g.grupo.titulo));
    }
  }

  Future<({List<T> datos, String? error})> cargar<T>(
    Future<List<T>> consulta,
    String nombre,
  ) async {
    try {
      return (datos: await consulta, error: null);
    } catch (e) {
      return (datos: <T>[], error: mensajeErrorHttp(e, contexto: nombre));
    }
  }

  final pedidosRepo = pedidosRepository ?? PedidosRepository();
  Future<({List<PedidoAdminModel> datos, String? error})> pedidosFuture =
      Future.value((datos: <PedidoAdminModel>[], error: null));
  final mesasRepo = mesasRepository ?? MesasRepository();
  var mesasFuture = cargar(mesasRepo.listar(sucursalId), 'buscar mesas');
  var filtro = '';
  Timer? temporizadorBusqueda;

  await FoodyDialogo.mostrar<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) => FutureBuilder(
          future: pedidosFuture,
          builder: (context, pedidosSnapshot) => FutureBuilder(
            future: mesasFuture,
            builder: (context, mesasSnapshot) {
              final pedidos =
                  pedidosSnapshot.data?.datos ?? <PedidoAdminModel>[];
              final mesas =
                  mesasSnapshot.data?.datos ?? <Map<String, dynamic>>[];
              final q = filtro.trim().toLowerCase();
              final buscandoPedidos = q.length >= 2 && !pedidosSnapshot.hasData;
              final cargandoMesas = !mesasSnapshot.hasData;
              final errorPedidos = pedidosSnapshot.data?.error;
              final errorMesas = mesasSnapshot.data?.error;
              final scheme = Theme.of(context).colorScheme;
              final pedidosMatch = q.isEmpty
                  ? <PedidoAdminModel>[]
                  : pedidos
                      .where(
                        (p) =>
                            p.numeroPedido.toLowerCase().contains(q) ||
                            (p.clienteNombre ?? '').toLowerCase().contains(q) ||
                            (p.clienteTelefono ?? '')
                                .toLowerCase()
                                .contains(q) ||
                            (p.mesaNombre ?? '').toLowerCase().contains(q),
                      )
                      .take(6)
                      .toList();

              final mesasMatch = q.isEmpty
                  ? <Map<String, dynamic>>[]
                  : mesas
                      .where(
                        (m) => '${m['nombre']}'.toLowerCase().contains(q),
                      )
                      .take(6)
                      .toList();

              final modulosMatch = q.isEmpty
                  ? modulos.take(8).toList()
                  : modulos
                      .where((e) {
                        final t = e.item.titulo.toLowerCase();
                        final r = e.item.ruta.toLowerCase();
                        return t.contains(q) || r.contains(q);
                      })
                      .take(8)
                      .toList();

              final sinResultados = q.length >= 2 &&
                  !buscandoPedidos &&
                  errorPedidos == null &&
                  errorMesas == null &&
                  pedidosMatch.isEmpty &&
                  mesasMatch.isEmpty &&
                  modulosMatch.isEmpty;

              final screen = MediaQuery.sizeOf(context);
              final keyboard = MediaQuery.viewInsetsOf(context).bottom;
              final altoMaximo = math.max(
                180.0,
                math.min(640.0, screen.height - keyboard - 48),
              );

              return Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: math.min(680.0, screen.width - 32),
                    maxHeight: altoMaximo,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Buscar en Foody',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cerrar búsqueda',
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: TextField(
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            labelText: 'Buscar módulos, pedidos o mesas',
                            hintText: 'Nombre, teléfono o número de pedido',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (v) {
                            temporizadorBusqueda?.cancel();
                            final consulta = v.trim();
                            setState(() {
                              filtro = v;
                              pedidosFuture = Future.value(
                                (datos: <PedidoAdminModel>[], error: null),
                              );
                            });
                            if (consulta.length >= 2) {
                              temporizadorBusqueda = Timer(
                                const Duration(milliseconds: 250),
                                () => setState(() {
                                  pedidosFuture = cargar(
                                    pedidosRepo.buscarActivos(
                                      sucursalId: sucursalId,
                                      consulta: consulta,
                                    ),
                                    'buscar pedidos',
                                  );
                                }),
                              );
                            }
                          },
                        ),
                      ),
                      if (buscandoPedidos || cargandoMesas)
                        const LinearProgressIndicator(
                          semanticsLabel: 'Buscando coincidencias',
                        ),
                      if (errorPedidos != null)
                        _ErrorBusqueda(
                          mensaje: errorPedidos,
                          onReintentar: q.length < 2
                              ? null
                              : () => setState(() {
                                    pedidosFuture = cargar(
                                      pedidosRepo.buscarActivos(
                                        sucursalId: sucursalId,
                                        consulta: filtro.trim(),
                                      ),
                                      'buscar pedidos',
                                    );
                                  }),
                        ),
                      if (errorMesas != null)
                        _ErrorBusqueda(
                          mensaje: errorMesas,
                          onReintentar: () => setState(() {
                            mesasFuture = cargar(
                              mesasRepo.listar(sucursalId),
                              'buscar mesas',
                            );
                          }),
                        ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                          children: [
                            if (pedidosMatch.isNotEmpty) ...[
                              _tituloSeccion(context, 'Pedidos activos'),
                              ...pedidosMatch.map(
                                (p) => ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    Icons.receipt_long,
                                    color: scheme.primary,
                                  ),
                                  title: Text(
                                    p.numeroPedido,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      if (p.mesaNombre != null)
                                        'Mesa ${p.mesaNombre}',
                                      if (p.clienteNombre != null)
                                        p.clienteNombre!,
                                      p.estado.replaceAll('_', ' '),
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    if (onIrPedido != null) {
                                      onIrPedido(p.id);
                                    } else {
                                      onIrSeccion('pedidos');
                                    }
                                  },
                                ),
                              ),
                            ],
                            if (mesasMatch.isNotEmpty) ...[
                              _tituloSeccion(context, 'Mesas'),
                              ...mesasMatch.map(
                                (m) => ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    Icons.table_restaurant,
                                    color: scheme.secondary,
                                  ),
                                  title: Text('${m['nombre']}'),
                                  subtitle: Text('${m['estado'] ?? 'mesa'}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onIrMesa('${m['id']}');
                                  },
                                ),
                              ),
                            ],
                            if (modulosMatch.isNotEmpty) ...[
                              _tituloSeccion(
                                context,
                                q.isEmpty ? 'Accesos rápidos' : 'Módulos',
                              ),
                              ...modulosMatch.map(
                                (e) => ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    e.item.bloqueadoPorPlan
                                        ? Icons.lock_outline
                                        : e.item.icono,
                                    color: e.item.bloqueadoPorPlan
                                        ? scheme.onSurfaceVariant
                                        : scheme.primary,
                                  ),
                                  title: Text(
                                    e.item.titulo,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    e.item.bloqueadoPorPlan
                                        ? '${e.grupo} · Requiere plan superior'
                                        : e.grupo,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onIrSeccion(e.item.ruta);
                                  },
                                ),
                              ),
                            ],
                            if (q.length == 1 &&
                                pedidosMatch.isEmpty &&
                                mesasMatch.isEmpty &&
                                modulosMatch.isEmpty)
                              const _NotaBusqueda(
                                icono: Icons.keyboard,
                                texto:
                                    'Escribe al menos 2 caracteres para buscar pedidos.',
                              ),
                            if (sinResultados)
                              _NotaBusqueda(
                                icono: Icons.search_off,
                                texto: 'Sin resultados para «$filtro».',
                              ),
                            if (q.isEmpty && modulosMatch.isEmpty)
                              const _NotaBusqueda(
                                icono: Icons.search,
                                texto:
                                    'Escribe para buscar pedidos, mesas o módulos.',
                              ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cerrar'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
  temporizadorBusqueda?.cancel();
}

Widget _tituloSeccion(BuildContext context, String titulo) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 5),
    child: Text(
      titulo,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ErrorBusqueda extends StatelessWidget {
  const _ErrorBusqueda({required this.mensaje, this.onReintentar});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (onReintentar != null)
            TextButton(
                onPressed: onReintentar, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _NotaBusqueda extends StatelessWidget {
  const _NotaBusqueda({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Column(
        children: [
          Icon(icono, size: 24, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
