import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kanban de pedidos (Sprint 4) — reloj por estado + acciones rápidas.
class PedidosKanbanWidget extends StatefulWidget {
  const PedidosKanbanWidget({super.key, this.sucursalId, this.modoMesero = false});

  final String? sucursalId;
  final bool modoMesero;

  @override
  State<PedidosKanbanWidget> createState() => _PedidosKanbanWidgetState();
}

class _PedidosKanbanWidgetState extends State<PedidosKanbanWidget> {
  final _repo = PedidosRepository();
  final _domRepo = DomiciliariosRepository();
  late Future<List<PedidoAdminModel>> _future;
  List<Map<String, dynamic>> _domiciliarios = [];
  List<String> _permisos = [];
  RealtimeChannel? _canalRealtime;
  Timer? _relojTimer;
  final _busquedaCtrl = TextEditingController();
  String _filtroTipo = 'todos';
  bool _vistaKanban = false;
  final _formatoMoneda =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  static const _umbralRojoMin = 15;

  static const _columnas = [
    ('pendiente_aprobacion', 'Aprobar QR'),
    ('pendiente', 'Pendiente'),
    ('en_cocina', 'En cocina'),
    ('listo', 'Listo'),
    ('pagando', 'Pagando'),
    ('asignado', 'Asignado'),
    ('en_camino', 'En camino'),
    ('entregado', 'Entregado'),
  ];

  static const _columnasMesero = [
    ('pendiente_aprobacion', 'Por confirmar'),
    ('en_cocina', 'Preparando'),
    ('listo', 'Listo para servir'),
    ('pagando', 'Pagando'),
  ];

  List<(String, String)> get _columnasVisibles =>
      widget.modoMesero ? _columnasMesero : _columnas;

  @override
  void initState() {
    super.initState();
    _vistaKanban = widget.modoMesero;
    _future = _repo.listarActivos(sucursalId: widget.sucursalId);
    _cargarDomiciliarios();
    _cargarPermisos();
    _suscribirRealtime();
    _relojTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(PedidosKanbanWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _canalRealtime?.unsubscribe();
      _canalRealtime = null;
      _future = _repo.listarActivos(sucursalId: widget.sucursalId);
      _cargarDomiciliarios();
      _suscribirRealtime();
    }
  }

  @override
  void dispose() {
    _canalRealtime?.unsubscribe();
    _relojTimer?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<PedidoAdminModel> _filtrarPedidos(List<PedidoAdminModel> pedidos) {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    var lista = pedidos.where((p) {
      if (_filtroTipo != 'todos' && p.tipo != _filtroTipo) return false;
      if (q.isEmpty) return true;
      return p.numeroPedido.toLowerCase().contains(q) ||
          p.etiquetaCliente.toLowerCase().contains(q) ||
          (p.mesaNombre?.toLowerCase().contains(q) ?? false) ||
          (p.clienteNombre?.toLowerCase().contains(q) ?? false);
    }).toList();
    lista.sort(
      (a, b) => _minutosEnEstado(b.estadoDesde)
          .compareTo(_minutosEnEstado(a.estadoDesde)),
    );
    return lista;
  }

  Map<String, int> _conteoPorEstado(List<PedidoAdminModel> pedidos) {
    final mapa = <String, int>{};
    for (final p in pedidos) {
      mapa[p.estado] = (mapa[p.estado] ?? 0) + 1;
    }
    return mapa;
  }

  void _suscribirRealtime() {
    final sucursalId = widget.sucursalId;
    if (!AppBackend.supabaseReady || sucursalId == null) return;

    _canalRealtime = FoodyRealtime.suscribirSucursal(
      sucursalId,
      onEvento: (_) => _recargar(),
    );
  }

  void _recargar() {
    setState(() {
      _future = _repo.listarActivos(sucursalId: widget.sucursalId);
    });
    _cargarDomiciliarios();
  }

  Future<void> _cargarPermisos() async {
    final sesion = await SesionStaffService.cargar();
    if (mounted) setState(() => _permisos = sesion?.permisos ?? []);
  }

  Future<void> _cargarDomiciliarios() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final lista = await _domRepo.listarDisponibles(sid);
      if (mounted) setState(() => _domiciliarios = lista);
    } catch (_) {}
  }

  Future<void> _asignarDomiciliario(
    PedidoAdminModel pedido,
    String domiciliarioPlantaId,
  ) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _domRepo.asignar(
        pedidoId: pedido.id,
        sucursalId: sid,
        domiciliarioPlantaId: domiciliarioPlantaId,
      );
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pedido.numeroPedido} asignado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'asignación')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _dispatchIndependiente(PedidoAdminModel pedido) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final res = await _domRepo.dispatchIndependiente(
        pedidoId: pedido.id,
        sucursalId: sid,
      );
      _recargar();
      if (mounted) {
        final msg = res['iniciado'] == true
            ? 'Oferta enviada a ${res['domiciliarios_notificados']} repartidor(es)'
            : '${res['motivo'] ?? 'No se pudo iniciar búsqueda'}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'dispatch')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _moverPedido(
    PedidoAdminModel pedido,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      await _repo.cambiarEstado(
        pedidoId: pedido.id,
        estado: nuevoEstado,
        sucursalId: widget.sucursalId,
        motivo: motivo,
      );
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pedido.numeroPedido} → $nuevoEstado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'cambiar estado')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  Future<void> _accionRapida(PedidoAdminModel pedido) async {
    final accion = pedido.accionRapida;
    if (accion == null) {
      _mostrarAcciones(pedido);
      return;
    }
    if (accion == 'aprobar') {
      await _aprobarMesa(pedido);
      return;
    }
    final estadoDestino = accion == 'aprobar' ? 'en_cocina' : accion;
    await _moverPedido(pedido, estadoDestino);
  }

  Future<void> _aprobarMesa(PedidoAdminModel pedido) async {
    try {
      await _repo.aprobarMesa(pedido.id, sucursalId: widget.sucursalId);
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${pedido.numeroPedido} aprobado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'aprobar pedido QR'))),
        );
      }
    }
  }

  Future<void> _rechazarMesa(PedidoAdminModel pedido, String motivo) async {
    try {
      await _repo.rechazarMesa(
        pedido.id,
        motivo: motivo,
        sucursalId: widget.sucursalId,
      );
      _recargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'rechazar pedido'))),
        );
      }
    }
  }

  void _mostrarAcciones(PedidoAdminModel pedido) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(pedido.numeroPedido),
                subtitle: Text(pedido.etiquetaCliente),
              ),
              if (pedido.estado == 'pendiente_aprobacion') ...[
                ListTile(
                  leading: const Icon(Icons.check, color: Colors.green),
                  title: const Text('Aprobar pedido mesa'),
                  onTap: () {
                    Navigator.pop(context);
                    _aprobarMesa(pedido);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.close, color: ColoresFoody.error),
                  title: const Text('Rechazar con motivo'),
                  onTap: () {
                    Navigator.pop(context);
                    _dialogoRechazar(pedido);
                  },
                ),
              ],
              ListTile(
                leading: Icon(Icons.cancel, color: ColoresFoody.error),
                title: const Text('Cancelar pedido'),
                onTap: () {
                  Navigator.pop(context);
                  _dialogoCancelar(pedido);
                },
              ),
              if (_permisos.contains('aplicar_descuento'))
                ListTile(
                  leading: const Icon(Icons.discount_outlined),
                  title: const Text('Aplicar descuento'),
                  onTap: () {
                    Navigator.pop(context);
                    _dialogoDescuento(pedido);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _dialogoRechazar(PedidoAdminModel pedido) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar pedido'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (obligatorio)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim().isNotEmpty),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok == true && motivoCtrl.text.trim().isNotEmpty) {
      await _rechazarMesa(pedido, motivoCtrl.text.trim());
    }
    motivoCtrl.dispose();
  }

  Future<void> _dialogoCancelar(PedidoAdminModel pedido) async {
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo (obligatorio)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim().isNotEmpty),
            style: FilledButton.styleFrom(backgroundColor: ColoresFoody.error),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (ok == true && motivoCtrl.text.trim().isNotEmpty) {
      await _moverPedido(pedido, 'cancelado', motivo: motivoCtrl.text.trim());
    }
    motivoCtrl.dispose();
  }

  Future<void> _dialogoDescuento(PedidoAdminModel pedido) async {
    final modoPorcentaje = ValueNotifier<bool>(true);
    final valorCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Descuento · ${pedido.numeroPedido}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: modoPorcentaje,
              builder: (_, esPct, __) => SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text('COP')),
                ],
                selected: {esPct},
                onSelectionChanged: (s) => modoPorcentaje.value = s.first,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valorCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: modoPorcentaje.value ? 'Porcentaje' : 'Monto (COP)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(labelText: 'Motivo (obligatorio)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              valorCtrl.text.trim().isNotEmpty &&
                  motivoCtrl.text.trim().isNotEmpty,
            ),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final valor = num.tryParse(valorCtrl.text.trim());
      if (valor != null) {
        try {
          final res = await _repo.aplicarDescuento(
            pedidoId: pedido.id,
            motivo: motivoCtrl.text.trim(),
            sucursalId: widget.sucursalId,
            porcentaje: modoPorcentaje.value ? valor : null,
            monto: modoPorcentaje.value ? null : valor,
          );
          _recargar();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Descuento aplicado · nuevo total ${_formatoMoneda.format(res['total'])}',
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensajeErrorHttp(e, contexto: 'descuento')),
                backgroundColor: ColoresFoody.error,
              ),
            );
          }
        }
      }
    }
    valorCtrl.dispose();
    motivoCtrl.dispose();
    modoPorcentaje.dispose();
  }

  int _minutosEnEstado(DateTime desde) =>
      DateTime.now().difference(desde).inMinutes;

  String _textoReloj(int minutos) {
    if (minutos < 1) return '<1 min';
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return '${h}h ${m}m';
  }

  Color _colorReloj(int minutos) {
    if (minutos >= _umbralRojoMin) return ColoresFoody.error;
    if (minutos >= 8) return ColoresFoody.acento;
    return ColoresFoody.exito;
  }

  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'mesa':
        return Icons.table_restaurant;
      case 'domicilio':
        return Icons.delivery_dining;
      case 'para_llevar':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperacionPageHeader(
          titulo: 'Pedidos',
          subtitulo: widget.modoMesero ? 'Tu turno en salón' : 'Activos en sucursal',
          acciones: [
            if (!widget.modoMesero)
              IconButton(
                tooltip: _vistaKanban ? 'Vista tarjetas' : 'Vista columnas',
                onPressed: () => setState(() => _vistaKanban = !_vistaKanban),
                icon: Icon(_vistaKanban ? Icons.grid_view : Icons.view_column),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _recargar,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<PedidoAdminModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${snapshot.error}'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _recargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              final pedidos = snapshot.data ?? [];
              final filtrados = _filtrarPedidos(pedidos);
              final conteos = _conteoPorEstado(pedidos);
              final totalTurno = pedidos.fold<num>(0, (s, p) => s + p.total);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.modoMesero)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          OperacionStatChip(
                            etiqueta: 'En cocina',
                            valor:
                                '${(conteos['en_cocina'] ?? 0) + (conteos['confirmado'] ?? 0)}',
                            colorPunto: const Color(0xFFEF9F27),
                          ),
                          const SizedBox(width: 8),
                          OperacionStatChip(
                            etiqueta: 'Listos',
                            valor: '${conteos['listo'] ?? 0}',
                            colorPunto: const Color(0xFF639922),
                          ),
                          const SizedBox(width: 8),
                          OperacionStatChip(
                            etiqueta: 'Pagando',
                            valor: '${conteos['pagando'] ?? 0}',
                            colorPunto: const Color(0xFF993556),
                          ),
                          const SizedBox(width: 8),
                          OperacionStatChip(
                            etiqueta: 'Domicilio',
                            valor: '${pedidos.where((p) => p.tipo == 'domicilio').length}',
                            colorPunto: const Color(0xFF534AB7),
                          ),
                          const SizedBox(width: 8),
                          OperacionStatChip(
                            etiqueta: 'Total activos',
                            valor: _formatoMoneda.format(totalTurno),
                            icono: Icons.payments_outlined,
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OperacionBusqueda(
                          controller: _busquedaCtrl,
                          hint: 'Buscar pedido, mesa, cliente…',
                          onChanged: (_) => setState(() {}),
                        ),
                        OperacionPillTabs(
                          opciones: const [
                            ('todos', 'Todos'),
                            ('mesa', 'Mesa'),
                            ('domicilio', 'Domicilio'),
                            ('para_llevar', 'Para llevar'),
                          ],
                          seleccionada: _filtroTipo,
                          onCambio: (v) => setState(() => _filtroTipo = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _recargar(),
                      child: _vistaKanban
                          ? _vistaColumnasKanban(pedidos)
                          : _vistaGridPedidos(filtrados),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _vistaGridPedidos(List<PedidoAdminModel> pedidos) {
    if (pedidos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Sin pedidos con ese filtro')),
        ],
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width >= 1200 ? 3 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: pedidos.length,
      itemBuilder: (_, i) => _TarjetaPedidoOperacion(
        pedido: pedidos[i],
        formatoMoneda: _formatoMoneda,
        minutos: _minutosEnEstado(pedidos[i].estadoDesde),
        textoReloj: _textoReloj,
        colorReloj: _colorReloj,
        iconoTipo: _iconoTipo,
        onTap: () => _mostrarAcciones(pedidos[i]),
        onAccionRapida: () => _accionRapida(pedidos[i]),
        domiciliarios: _domiciliarios,
        onAsignarDomiciliario: _asignarDomiciliario,
        onDispatchIndependiente: _dispatchIndependiente,
      ),
    );
  }

  Widget _vistaColumnasKanban(List<PedidoAdminModel> pedidos) {
    final porEstado = <String, List<PedidoAdminModel>>{};
    for (final col in _columnasVisibles) {
      porEstado[col.$1] = [];
    }
    for (final p in pedidos) {
      final col = p.estadoKanban;
      porEstado.putIfAbsent(col, () => []).add(p);
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        for (final col in _columnasVisibles)
          _ColumnaKanban(
            titulo: col.$2,
            pedidos: porEstado[col.$1] ?? [],
            formatoMoneda: _formatoMoneda,
            minutosEnEstado: _minutosEnEstado,
            textoReloj: _textoReloj,
            colorReloj: _colorReloj,
            iconoTipo: _iconoTipo,
            onTapPedido: _mostrarAcciones,
            onAccionRapida: _accionRapida,
            domiciliarios: _domiciliarios,
            onAsignarDomiciliario: _asignarDomiciliario,
            onDispatchIndependiente: _dispatchIndependiente,
          ),
      ],
    );
  }
}

class _TarjetaPedidoOperacion extends StatelessWidget {
  const _TarjetaPedidoOperacion({
    required this.pedido,
    required this.formatoMoneda,
    required this.minutos,
    required this.textoReloj,
    required this.colorReloj,
    required this.iconoTipo,
    required this.onTap,
    required this.onAccionRapida,
    required this.domiciliarios,
    required this.onAsignarDomiciliario,
    required this.onDispatchIndependiente,
  });

  final PedidoAdminModel pedido;
  final NumberFormat formatoMoneda;
  final int minutos;
  final String Function(int) textoReloj;
  final Color Function(int) colorReloj;
  final IconData Function(String) iconoTipo;
  final VoidCallback onTap;
  final Future<void> Function() onAccionRapida;
  final List<Map<String, dynamic>> domiciliarios;
  final Future<void> Function(PedidoAdminModel, String) onAsignarDomiciliario;
  final Future<void> Function(PedidoAdminModel) onDispatchIndependiente;

  Color? get _bordeUrgencia {
    if (minutos >= 15) return ColoresFoody.error;
    if (minutos >= 8) return const Color(0xFFEF9F27);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorTiempo = colorReloj(minutos);
    return OperacionTarjeta(
      acentoIzquierdo: _bordeUrgencia,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pedido.numeroPedido,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              iconoTipo(pedido.tipo),
                              size: 13,
                              color: OperacionUi.textoTerciario,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                pedido.etiquetaCliente,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: OperacionUi.textoTerciario,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  OperacionStatusChip(estado: pedido.estado),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OperacionUi.fondoPagina,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pedido.tipo == 'domicilio'
                      ? 'Domicilio · ${pedido.etiquetaCliente}'
                      : pedido.tipo == 'mesa'
                          ? 'Mesa ${pedido.mesaNombre ?? '—'}'
                          : 'Para llevar',
                  style: const TextStyle(
                    fontSize: 12,
                    color: OperacionUi.textoSecundario,
                    height: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: colorTiempo),
                  const SizedBox(width: 4),
                  Text(
                    textoReloj(minutos),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorTiempo,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatoMoneda.format(pedido.total),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (pedido.accionRapida != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onAccionRapida,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresFoody.primario,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      '${pedido.etiquetaAccionRapida} →',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              if (pedido.estado == 'listo' && pedido.tipo == 'domicilio')
                _AsignarDomiciliario(
                  pedido: pedido,
                  domiciliarios: domiciliarios,
                  onAsignar: onAsignarDomiciliario,
                  onDispatchIndependiente: onDispatchIndependiente,
                ),
        ],
      ),
    );
  }
}

class _ColumnaKanban extends StatelessWidget {
  const _ColumnaKanban({
    required this.titulo,
    required this.pedidos,
    required this.formatoMoneda,
    required this.minutosEnEstado,
    required this.textoReloj,
    required this.colorReloj,
    required this.iconoTipo,
    required this.onTapPedido,
    required this.onAccionRapida,
    required this.domiciliarios,
    required this.onAsignarDomiciliario,
    required this.onDispatchIndependiente,
  });

  final String titulo;
  final List<PedidoAdminModel> pedidos;
  final NumberFormat formatoMoneda;
  final int Function(DateTime) minutosEnEstado;
  final String Function(int) textoReloj;
  final Color Function(int) colorReloj;
  final IconData Function(String) iconoTipo;
  final void Function(PedidoAdminModel) onTapPedido;
  final Future<void> Function(PedidoAdminModel) onAccionRapida;
  final List<Map<String, dynamic>> domiciliarios;
  final Future<void> Function(PedidoAdminModel, String) onAsignarDomiciliario;
  final Future<void> Function(PedidoAdminModel) onDispatchIndependiente;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 12, bottom: 16),
      decoration: BoxDecoration(
        color: ColoresFoody.fondo,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                CircleAvatar(
                  radius: 14,
                  backgroundColor: ColoresFoody.primario,
                  child: Text(
                    '${pedidos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: pedidos.isEmpty
                ? const Center(
                    child: Text('—', style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) {
                      final p = pedidos[index];
                      final mins = minutosEnEstado(p.estadoDesde);
                      final color = colorReloj(mins);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => onTapPedido(p),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(iconoTipo(p.tipo), size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.numeroPedido,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(p.etiquetaCliente),
                                if (p.domiciliarioNombre != null &&
                                    p.domiciliarioNombre!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.two_wheeler, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            p.domiciliarioNombre!,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined,
                                        size: 16, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      textoReloj(mins),
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(formatoMoneda.format(p.total)),
                                  ],
                                ),
                                if (p.accionRapida != null) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.tonal(
                                      onPressed: () => onAccionRapida(p),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: ColoresFoody.primario
                                            .withValues(alpha: 0.15),
                                        foregroundColor: ColoresFoody.primario,
                                      ),
                                      child: Text(p.etiquetaAccionRapida),
                                    ),
                                  ),
                                ],
                                if (p.estado == 'listo' && p.tipo == 'domicilio')
                                  _AsignarDomiciliario(
                                    pedido: p,
                                    domiciliarios: domiciliarios,
                                    onAsignar: onAsignarDomiciliario,
                                    onDispatchIndependiente: onDispatchIndependiente,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AsignarDomiciliario extends StatefulWidget {
  const _AsignarDomiciliario({
    required this.pedido,
    required this.domiciliarios,
    required this.onAsignar,
    required this.onDispatchIndependiente,
  });

  final PedidoAdminModel pedido;
  final List<Map<String, dynamic>> domiciliarios;
  final Future<void> Function(PedidoAdminModel, String) onAsignar;
  final Future<void> Function(PedidoAdminModel) onDispatchIndependiente;

  @override
  State<_AsignarDomiciliario> createState() => _AsignarDomiciliarioState();
}

class _AsignarDomiciliarioState extends State<_AsignarDomiciliario> {
  String? _seleccion;

  @override
  Widget build(BuildContext context) {
    final libres = widget.domiciliarios
        .where((d) => d['ocupado'] != true)
        .toList();

    if (libres.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sin domiciliarios de planta libres',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: () => widget.onDispatchIndependiente(widget.pedido),
              icon: const Icon(Icons.radar, size: 18),
              label: const Text('Buscar independiente'),
            ),
          ],
        ),
      );
    }

    _seleccion ??= libres.first['id'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _seleccion,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Domiciliario',
              isDense: true,
            ),
            items: libres
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(d['nombre'] as String? ?? '—'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _seleccion = v),
          ),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _seleccion == null
                ? null
                : () => widget.onAsignar(widget.pedido, _seleccion!),
            child: const Text('Asignar'),
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => widget.onDispatchIndependiente(widget.pedido),
            icon: const Icon(Icons.radar, size: 18),
            label: const Text('Buscar independiente'),
          ),
        ],
      ),
    );
  }
}
