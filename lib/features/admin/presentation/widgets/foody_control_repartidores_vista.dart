import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/data/super_admin_repository.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliario_documentos_screen.dart';

/// Foody Control — repartidores independientes y revisión de documentos (P1-12).
class FoodyControlRepartidoresVista extends StatefulWidget {
  const FoodyControlRepartidoresVista({super.key, required this.repo});

  final SuperAdminRepository repo;

  @override
  State<FoodyControlRepartidoresVista> createState() =>
      _FoodyControlRepartidoresVistaState();
}

class _FoodyControlRepartidoresVistaState
    extends State<FoodyControlRepartidoresVista> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _docsFuture;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _future = widget.repo.domiciliarios();
      _docsFuture = widget.repo.documentosPendientes();
    });
  }

  String _etiquetaEstado(String? estado) {
    switch (estado) {
      case 'activo':
        return 'Activo';
      case 'pendiente_verificacion':
        return 'Pendiente verificación';
      case 'suspendido':
        return 'Suspendido';
      case 'bloqueado':
        return 'Bloqueado';
      default:
        return estado ?? '—';
    }
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'activo':
        return ColoresFoody.exito;
      case 'pendiente_verificacion':
        return ColoresFoody.acento;
      case 'suspendido':
      case 'bloqueado':
        return ColoresFoody.error;
      default:
        return Colors.grey;
    }
  }

  Map<String, List<Map<String, dynamic>>> _agruparDocumentos(
    List<Map<String, dynamic>> docs,
  ) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final doc in docs) {
      final id = '${doc['domiciliario_id']}';
      map.putIfAbsent(id, () => []).add(doc);
    }
    return map;
  }

  Future<void> _aprobar(String domiciliarioId, String documentoId) async {
    try {
      await widget.repo.aprobarDocumento(domiciliarioId, documentoId);
      _recargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documento aprobado'),
          backgroundColor: ColoresFoody.exito,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorHttp(e))),
      );
    }
  }

  Future<void> _rechazar(String domiciliarioId, String documentoId) async {
    final motivoCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar documento'),
        content: TextField(
          controller: motivoCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo (mín. 3 caracteres)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, motivoCtrl.text.trim().length >= 3),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    final motivo = motivoCtrl.text.trim();
    motivoCtrl.dispose();
    if (ok != true) return;

    try {
      await widget.repo.rechazarDocumento(domiciliarioId, documentoId, motivo);
      _recargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorHttp(e))),
      );
    }
  }

  void _verImagen(String url, String titulo) {
    FoodyDialogo.mostrar<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            InteractiveViewer(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No se pudo cargar la imagen'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _docsFuture,
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              return TabBar(
                labelColor: ColoresFoody.primario,
                tabs: [
                  const Tab(text: 'Independientes'),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Documentos pendientes'),
                        if (n > 0) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: ColoresFoody.primario,
                            child: Text(
                              '$n',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Expanded(
            child: TabBarView(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: AnaliticaSkeleton.seccion(
                            etiqueta: 'Cargando datos de la plataforma'),
                      );
                    }
                    final lista = snap.data!;
                    if (lista.isEmpty) {
                      return const Center(
                          child: Text('Sin repartidores registrados'));
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _recargar(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lista.length,
                        itemBuilder: (_, i) {
                          final d = lista[i];
                          final estado = d['estado_cuenta'] as String?;
                          return Card(
                            child: ListTile(
                              title: Text(d['nombre'] as String? ?? ''),
                              subtitle: Text(
                                '${d['email']} · ${d['ciudad_nombre'] ?? '—'}\n'
                                'Entregas: ${d['total_entregas'] ?? 0}',
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(
                                  _etiquetaEstado(estado),
                                  style: TextStyle(
                                    color: _colorEstado(estado),
                                    fontSize: 11,
                                  ),
                                ),
                                side: BorderSide(color: _colorEstado(estado)),
                              ),
                              onTap: () async {
                                final est = estado == 'activo'
                                    ? 'suspendido'
                                    : 'activo';
                                final confirmar =
                                    await FoodyDialogo.mostrar<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      est == 'activo'
                                          ? 'Activar cuenta'
                                          : 'Suspender cuenta',
                                    ),
                                    content: Text(
                                      est == 'activo'
                                          ? '¿Activar manualmente a ${d['nombre']}?'
                                          : '¿Suspender a ${d['nombre']}?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Confirmar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmar != true) return;
                                try {
                                  await widget.repo
                                      .domiciliarioEstado('${d['id']}', est);
                                  _recargar();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(mensajeErrorHttp(e))),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _docsFuture,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: AnaliticaSkeleton.seccion(
                            etiqueta: 'Cargando datos de la plataforma'),
                      );
                    }
                    if (snap.data!.isEmpty) {
                      return const Center(
                          child: Text('Sin documentos pendientes'));
                    }
                    final grupos = _agruparDocumentos(snap.data!);
                    return RefreshIndicator(
                      onRefresh: () async => _recargar(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: grupos.entries.map((entry) {
                          final docs = entry.value;
                          final primero = docs.first;
                          final nombre =
                              primero['domiciliario_nombre'] as String? ?? '';
                          final email =
                              primero['domiciliario_email'] as String? ?? '';
                          final telefono =
                              primero['telefono'] as String? ?? '—';
                          final ciudad =
                              primero['ciudad_nombre'] as String? ?? '—';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              title: Text(nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('$email · $ciudad · $telefono'),
                              children: docs.map((doc) {
                                final tipo = doc['tipo'] as String? ?? '';
                                final etiqueta =
                                    tiposDocumentoDomiciliario[tipo] ?? tipo;
                                final url = doc['url'] as String?;
                                final domId = '${doc['domiciliario_id']}';
                                final docId = '${doc['id']}';

                                return ListTile(
                                  title: Text(etiqueta),
                                  subtitle: url != null
                                      ? TextButton(
                                          onPressed: () =>
                                              _verImagen(url, etiqueta),
                                          child: const Text('Ver documento'),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Aprobar',
                                        icon: const Icon(
                                            Icons.check_circle_outline,
                                            color: ColoresFoody.exito),
                                        onPressed: () => _aprobar(domId, docId),
                                      ),
                                      IconButton(
                                        tooltip: 'Rechazar',
                                        icon: Icon(Icons.cancel_outlined,
                                            color: ColoresFoody.error),
                                        onPressed: () =>
                                            _rechazar(domId, docId),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
