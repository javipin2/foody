import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/manejo_error_sesion.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/domain/pedido_admin_model.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/admin/providers/operacion_sucursal_provider.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_columnas_por_canal.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_detalle_sheet.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/asignar_domiciliario_slot.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/asignar_mesero_sheet.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_kanban_card.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_kanban_column.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Kanban de pedidos — columnas por canal, cards ricas, modal detalle.
class PedidosKanbanWidget extends ConsumerStatefulWidget {
  const PedidosKanbanWidget({
    super.key,
    this.sucursalId,
    this.modoMesero = false,
    this.meseraUsuarioId,
    this.pedidoIdInicial,
    this.onPedidoAbierto,
    this.onVerMesa,
    this.onIrCaja,
    this.onIrFacturacion,
    this.onIrCocinaKds,
    this.onNuevoPedido,
    this.onAgregarItems,
    this.ocultarCabecera = false,
  });

  final String? sucursalId;
  final bool modoMesero;
  final String? meseraUsuarioId;
  final String? pedidoIdInicial;
  final VoidCallback? onPedidoAbierto;
  final ValueChanged<String>? onVerMesa;
  final VoidCallback? onIrCaja;
  final void Function(String pedidoId, String numeroPedido)? onIrFacturacion;
  final VoidCallback? onIrCocinaKds;
  final VoidCallback? onNuevoPedido;
  /// Abrir POS para sumar ítems a un pedido existente (o reemplazar uno).
  final void Function(PedidoAdminModel pedido, {String? itemIdReemplazar})?
      onAgregarItems;
  final bool ocultarCabecera;

  @override
  ConsumerState<PedidosKanbanWidget> createState() =>
      _PedidosKanbanWidgetState();
}

class _PedidosKanbanWidgetState extends ConsumerState<PedidosKanbanWidget>
    with WidgetsBindingObserver {
  final _repo = PedidosRepository();
  final _domRepo = DomiciliariosRepository();
  late Future<List<PedidoAdminModel>> _future;
  List<PedidoAdminModel> _cerradosHoy = [];
  bool _cargandoCerrados = false;
  bool _cargandoMasCerrados = false;
  int _pageCerrados = 1;
  bool _hayMasCerrados = false;
  int _totalCerrados = 0;
  List<Map<String, dynamic>> _domiciliarios = [];
  List<String> _permisos = [];
  String _rolSesion = '';
  RealtimeChannel? _canalRealtime;
  Timer? _relojTimer;
  PollRealtimeRespaldo? _pollRespaldo;
  final _busquedaCtrl = TextEditingController();
  String _filtroTipo = 'todos';
  /// Pestaña de estado activa (clave de PedidoColumnaDef o cerrados_hoy).
  String _tabClave = 'pendiente';
  /// Opcional: columnas kanban (off por defecto — tabs + grid).
  bool _vistaKanban = false;
  bool _cobrando = false;
  final _formatoMoneda =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  static const _umbralRojoMin = 15;

  List<PedidoColumnaDef> get _tabsEstado =>
      PedidoColumnasPorCanal.tabsConCerrados(
        filtroTipo: _filtroTipo,
        modoMesero: widget.modoMesero,
      );

  List<PedidoColumnaDef> get _columnasVisibles => PedidoColumnasPorCanal.para(
        filtroTipo: _filtroTipo,
        modoMesero: widget.modoMesero,
      );

  void _asegurarTabValida() {
    final tabs = _tabsEstado;
    if (tabs.every((t) => t.clave != _tabClave)) {
      _tabClave = tabs.first.clave;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vistaKanban = false;
    if (widget.modoMesero) {
      _filtroTipo = 'mesa';
      _tabClave = 'pendiente_aprobacion';
    }
    _future = _repo.listarActivos(
      sucursalId: widget.sucursalId,
      meseraId: widget.modoMesero ? widget.meseraUsuarioId : null,
    );
    unawaited(_cargarPermisosYDomiciliarios());
    _suscribirRealtime();
    unawaited(_cargarCerradosHoy());
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) _recargar();
    });
    unawaited(_pollRespaldo!.iniciar());
    _relojTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_abrirPedidoInicialSiHay());
    });
  }

  Future<void> _abrirPedidoInicialSiHay() async {
    final id = widget.pedidoIdInicial;
    if (id == null || id.isEmpty) return;
    try {
      final lista = await _future;
      PedidoAdminModel? encontrado;
      for (final p in lista) {
        if (p.id == id) {
          encontrado = p;
          break;
        }
      }
      if (encontrado != null && mounted) {
        widget.onPedidoAbierto?.call();
        _mostrarAcciones(encontrado);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(PedidosKanbanWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      FoodyRealtime.liberarCanal(_canalRealtime);
      _canalRealtime = null;
      _future = _repo.listarActivos(
        sucursalId: widget.sucursalId,
        meseraId: widget.modoMesero ? widget.meseraUsuarioId : null,
      );
      _cargarDomiciliarios();
      _suscribirRealtime();
    }
    if (widget.pedidoIdInicial != null &&
        widget.pedidoIdInicial!.isNotEmpty &&
        widget.pedidoIdInicial != oldWidget.pedidoIdInicial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_abrirPedidoInicialSiHay());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _recargar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FoodyRealtime.liberarCanal(_canalRealtime);
    _pollRespaldo?.detener();
    _relojTimer?.cancel();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  List<PedidoAdminModel> _filtrarPedidos(
    List<PedidoAdminModel> pedidos, {
    bool ignorarTab = false,
  }) {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    final tabCerrados =
        !ignorarTab && _tabClave == PedidoColumnasPorCanal.cerradosClave;
    final cols = _columnasVisibles;

    var lista = tabCerrados
        ? List<PedidoAdminModel>.from(_cerradosHoy)
        : List<PedidoAdminModel>.from(pedidos);

    lista = lista.where((p) {
      if (_filtroTipo != 'todos' && p.tipo != _filtroTipo) return false;
      if (!tabCerrados && !ignorarTab) {
        final clave = PedidoColumnasPorCanal.claveColumna(p.estadoKanban, cols);
        if (clave != _tabClave) return false;
      }
      if (q.isEmpty) return true;
      return p.numeroPedido.toLowerCase().contains(q) ||
          p.etiquetaCliente.toLowerCase().contains(q) ||
          (p.mesaNombre?.toLowerCase().contains(q) ?? false) ||
          (p.clienteNombre?.toLowerCase().contains(q) ?? false) ||
          (p.domiciliarioNombre?.toLowerCase().contains(q) ?? false);
    }).toList();
    lista.sort(
      (a, b) => _minutosEnEstado(b.estadoDesde)
          .compareTo(_minutosEnEstado(a.estadoDesde)),
    );
    return lista;
  }

  int _conteoTab(PedidoColumnaDef tab, List<PedidoAdminModel> activos) {
    if (tab.clave == PedidoColumnasPorCanal.cerradosClave) {
      return _cerradosHoy
          .where((p) => _filtroTipo == 'todos' || p.tipo == _filtroTipo)
          .length;
    }
    return activos.where((p) {
      if (_filtroTipo != 'todos' && p.tipo != _filtroTipo) return false;
      return PedidoColumnasPorCanal.claveColumna(
            p.estadoKanban,
            _columnasVisibles,
          ) ==
          tab.clave;
    }).length;
  }

  void _suscribirRealtime() {
    final sucursalId = widget.sucursalId;
    if (!AppBackend.supabaseReady || sucursalId == null) return;

    _canalRealtime = FoodyRealtime.suscribirSucursal(
      sucursalId,
      onEvento: (_) => _recargar(),
      onReconectado: _recargar,
    );
  }

  void _recargar() {
    setState(() {
      _future = _repo.listarActivos(
        sucursalId: widget.sucursalId,
        meseraId: widget.modoMesero ? widget.meseraUsuarioId : null,
      );
    });
    _cargarDomiciliarios();
    unawaited(_cargarCerradosHoy());
  }

  Future<void> _cargarCerradosHoy({bool mas = false}) async {
    if (mas) {
      if (_cargandoMasCerrados || !_hayMasCerrados) return;
      setState(() => _cargandoMasCerrados = true);
    } else {
      if (_cargandoCerrados) return;
      setState(() {
        _cargandoCerrados = true;
        _pageCerrados = 1;
      });
    }
    try {
      final page = mas ? _pageCerrados + 1 : 1;
      final res = await _repo.listarCerradosHoy(
        sucursalId: widget.sucursalId,
        meseraId: widget.modoMesero ? widget.meseraUsuarioId : null,
        page: page,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          if (mas) {
            _cerradosHoy = [..._cerradosHoy, ...res.items];
            _pageCerrados = page;
            _cargandoMasCerrados = false;
          } else {
            _cerradosHoy = res.items;
            _pageCerrados = 1;
            _cargandoCerrados = false;
          }
          _hayMasCerrados = res.hayMas;
          _totalCerrados = res.total;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargandoCerrados = false;
          _cargandoMasCerrados = false;
        });
      }
    }
  }

  Future<void> _cargarPermisos() async {
    final sesion = await SesionStaffService.cargar();
    if (mounted) {
      setState(() {
        _permisos = sesion?.permisos ?? [];
        _rolSesion = sesion?.rol ?? '';
      });
    }
  }

  Future<void> _cargarPermisosYDomiciliarios() async {
    await _cargarPermisos();
    await _cargarDomiciliarios();
  }

  Future<void> _cargarDomiciliarios() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    if (!_permisos.contains('gestionar_domiciliarios')) {
      if (mounted) setState(() => _domiciliarios = []);
      return;
    }
    try {
      final lista = await _domRepo.listarDisponibles(sid);
      if (mounted) setState(() => _domiciliarios = lista);
    } catch (_) {}
  }

  Future<void> _asignarDomiciliario(
    PedidoAdminModel pedido,
    String domiciliarioPlantaId, {
    bool reasignar = false,
  }) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      if (reasignar) {
        await _domRepo.reasignar(
          pedidoId: pedido.id,
          sucursalId: sid,
          domiciliarioPlantaId: domiciliarioPlantaId,
        );
      } else {
        await _domRepo.asignar(
          pedidoId: pedido.id,
          sucursalId: sid,
          domiciliarioPlantaId: domiciliarioPlantaId,
        );
      }
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reasignar
                  ? '${pedido.numeroPedido} reasignado'
                  : '${pedido.numeroPedido} asignado',
            ),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mensajeDispatch(res))),
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

  String _mensajeDispatch(Map<String, dynamic> res) {
    if (res['iniciado'] == true) {
      final n = res['domiciliarios_notificados'];
      final seg = res['expira_en_seg'] ?? 60;
      final radio = res['radio_km'];
      final intento = res['intento'];
      final radioTxt = radio != null ? ' · radio $radio km' : '';
      final intentoTxt = intento != null ? ' (intento $intento)' : '';
      return 'Oferta enviada a $n repartidor(es)$intentoTxt$radioTxt. '
          'Tienen $seg s para aceptar.';
    }
    final mensajeApi = res['mensaje'] as String?;
    if (mensajeApi != null && mensajeApi.trim().isNotEmpty) {
      return mensajeApi.trim();
    }
    switch (res['motivo'] as String?) {
      case 'DOMICILIARIO_NO_DISPONIBLE':
        final radio = res['radio_km'];
        final intento = res['intento'];
        return 'No hay repartidores independientes conectados'
            '${radio != null ? ' en $radio km' : ''}'
            '${intento != null ? ' (intento $intento)' : ''}. '
            'Deben abrir la app repartidor, iniciar turno y estar en la misma ciudad.';
      case 'oferta_activa':
        return 'Ya hay una oferta activa para este pedido. Espera a que expire o a que alguien acepte.';
      case 'max_intentos':
        return 'Se agotaron los intentos de búsqueda. Vuelve a intentar más tarde.';
      default:
        return res['motivo']?.toString() ?? 'No se pudo iniciar la búsqueda';
    }
  }

  Future<void> _moverPedido(
    PedidoAdminModel pedido,
    String nuevoEstado, {
    String? motivo,
  }) async {
    try {
      final datos = await _repo.cambiarEstado(
        pedidoId: pedido.id,
        estado: nuevoEstado,
        sucursalId: widget.sucursalId,
        motivo: motivo,
      );
      _recargar();
      if (mounted) {
        var mensaje = '${pedido.numeroPedido} â†’ $nuevoEstado';
        if (nuevoEstado == 'cancelado' || nuevoEstado == 'rechazado') {
          final caja = datos?['caja'];
          if (caja is Map) {
            final devolucion = (caja['devolucion_automatica'] as num?)?.toDouble() ?? 0;
            if (devolucion > 0) {
              mensaje +=
                  '\nSe revirtieron ${_formatoMoneda.format(devolucion)} en caja.';
            } else {
              mensaje +=
                  '\nSin devolución en caja (el pedido no estaba cobrado).';
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje)),
        );
        if (widget.modoMesero && nuevoEstado == 'pagando') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cuenta presentada — avisa al cajero para cobrar',
              ),
            ),
          );
        }
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
    await _moverPedido(pedido, accion);
  }

  Future<void> _aprobarMesa(PedidoAdminModel pedido) async {
    final sid = widget.sucursalId;
    String? meseraId;
    if (_rolSesion != 'mesero' && !widget.modoMesero) {
      if (sid == null) return;
      final elegida = await mostrarAsignarMeseroSheet(
        context: context,
        pedido: pedido,
        sucursalId: sid,
        meseraPreseleccionadaId: pedido.meseraId ?? pedido.meseraMesaId,
      );
      if (elegida == null) return;
      meseraId = elegida;
    }
    try {
      await _repo.aprobarMesa(
        pedido.id,
        sucursalId: sid,
        meseraId: meseraId,
      );
      _recargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${pedido.numeroPedido} confirmado · a cocina'),
            backgroundColor: ColoresFoody.secundario,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'confirmar pedido QR')),
          ),
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
    mostrarPedidoDetalleSheet(
      context: context,
      pedidoInicial: pedido,
      sucursalId: widget.sucursalId,
      modoMesero: widget.modoMesero,
      permisos: _permisos,
      formatoMoneda: _formatoMoneda,
      onCambiado: _recargar,
      onVerMesa: widget.onVerMesa,
      onIrCaja: widget.onIrCaja,
      onIrFacturacion: widget.onIrFacturacion,
      onIrCocinaKds: widget.onIrCocinaKds,
      onAgregarItems: widget.onAgregarItems,
      onCobrarParaLlevar:
          _permisos.contains('cobrar_pedido') ? _cobrarParaLlevar : null,
      onAprobar: _aprobarMesa,
      onRechazar: (p) async => _dialogoRechazar(p),
      onCambiarEstado: (p, estado) => _moverPedido(p, estado),
      onCancelar: (p) async => _dialogoCancelar(p),
      onDescuento: (p) async => _dialogoDescuento(p),
      asignarDomiciliarioSlot: _puedeGestionarDomi(pedido)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AsignarDomiciliarioSlot(
                pedido: pedido,
                domiciliarios: _domiciliarios,
                reasignar: _esReasignacionDomi(pedido),
                onAsignar: _asignarDomiciliario,
                onDispatchIndependiente: _dispatchIndependiente,
              ),
            )
          : null,
    );
  }

  bool _puedeGestionarDomi(PedidoAdminModel pedido) {
    if (!_permisos.contains('gestionar_domiciliarios')) return false;
    if (pedido.tipo != 'domicilio') return false;
    return pedido.estado == 'listo' ||
        pedido.estado == 'asignado' ||
        pedido.estado == 'en_camino';
  }

  bool _esReasignacionDomi(PedidoAdminModel pedido) =>
      pedido.estado == 'asignado' || pedido.estado == 'en_camino';

  Future<void> _cobrarParaLlevar(PedidoAdminModel pedido) async {
    if (_cobrando) return;
    final propinaCtrl = TextEditingController(text: '0');
    final metodo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cobrar ${pedido.numeroPedido}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Saldo ${_formatoMoneda.format(pedido.saldoPendiente)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: propinaCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Propina (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'efectivo'),
            child: const Text('Efectivo'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, 'transferencia'),
            child: const Text('Transfer.'),
          ),
        ],
      ),
    );
    final propina = double.tryParse(propinaCtrl.text.replaceAll(',', ''));
    propinaCtrl.dispose();
    if (metodo == null) return;
    setState(() => _cobrando = true);
    final clave = const Uuid().v4();
    try {
      await _repo.cobrarPedidoCaja(
        pedidoId: pedido.id,
        sucursalId: widget.sucursalId,
        metodoPago: metodo,
        propina: (propina != null && propina > 0) ? propina : null,
        idempotencyKey: clave,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cobrado · ${pedido.numeroPedido}'),
            backgroundColor: ColoresFoody.secundario,
          ),
        );
      }
      _recargar();
    } catch (e) {
      if (codigoErrorApi(e) == 'COCINA_INCOMPLETA_PARA_PAGADO' && mounted) {
        final sesion = await SesionStaffService.cargar();
        final rol = sesion?.rol ?? '';
        final puede =
            rol == 'admin' || rol == 'gerente' || rol == 'gerente_cadena';
        if (puede) {
          final motivoCtrl = TextEditingController();
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cocina incompleta'),
              content: TextField(
                controller: motivoCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Motivo para forzar cobro',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Forzar'),
                ),
              ],
            ),
          );
          final motivo = motivoCtrl.text.trim();
          motivoCtrl.dispose();
          if (ok == true && motivo.isNotEmpty) {
            try {
              await _repo.cobrarPedidoCaja(
                pedidoId: pedido.id,
                sucursalId: widget.sucursalId,
                metodoPago: metodo,
                propina: (propina != null && propina > 0) ? propina : null,
                idempotencyKey: const Uuid().v4(),
                motivo: motivo,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cobrado (forzado) · ${pedido.numeroPedido}'),
                    backgroundColor: ColoresFoody.secundario,
                  ),
                );
              }
              _recargar();
              return;
            } catch (e2) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      mensajeErrorHttp(e2, contexto: 'forzar cobro'),
                    ),
                  ),
                );
              }
              return;
            }
          }
        }
      }
      // INFRA-EXT-TO: tras timeout, verificar si ya quedó pagado
      final recuperado = await _verificarCobroTrasTimeout(pedido.id, e);
      if (recuperado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cobro confirmado · ${pedido.numeroPedido}'),
              backgroundColor: ColoresFoody.secundario,
            ),
          );
        }
        _recargar();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cobrar pedido'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cobrando = false);
    }
  }

  Future<bool> _verificarCobroTrasTimeout(String pedidoId, Object e) async {
    final msg = e.toString().toLowerCase();
    final esTimeout = msg.contains('timeout') ||
        msg.contains('timed out') ||
        msg.contains('receive timeout') ||
        msg.contains('connection timeout');
    if (!esTimeout) return false;
    try {
      final det = await _repo.obtenerDetalle(
        pedidoId: pedidoId,
        sucursalId: widget.sucursalId,
      );
      return det.estado == 'pagado';
    } catch (_) {
      return false;
    }
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (obligatorio)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text(
              'Si el pedido no estaba cobrado, no registres devolución en Caja. '
              'Al cancelar, el sistema solo devuelve efectivo cuando ya hubo cobro.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
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
    if (minutos >= _umbralRojoMin) return AnaliticaTokens.alertas;
    if (minutos >= 8) return const Color(0xFFD97706);
    return AnaliticaTokens.inventario;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      operacionSucursalProvider.select((s) => s.epochPedidos),
      (prev, next) {
        if (prev != null && prev != next && mounted) _recargar();
      },
    );
    final ancho = MediaQuery.sizeOf(context).width;
    // NAV-ADM2-03 / NAV-MS-15: móvil = lista; anchos ≥720 respetan preferencia.
    final usarKanban = ancho < 720 ? false : _vistaKanban;
    final mostrarToggleVista = FoodyBreakpoints.esExpanded(ancho);

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.ocultarCabecera)
            OperacionPageHeader(
              titulo: 'Pedidos',
              subtitulo: widget.modoMesero
                  ? 'Tu turno en salón'
                  : 'Operación en vivo',
              acciones: [
                if (!widget.modoMesero && widget.onNuevoPedido != null)
                  FilledButton.icon(
                    onPressed: widget.onNuevoPedido,
                    style: FilledButton.styleFrom(
                      backgroundColor: AnaliticaTokens.ink,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo'),
                  ),
                if (mostrarToggleVista)
                  IconButton(
                    tooltip: usarKanban ? 'Vista tarjetas' : 'Vista columnas',
                    onPressed: () =>
                        setState(() => _vistaKanban = !_vistaKanban),
                    icon: Icon(
                      usarKanban ? Icons.grid_view : Icons.view_column,
                      color: AnaliticaTokens.ink,
                    ),
                  ),
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: _recargar,
                  icon: const Icon(Icons.refresh, color: AnaliticaTokens.ink),
                ),
              ],
            ),
          Expanded(
            child: FutureBuilder<List<PedidoAdminModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AnaliticaTokens.ink,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final err = snapshot.error!;
                  final es401 = ManejoErrorSesion.es401(err);
                  if (!es401) {
                    return FoodyEstadoUi.desdeExcepcion(
                      error: err,
                      contexto: 'cargar pedidos',
                      onReintentar: _recargar,
                    );
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            size: 40,
                            color: AnaliticaTokens.inkSoft,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            mensajeErrorHttp(err, contexto: 'cargar pedidos'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AnaliticaTokens.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                ManejoErrorSesion.manejarEnPantalla(err),
                            style: FilledButton.styleFrom(
                              backgroundColor: AnaliticaTokens.ink,
                            ),
                            child: const Text('Iniciar sesión'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final pedidos = snapshot.data ?? [];
                final tabCerrados =
                    _tabClave == PedidoColumnasPorCanal.cerradosClave;
                final mostrarKanban = usarKanban && !tabCerrados;
                final filtrados = _filtrarPedidos(
                  pedidos,
                  ignorarTab: mostrarKanban,
                );
                final tabs = _tabsEstado;
                final activos =
                    pedidos.where((p) => !p.esTerminal).length;
                final totalTurno =
                    pedidos.fold<num>(0, (s, p) => s + p.total);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!widget.modoMesero) ...[
                            _KpiPedidosChip(
                              etiqueta: 'Activos',
                              valor: '$activos',
                            ),
                            _KpiPedidosChip(
                              etiqueta: 'Total',
                              valor: _formatoMoneda.format(totalTurno),
                            ),
                          ],
                          OperacionBusqueda(
                            controller: _busquedaCtrl,
                            hint: 'Buscar pedido, mesa, cliente…',
                            onChanged: (_) => setState(() {}),
                          ),
                          if (widget.ocultarCabecera) ...[
                            if (mostrarToggleVista)
                              IconButton(
                                tooltip: usarKanban
                                    ? 'Vista tarjetas'
                                    : 'Vista columnas',
                                onPressed: () => setState(
                                  () => _vistaKanban = !_vistaKanban,
                                ),
                                icon: Icon(
                                  usarKanban
                                      ? Icons.grid_view
                                      : Icons.view_column,
                                  color: AnaliticaTokens.ink,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Actualizar',
                              onPressed: _recargar,
                              icon: const Icon(
                                Icons.refresh,
                                color: AnaliticaTokens.ink,
                              ),
                            ),
                            if (!widget.modoMesero &&
                                widget.onNuevoPedido != null)
                              FilledButton.icon(
                                onPressed: widget.onNuevoPedido,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AnaliticaTokens.ink,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Nuevo'),
                              ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                      child: OperacionPillTabs(
                        opciones: widget.modoMesero
                            ? const [
                                ('todos', 'Todos'),
                                ('mesa', 'Mesa'),
                                ('para_llevar', 'Para llevar'),
                              ]
                            : const [
                                ('todos', 'Todos'),
                                ('mesa', 'Mesa'),
                                ('domicilio', 'Domicilio'),
                                ('para_llevar', 'Para llevar'),
                              ],
                        seleccionada: _filtroTipo,
                        onCambio: (v) => setState(() {
                          _filtroTipo = v;
                          _asegurarTabValida();
                        }),
                      ),
                    ),
                    if (!mostrarKanban)
                      FoodyScrollHorizontalFade(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < tabs.length; i++) ...[
                                if (i > 0) const SizedBox(width: 8),
                                OperacionStatChip(
                                  etiqueta: tabs[i].titulo,
                                  valor: '${_conteoTab(tabs[i], pedidos)}',
                                  seleccionado: _tabClave == tabs[i].clave,
                                  onTap: () => setState(() {
                                    _tabClave = tabs[i].clave;
                                    _vistaKanban = false;
                                  }),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        color: AnaliticaTokens.ink,
                        onRefresh: () async => _recargar(),
                        child: mostrarKanban
                            ? _vistaColumnasKanban(filtrados)
                            : _vistaGridPedidos(filtrados),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget? _pieDomi(PedidoAdminModel pedido) {
    // En card solo asignar (listo); reasignar vive en el detalle.
    if (!_puedeGestionarDomi(pedido) || pedido.estado != 'listo') return null;
    return AsignarDomiciliarioSlot(
      pedido: pedido,
      domiciliarios: _domiciliarios,
      reasignar: false,
      onAsignar: _asignarDomiciliario,
      onDispatchIndependiente: _dispatchIndependiente,
    );
  }

  Widget _vistaGridPedidos(List<PedidoAdminModel> pedidos) {
    if (pedidos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'Sin pedidos con ese filtro',
              style: TextStyle(color: AnaliticaTokens.inkSoft),
            ),
          ),
        ],
      );
    }
    // Altura intrínseca por tarjeta (no GridView de celdas fijas).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = FoodyBreakpoints.esLarge(constraints.maxWidth)
            ? 3
            : FoodyBreakpoints.esExpanded(constraints.maxWidth)
                ? 2
                : 1;
        const gap = 12.0;
        const padH = 16.0;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(padH, 0, padH, 16),
          itemCount: ((pedidos.length + cols - 1) ~/ cols) +
              (_tabClave == PedidoColumnasPorCanal.cerradosClave ? 1 : 0),
          itemBuilder: (context, row) {
            final filasPedidos = (pedidos.length + cols - 1) ~/ cols;
            if (row >= filasPedidos) {
              return Column(
                children: [
                  const SizedBox(height: 16),
                  if (_totalCerrados > 0)
                    Text(
                      'Mostrando ${_cerradosHoy.length} de $_totalCerrados',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  if (_hayMasCerrados) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _cargandoMasCerrados
                            ? null
                            : () => _cargarCerradosHoy(mas: true),
                        child: _cargandoMasCerrados
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Cargar más'),
                      ),
                    ),
                  ],
                ],
              );
            }
            final start = row * cols;
            final end = (start + cols).clamp(0, pedidos.length);
            final slice = pedidos.sublist(start, end);
            return Padding(
              padding: EdgeInsets.only(bottom: row == filasPedidos - 1 ? 0 : gap),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cols; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    Expanded(
                      child: i < slice.length
                          ? PedidoKanbanCard(
                              pedido: slice[i],
                              formatoMoneda: _formatoMoneda,
                              minutos: _minutosEnEstado(slice[i].estadoDesde),
                              textoReloj: _textoReloj,
                              colorReloj: _colorReloj,
                              onTap: () => _mostrarAcciones(slice[i]),
                              onAccionRapida: () => _accionRapida(slice[i]),
                              pieExtra: _pieDomi(slice[i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _vistaColumnasKanban(List<PedidoAdminModel> pedidos) {
    final cols = _columnasVisibles;
    final porColumna = <String, List<PedidoAdminModel>>{};
    for (final col in cols) {
      porColumna[col.clave] = [];
    }
    for (final p in pedidos) {
      final clave = PedidoColumnasPorCanal.claveColumna(p.estadoKanban, cols);
      porColumna.putIfAbsent(clave, () => []).add(p);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = cols.length;
        final anchoCol =
            (constraints.maxWidth / n.clamp(1, 4)).clamp(240.0, 320.0);
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final col in cols)
              PedidoKanbanColumn(
                titulo: col.titulo,
                ancho: anchoCol,
                pedidos: porColumna[col.clave] ?? [],
                formatoMoneda: _formatoMoneda,
                minutosEnEstado: _minutosEnEstado,
                textoReloj: _textoReloj,
                colorReloj: _colorReloj,
                onTapPedido: _mostrarAcciones,
                onAccionRapida: _accionRapida,
                pieBuilder: _pieDomi,
              ),
          ],
        );
      },
    );
  }
}

class _KpiPedidosChip extends StatelessWidget {
  const _KpiPedidosChip({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AnaliticaTokens.border),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AnaliticaTokens.inkSoft,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AnaliticaTokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}
