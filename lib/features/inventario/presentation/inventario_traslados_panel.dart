import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';

/// Panel traslados entre sedes (INV-010).
class InventarioTrasladosPanel extends StatefulWidget {
  const InventarioTrasladosPanel({
    super.key,
    required this.sucursalId,
    this.sucursalesHermanas = const [],
    this.habilitado = true,
    this.tienePermisoHermanas = true,
  });

  final String sucursalId;
  final List<Map<String, dynamic>> sucursalesHermanas;
  final bool habilitado;
  /// NAV-MG-05: distingue «sin permiso» vs «sin otras sedes».
  final bool tienePermisoHermanas;

  @override
  State<InventarioTrasladosPanel> createState() =>
      _InventarioTrasladosPanelState();
}

class _InventarioTrasladosPanelState extends State<InventarioTrasladosPanel> {
  final _repo = InventarioRepository();
  List<Map<String, dynamic>> _traslados = [];
  List<Map<String, dynamic>> _ingredientes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final traslados = await _repo.listarTraslados(sucursalId: widget.sucursalId);
      final ingredientes = await _repo.ingredientes(widget.sucursalId);
      if (mounted) {
        setState(() {
          _traslados = traslados;
          _ingredientes = ingredientes;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'traslados');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _nuevoTraslado() async {
    if (widget.sucursalesHermanas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitas otra sucursal del restaurante para traslados'),
        ),
      );
      return;
    }

    String? destinoId = widget.sucursalesHermanas.first['sucursal_id'] as String?;
    String? ingredienteId =
        _ingredientes.isNotEmpty ? _ingredientes.first['id'] as String? : null;
    final cantidadCtrl = TextEditingController(text: '1');
    final motivoCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Nuevo traslado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: destinoId,
                  decoration: const InputDecoration(
                    labelText: 'Sucursal destino',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.sucursalesHermanas
                      .where((s) => s['sucursal_id'] != widget.sucursalId)
                      .map(
                        (s) => DropdownMenuItem(
                          value: s['sucursal_id'] as String,
                          child: Text(s['nombre'] as String? ?? 'Sede'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => destinoId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: ingredienteId,
                  decoration: const InputDecoration(
                    labelText: 'Insumo',
                    border: OutlineInputBorder(),
                  ),
                  items: _ingredientes
                      .map(
                        (i) => DropdownMenuItem(
                          value: i['id'] as String,
                          child: Text(i['nombre'] as String? ?? '—'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialog(() => ingredienteId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cantidadCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || destinoId == null || ingredienteId == null) {
      cantidadCtrl.dispose();
      motivoCtrl.dispose();
      return;
    }

    try {
      await _repo.crearTraslado(
        sucursalOrigenId: widget.sucursalId,
        sucursalDestinoId: destinoId!,
        ingredienteId: ingredienteId!,
        cantidad: double.tryParse(cantidadCtrl.text.replaceAll(',', '.')) ?? 0,
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      cantidadCtrl.dispose();
      motivoCtrl.dispose();
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traslado registrado'),
            backgroundColor: ColoresFoody.exito,
          ),
        );
      }
    } catch (e) {
      cantidadCtrl.dispose();
      motivoCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'traslado'))),
        );
      }
    }
  }

  Future<void> _recibir(String id) async {
    try {
      await _repo.recibirTraslado(id);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traslado recibido en inventario'),
            backgroundColor: ColoresFoody.exito,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'recibir traslado'))),
        );
      }
    }
  }

  Future<void> _cancelar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar traslado'),
        content: const Text(
          'Se devolverá el stock a la sucursal de origen. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancelarTraslado(id);
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Traslado cancelado'),
            backgroundColor: ColoresFoody.exito,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cancelar traslado'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.habilitado) {
      final mensaje = !widget.tienePermisoHermanas
          ? 'No tienes permiso para ver inventario de otras sedes. '
              'Sin ese permiso no puedes crear traslados entre sucursales.'
          : 'No hay otras sucursales activas en tu restaurante. '
              'Cuando exista otra sede, podrás solicitar o enviar insumos desde aquí.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            mensaje,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final fecha = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Traslados entre sedes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton.icon(
                onPressed: _nuevoTraslado,
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Nuevo'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _traslados.isEmpty
              ? const Center(child: Text('Sin traslados registrados'))
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _traslados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = _traslados[i];
                      final estado = t['estado'] as String? ?? 'pendiente';
                      final usuario = t['usuario_nombre'] as String?;
                      final esDestino =
                          t['sucursal_destino_id'] == widget.sucursalId;
                      final esOrigen =
                          t['sucursal_origen_id'] == widget.sucursalId;
                      Widget? trailing;
                      if (estado == 'pendiente' && esDestino) {
                        trailing = FilledButton(
                          onPressed: () => _recibir('${t['id']}'),
                          child: const Text('Recibir'),
                        );
                      } else if (estado == 'pendiente' && esOrigen) {
                        trailing = TextButton(
                          onPressed: () => _cancelar('${t['id']}'),
                          child: const Text('Cancelar'),
                        );
                      } else {
                        trailing = Chip(label: Text(estado));
                      }
                      return Card(
                        child: ListTile(
                          title: Text(
                            '${t['ingrediente_nombre']} · ${t['cantidad']} ${t['unidad_base'] ?? ''}',
                          ),
                          subtitle: Text(
                            '${t['sucursal_origen']} → ${t['sucursal_destino']}\n'
                            '${fecha.format(DateTime.parse('${t['created_at']}').toLocal())} · $estado'
                            '${usuario != null ? ' · $usuario' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: trailing,
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
