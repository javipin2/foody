import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

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
      final traslados =
          await _repo.listarTraslados(sucursalId: widget.sucursalId);
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
          content:
              Text('Necesitas otra sucursal del restaurante para traslados'),
        ),
      );
      return;
    }

    String? destinoId =
        widget.sucursalesHermanas.first['sucursal_id'] as String?;
    String? ingredienteId =
        _ingredientes.isNotEmpty ? _ingredientes.first['id'] as String? : null;
    final cantidadCtrl = TextEditingController(text: '1');
    final motivoCtrl = TextEditingController();

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => FoodyDialogoShell(
          titulo: 'Nuevo traslado',
          subtitulo: 'Envía existencias a otra sede del restaurante.',
          contenido: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: destinoId,
                decoration: FoodyFormEstilo.campo(
                  label: 'Sucursal destino',
                  prefixIcon: const Icon(Icons.store_outlined),
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
                initialValue: ingredienteId,
                decoration: FoodyFormEstilo.campo(
                  label: 'Insumo',
                  prefixIcon: const Icon(Icons.inventory_2_outlined),
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
                decoration: FoodyFormEstilo.campo(
                  label: 'Cantidad',
                  prefixIcon: const Icon(Icons.scale_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                decoration: FoodyFormEstilo.campo(
                  label: 'Motivo (opcional)',
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
              ),
            ],
          ),
          acciones: [
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
          SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'recibir traslado'))),
        );
      }
    }
  }

  Future<void> _cancelar(String id) async {
    final ok = await FoodyDialogo.mostrar<bool>(
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
          SnackBar(
              content:
                  Text(mensajeErrorHttp(e, contexto: 'cancelar traslado'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compacto =
        FoodyBreakpoints.esCompact(FoodyBreakpoints.widthOf(context));
    if (!widget.habilitado) {
      final mensaje = !widget.tienePermisoHermanas
          ? 'No tienes permiso para ver inventario de otras sedes. '
              'Sin ese permiso no puedes crear traslados entre sucursales.'
          : 'No hay otras sucursales activas en tu restaurante. '
              'Cuando exista otra sede, podrás solicitar o enviar insumos desde aquí.';
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _EstadoTraslado(
              icono: Icons.swap_horiz_rounded,
              titulo: widget.tienePermisoHermanas
                  ? 'Sin otras sedes'
                  : 'Acceso restringido',
              mensaje: mensaje,
            ),
          ),
        ),
      );
    }
    if (_cargando) {
      return Center(
          child: CircularProgressIndicator(color: AnaliticaTokens.ventas));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _EstadoTraslado(
            icono: Icons.cloud_off_outlined,
            titulo: 'No se pudieron cargar los traslados',
            mensaje: _error!,
            accion: FilledButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        ),
      );
    }

    final fecha = DateFormat('dd/MM HH:mm');

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 20, 12, compacto ? 12 : 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Traslados entre sedes',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (!compacto)
                      Text('Seguimiento de envíos y recepciones de inventario',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: AnaliticaTokens.inkMutedOf(context))),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar traslados',
                onPressed: _cargar,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (compacto)
                FilledButton.icon(
                  onPressed: _nuevoTraslado,
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Nuevo'),
                )
              else
                FilledButton.icon(
                  onPressed: _nuevoTraslado,
                  icon: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Nuevo traslado'),
                ),
            ],
          ),
        ),
        Expanded(
          child: _traslados.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _EstadoTraslado(
                      icono: Icons.inventory_2_outlined,
                      titulo: 'Aún no hay traslados',
                      mensaje:
                          'Cuando envíes insumos a otra sede, aquí podrás revisar su estado.',
                      accion: FilledButton.icon(
                        onPressed: _nuevoTraslado,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear traslado'),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                        compacto ? 12 : 20, 8, compacto ? 12 : 20, 24),
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
                      final colorEstado = estado == 'pendiente'
                          ? AnaliticaTokens.alertas
                          : estado == 'recibido'
                              ? ColoresFoody.exito
                              : AnaliticaTokens.inkMutedOf(context);
                      final created =
                          DateTime.tryParse('${t['created_at']}')?.toLocal();
                      final detalle = [
                        '${t['sucursal_origen']} → ${t['sucursal_destino']}',
                        if (created != null) fecha.format(created),
                        if (usuario != null && usuario.isNotEmpty) usuario,
                      ].join(' · ');
                      return Container(
                        padding: EdgeInsets.all(compacto ? 14 : 16),
                        decoration: BoxDecoration(
                          color: AnaliticaTokens.surfaceOf(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AnaliticaTokens.borderOf(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                      color: AnaliticaTokens.ventas
                                          .withValues(alpha: .10),
                                      borderRadius: BorderRadius.circular(11)),
                                  child: Icon(Icons.inventory_2_outlined,
                                      color: AnaliticaTokens.ventas, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          '${t['ingrediente_nombre'] ?? 'Insumo'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(
                                          '${t['cantidad']} ${t['unidad_base'] ?? ''}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  color: AnaliticaTokens
                                                      .inkMutedOf(context))),
                                    ])),
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                        color:
                                            colorEstado.withValues(alpha: .12),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(estado,
                                        style: TextStyle(
                                            color: colorEstado,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(detalle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: AnaliticaTokens.inkMutedOf(
                                            context))),
                            if (estado == 'pendiente') ...[
                              const SizedBox(height: 12),
                              Align(
                                  alignment: Alignment.centerRight,
                                  child: trailing),
                            ],
                          ],
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

class _EstadoTraslado extends StatelessWidget {
  const _EstadoTraslado(
      {required this.icono,
      required this.titulo,
      required this.mensaje,
      this.accion});
  final IconData icono;
  final String titulo;
  final String mensaje;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 34, color: AnaliticaTokens.inkMutedOf(context)),
          const SizedBox(height: 12),
          Text(titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AnaliticaTokens.inkMutedOf(context))),
          if (accion != null) ...[const SizedBox(height: 16), accion!],
        ],
      );
}
