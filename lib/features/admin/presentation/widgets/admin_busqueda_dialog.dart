import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
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

  final pedidosFuture = cargar(
    PedidosRepository().listarActivos(sucursalId: sucursalId),
    'buscar pedidos',
  );
  final mesasFuture =
      cargar(MesasRepository().listar(sucursalId), 'buscar mesas');
  var filtro = '';

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
              final cargandoEntidades =
                  !pedidosSnapshot.hasData || !mesasSnapshot.hasData;
              final errores = [
                pedidosSnapshot.data?.error,
                mesasSnapshot.data?.error,
              ].whereType<String>();
              final scheme = Theme.of(context).colorScheme;
              final q = filtro.trim().toLowerCase();

              final pedidosMatch = q.isEmpty
                  ? <PedidoAdminModel>[]
                  : pedidos
                      .where(
                        (p) =>
                            p.numeroPedido.toLowerCase().contains(q) ||
                            (p.clienteNombre ?? '').toLowerCase().contains(q) ||
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

              final sinResultados = q.isNotEmpty &&
                  !cargandoEntidades &&
                  pedidosMatch.isEmpty &&
                  mesasMatch.isEmpty &&
                  modulosMatch.isEmpty;

              return AlertDialog(
                title: const Text('Buscar en Foody'),
                content: SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 48)
                      .clamp(280.0, 720.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Módulo, pedido o mesa',
                          hintText: 'Escribe un nombre o número',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => filtro = v),
                      ),
                      if (cargandoEntidades) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(
                          semanticsLabel: 'Buscando pedidos y mesas',
                        ),
                      ],
                      for (final error in errores) ...[
                        const SizedBox(height: 8),
                        Text(
                          error,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            if (pedidosMatch.isNotEmpty) ...[
                              _tituloSeccion('Pedidos'),
                              ...pedidosMatch.map(
                                (p) => ListTile(
                                  leading: const Icon(
                                    Icons.receipt_long,
                                    color: ColoresFoody.primario,
                                  ),
                                  title: Text(p.numeroPedido),
                                  subtitle: Text(
                                    [
                                      if (p.mesaNombre != null)
                                        'Mesa ${p.mesaNombre}',
                                      if (p.clienteNombre != null)
                                        p.clienteNombre!,
                                      p.estado.replaceAll('_', ' '),
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                  ),
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
                              _tituloSeccion('Mesas'),
                              ...mesasMatch.map(
                                (m) => ListTile(
                                  leading: const Icon(
                                    Icons.table_restaurant,
                                    color: ColoresFoody.secundario,
                                  ),
                                  title: Text('${m['nombre']}'),
                                  subtitle: Text('${m['estado'] ?? 'mesa'}'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onIrMesa('${m['id']}');
                                  },
                                ),
                              ),
                            ],
                            if (modulosMatch.isNotEmpty) ...[
                              _tituloSeccion('Módulos'),
                              ...modulosMatch.map(
                                (e) => ListTile(
                                  leading: Icon(
                                    e.item.bloqueadoPorPlan
                                        ? Icons.lock_outline
                                        : e.item.icono,
                                    color: e.item.bloqueadoPorPlan
                                        ? Colors.grey
                                        : ColoresFoody.primario,
                                  ),
                                  title: Text(e.item.titulo),
                                  subtitle: Text(
                                    e.item.bloqueadoPorPlan
                                        ? '${e.grupo} · Requiere plan superior'
                                        : e.grupo,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onIrSeccion(e.item.ruta);
                                  },
                                ),
                              ),
                            ],
                            if (sinResultados)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Sin resultados para «$filtro»',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

Widget _tituloSeccion(String titulo) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
    child: Text(
      titulo,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: ColoresFoody.primario,
      ),
    ),
  );
}
