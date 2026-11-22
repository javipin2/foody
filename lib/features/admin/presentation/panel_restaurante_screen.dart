import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/auth/roles_foody.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/manejo_error_sesion.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/core/tema/tema_mode_provider.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/api_offline_banner.dart';
import 'package:reserva_canchas/features/admin/presentation/configuracion_admin_screen.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/realtime_aviso_banner.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/modulo_bloqueado_placeholder.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/suscripcion_aviso_banner.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/admin_busqueda_dialog.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/panel_sidebar_nav.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_consolidado_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_graficos_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_resumen_widget.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/pedidos_kanban_widget.dart';
import 'package:reserva_canchas/features/caja/presentation/caja_admin_screen.dart';
import 'package:reserva_canchas/features/catalogo/presentation/menu_admin_screen.dart';
import 'package:reserva_canchas/features/cocinas/presentation/cocinas_admin_screen.dart';
import 'package:reserva_canchas/features/cocinas/presentation/kds_screen.dart';
import 'package:reserva_canchas/features/costeo/presentation/costos_margenes_screen.dart';
import 'package:reserva_canchas/features/inventario/presentation/inventario_admin_screen.dart';
import 'package:reserva_canchas/features/zonas/presentation/zonas_admin_screen.dart';
import 'package:reserva_canchas/features/usuarios/presentation/usuarios_admin_screen.dart';
import 'package:reserva_canchas/features/alertas/presentation/alertas_admin_screen.dart';
import 'package:reserva_canchas/features/analitica/presentation/analitica_screen.dart';
import 'package:reserva_canchas/features/reportes/presentation/reportes_admin_screen.dart';
import 'package:reserva_canchas/features/facturacion/presentation/facturacion_admin_screen.dart';
import 'package:reserva_canchas/features/finanzas/presentation/finanzas_admin_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliarios_admin_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/presentation/horarios_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/presentation/sucursales_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/core/navegacion/abrir_app_cliente.dart';
import 'package:reserva_canchas/features/pagos/presentation/mejorar_plan_screen.dart';
import 'package:reserva_canchas/features/pagos/domain/pagos_deep_link_service.dart';
import 'package:reserva_canchas/features/pagos/data/pagos_repository.dart';
import 'package:reserva_canchas/features/pagos/domain/planes_comerciales.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Panel restaurante (A02…) — sidebar dinámico según permisos del backend.
class PanelRestauranteScreen extends StatefulWidget {
  const PanelRestauranteScreen({
    super.key,
    this.seccionInicial,
    this.pagoIdInicial,
    this.mesaIdInicial,
    this.productoIdInicial,
    this.pedidoIdInicial,
    this.ingredienteIdInicial,
  });

  /// Ruta interna del sidebar (p. ej. `pedidos`, `menu`). Ver `MenuAdminItem.ruta`.
  final String? seccionInicial;
  final String? pagoIdInicial;
  final String? mesaIdInicial;
  /// Deep-link Costos (NAV-MC-20): `?seccion=costos_margenes&producto_id=…`.
  final String? productoIdInicial;
  /// NAV-ADM2-01: FCM / alertas / caja → abrir sheet del pedido.
  final String? pedidoIdInicial;
  /// NAV-ADM2-04: alerta stock → destacar insumo.
  final String? ingredienteIdInicial;

  @override
  State<PanelRestauranteScreen> createState() => _PanelRestauranteScreenState();
}

class _PanelRestauranteScreenState extends State<PanelRestauranteScreen>
    with WidgetsBindingObserver {
  SesionStaff? _sesion;
  List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> _gruposMenu = [];
  String _seccion = 'dashboard';
  String? _analiticaTabInicial;
  String? _productoCostosId;
  String? _insumosFiltroInicial;
  bool _cargando = true;
  List<Map<String, dynamic>> _sucursales = [];
  String? _sucursalActivaId;
  Map<String, dynamic>? _suscripcion;
  String? _planSugeridoUpgrade;
  String? _pagoIdActivo;
  RealtimeChannel? _canalSuscripcion;
  PollRealtimeRespaldo? _pollSuscripcion;
  bool _avisoPlanMostrado = false;

  String? _mesaIdPendiente;
  String? _pedidoFacturaId;
  String? _pedidoFacturaNumero;
  String? _pedidoIdPendiente;
  String? _pedidoIdAgregar;
  String? _itemIdReemplazar;
  String? _insumosIngredienteId;
  /// NAV-ADM2-17: fuerza remount al pulsar refresh.
  int _refreshTick = 0;
  bool _bannerSuscripcionOculto = false;

  String? get _sucursalIdEfectiva =>
      _sucursalActivaId ?? _sesion?.sucursalId;

  bool get _puedeOperarMultiSucursal => esCorporativoStaff(
        rol: _sesion?.rol,
        permisos: _sesion?.permisos ?? [],
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pagoIdActivo =
        widget.pagoIdInicial ?? PagosDeepLinkService.consumirPagoIdPendiente();
    unawaited(_cargarSesion().then((_) async {
      if (!mounted) return;
      _suscribirSuscripcionRealtime();
      // Un sync puntual si volviste de Wompi con pago_id (sin poll ni remount).
      if (_pagoIdActivo != null) {
        await _intentarConfirmarPagoPendiente();
        await _recargarPerfilTrasPago(mostrarAviso: true);
      }
    }));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollSuscripcion?.detener();
    final ch = _canalSuscripcion;
    _canalSuscripcion = null;
    if (ch != null && AppBackend.supabaseReady) {
      unawaited(Supabase.instance.client.removeChannel(ch));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pagoIdActivo != null) {
      unawaited(_alVolverAlFrente());
    }
  }

  Future<void> _alVolverAlFrente() async {
    await _intentarConfirmarPagoPendiente();
    await _recargarPerfilTrasPago(mostrarAviso: true);
    if (!mounted) return;
    if (_pagoIdActivo != null && _seccion != 'mejorar_plan') {
      setState(() => _seccion = 'mejorar_plan');
    }
  }

  Future<void> _intentarConfirmarPagoPendiente() async {
    final pagoId = _pagoIdActivo;
    if (pagoId == null || pagoId.isEmpty) return;
    try {
      final r = await PagosRepository().sincronizar(pagoId: pagoId);
      if (r['sincronizado'] == true) {
        _pagoIdActivo = null;
      }
    } catch (_) {}
  }

  void _suscribirSuscripcionRealtime() {
    final rid = _sesion?.usuario['restaurante_id'] as String?;
    if (rid == null || rid.isEmpty) return;
    _pollSuscripcion?.detener();
    _pollSuscripcion = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) await _recargarPerfilTrasPago(mostrarAviso: false);
    });
    unawaited(_pollSuscripcion!.iniciar());
    if (!AppBackend.supabaseReady) return;
    final previo = _canalSuscripcion;
    if (previo != null) {
      unawaited(Supabase.instance.client.removeChannel(previo));
    }
    _canalSuscripcion = FoodyRealtime.suscribirRestaurante(
      rid,
      onSuscripcionActualizada: () {
        unawaited(_recargarPerfilTrasPago(mostrarAviso: true));
      },
      onReconectado: () {
        unawaited(_recargarPerfilTrasPago(mostrarAviso: false));
      },
    );
  }

  Future<void> _cargarSesion() async {
    var sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    if (sesion == null) {
      context.go('/admin/login');
      return;
    }
    FoodyRealtime.aplicarCanalesStaff(sesion.realtimeCanales);
    if (sesion.realtimeCanales.isEmpty) {
      try {
        await AuthRepository().refrescarRealtimeCanales(
          sucursalId: sesion.sucursalId,
        );
      } catch (_) {}
    }
    try {
      final perfil = await AuthRepository().sincronizarPerfil();
      final canalesFresh = await SesionStaffService.obtenerRealtimeCanales();
      sesion = SesionStaff(
        token: sesion.token,
        dashboard: sesion.dashboard,
        rol: sesion.rol,
        permisos: perfil.permisos,
        usuario: sesion.usuario,
        plan: perfil.plan,
        modulos: perfil.modulos,
        realtimeCanales: canalesFresh.isNotEmpty
            ? canalesFresh
            : sesion.realtimeCanales,
      );
      _suscripcion = perfil.suscripcion;
    } catch (e) {
      if (await ManejoErrorSesion.manejarEnPantalla(e)) return;
    }
    final sesionActiva = sesion!;
    final grupos = MenuAdminGrupoData.construir(
      sesionActiva.permisos,
      modulosPlan: sesionActiva.modulos,
      planActual: sesionActiva.plan,
      rol: sesionActiva.rol,
    );
    final rutas = grupos.expand((g) => g.items.map((i) => i.ruta)).toList();
    // NAV-MG-01: también gerente (ver_dashboard) para mostrar nombre real de sede.
    var sucursales = <Map<String, dynamic>>[];
    if (sesionActiva.permisos.contains('ver_dashboard') ||
        sesionActiva.permisos.contains('gestionar_sucursales') ||
        esCorporativoStaff(
          rol: sesionActiva.rol,
          permisos: sesionActiva.permisos,
        )) {
      try {
        sucursales = await SucursalesRepository().listarMiRestaurante();
      } catch (_) {}
    }
    if (!mounted) return;
    var seccion = widget.seccionInicial;
    if (_pagoIdActivo != null) {
      seccion = 'mejorar_plan';
    }
    // Plan/pagos siempre alcanzable por deep link aunque falte en sidebar.
    if (seccion != null &&
        seccion != 'mejorar_plan' &&
        !rutas.contains(seccion)) {
      seccion = null;
    }
    setState(() {
      _sesion = sesionActiva;
      _gruposMenu = grupos;
      _seccion = seccion ?? (rutas.isNotEmpty ? rutas.first : 'dashboard');
      _sucursales = sucursales;
      _sucursalActivaId = sesionActiva.sucursalId;
      _mesaIdPendiente = widget.mesaIdInicial;
      _productoCostosId = widget.productoIdInicial;
      _pedidoIdPendiente = widget.pedidoIdInicial;
      _insumosIngredienteId = widget.ingredienteIdInicial;
      if (widget.ingredienteIdInicial != null) {
        _insumosFiltroInicial ??= 'bajo_stock';
      }
      _cargando = false;
    });
  }

  Future<void> _cambiarSucursal(String? id) async {
    if (id == null || id == _sucursalIdEfectiva) return;
    if (!_puedeOperarMultiSucursal) return;
    await SesionStaffService.actualizarSucursalId(id);
    try {
      await AuthRepository().refrescarRealtimeCanales(sucursalId: id);
    } catch (_) {
      // Sin topic nuevo el RT de sede fallará hasta re-login; no bloquear UI.
    }
    if (!mounted) return;
    setState(() {
      _sucursalActivaId = id;
      if (_sesion != null) {
        final usuario = Map<String, dynamic>.from(_sesion!.usuario);
        usuario['sucursal_id'] = id;
        _sesion = SesionStaff(
          token: _sesion!.token,
          dashboard: _sesion!.dashboard,
          rol: _sesion!.rol,
          permisos: _sesion!.permisos,
          usuario: usuario,
          plan: _sesion!.plan,
          modulos: _sesion!.modulos,
          realtimeCanales: _sesion!.realtimeCanales,
        );
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesionStaff(context);
  }

  String _nombreSucursalActiva() {
    return _nombreSucursalConocido() ?? 'Sucursal';
  }

  /// Nombre real de la sede en sesión; null si aún no se resolvió.
  String? _nombreSucursalConocido() {
    for (final s in _sucursales) {
      if (s['id'] == _sucursalIdEfectiva) {
        return s['nombre'] as String?;
      }
    }
    return null;
  }

  Widget _contenido() {
    final sucursalId = _sucursalIdEfectiva;
    // Al cambiar sede (admin multi-sucursal) forzar recarga de cada módulo.
    return KeyedSubtree(
      key: ValueKey('panel-$sucursalId-$_seccion-$_refreshTick'),
      child: _contenidoSeccion(sucursalId),
    );
  }

  MenuAdminItem? _itemMenuActual() {
    for (final g in _gruposMenu) {
      for (final item in g.items) {
        if (item.ruta == _seccion) return item;
      }
    }
    return null;
  }

  Future<void> _recargarPerfilTrasPago({bool mostrarAviso = false}) async {
    try {
      final perfil = await AuthRepository().sincronizarPerfil();
      if (!mounted || _sesion == null) return;
      final planAntes = _sesion!.plan;
      final sesionFresh = await SesionStaffService.cargar();
      if (!mounted) return;
      final token = sesionFresh?.token ?? _sesion!.token;
      final cambio =
          PlanesComercialesFoody.nivel(perfil.plan) >
          PlanesComercialesFoody.nivel(planAntes);

      setState(() {
        _sesion = SesionStaff(
          token: token,
          dashboard: _sesion!.dashboard,
          rol: _sesion!.rol,
          permisos: perfil.permisos,
          usuario: sesionFresh?.usuario ?? _sesion!.usuario,
          plan: perfil.plan,
          modulos: perfil.modulos,
          realtimeCanales:
              sesionFresh?.realtimeCanales ?? _sesion!.realtimeCanales,
        );
        _suscripcion = perfil.suscripcion;
        _gruposMenu = MenuAdminGrupoData.construir(
          perfil.permisos,
          modulosPlan: perfil.modulos,
          planActual: perfil.plan,
          rol: _sesion!.rol,
        );
        if (cambio) _pagoIdActivo = null;
      });

      if (cambio && mostrarAviso && !_avisoPlanMostrado && mounted) {
        _avisoPlanMostrado = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Plan ${PlanesComercialesFoody.nombre(perfil.plan)} activo!',
            ),
            backgroundColor: ColoresFoody.exito,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (_) {}
  }

  void _irMejorarPlan({String? planSugerido}) {
    setState(() {
      _seccion = 'mejorar_plan';
      _planSugeridoUpgrade = planSugerido;
    });
  }

  Widget _contenidoSeccion(String? sucursalId) {
    if (_seccion == 'mejorar_plan') {
      return MejorarPlanScreen(
        planActual: _sesion?.plan ?? 'gratis',
        suscripcion: _suscripcion,
        planSugerido: _planSugeridoUpgrade,
        pagoIdInicial: _pagoIdActivo ?? widget.pagoIdInicial,
        onPagoIniciado: (id) => setState(() => _pagoIdActivo = id),
        onPlanActualizado: () => _recargarPerfilTrasPago(mostrarAviso: true),
      );
    }

    final itemMenu = _itemMenuActual();
    if (itemMenu != null && itemMenu.bloqueadoPorPlan) {
      return ModuloBloqueadoPlaceholder(
        tituloModulo: itemMenu.titulo,
        planMinimo: itemMenu.planMinimo ?? 'pro',
        beneficio: itemMenu.beneficioUpgrade ?? '',
        onMejorarPlan: () => _irMejorarPlan(planSugerido: itemMenu.planMinimo),
      );
    }

    switch (_seccion) {
      case 'configuracion':
        return ConfiguracionAdminScreen(
          permisos: _sesion?.permisos ?? const [],
          onAbrir: _seleccionarSeccion,
        );
      case 'dashboard':
        return ColoredBox(
          color: AnaliticaTokens.canvas,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_puedeOperarMultiSucursal && _sucursales.length > 1) ...[
                    DashboardConsolidadoWidget(
                      onSeleccionarSucursal: _cambiarSucursal,
                      onIrAlertas: () => setState(() => _seccion = 'alertas'),
                      onIrPedidos: () => _seleccionarSeccion('pedidos'),
                      onIrReportes: () => _seleccionarSeccion('reportes'),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: AnaliticaTokens.border),
                    const SizedBox(height: 8),
                    Text(
                      'Sede seleccionada: ${_nombreSucursalActiva()}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AnaliticaTokens.ink,
                          ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  DashboardResumenWidget(
                    sucursalId: sucursalId,
                    onIrPedidos: () => setState(() => _seccion = 'pedidos'),
                    onIrMesas: () => setState(() => _seccion = 'mesas'),
                    onIrAlertas: () => setState(() => _seccion = 'alertas'),
                    onIrCaja: () => setState(() => _seccion = 'caja'),
                    onIrReportes: () => _seleccionarSeccion('reportes'),
                    onIrInsumos: () => _seleccionarSeccion('insumos'),
                    onIrDomiciliarios: () =>
                        _seleccionarSeccion('domiciliarios'),
                    onIrCocinaKds: () => _seleccionarSeccion('cocina_kds'),
                  ),
                  const SizedBox(height: 20),
                  DashboardGraficosWidget(
                    sucursalId: sucursalId,
                    onIrReportes: () => _seleccionarSeccion('reportes'),
                    onIrAnalitica: () => _seleccionarSeccion('analitica'),
                  ),
                ],
              ),
            ),
          ),
        );
      case 'pedidos':
        return PedidosKanbanWidget(
          sucursalId: sucursalId,
          pedidoIdInicial: _pedidoIdPendiente,
          onPedidoAbierto: () => setState(() => _pedidoIdPendiente = null),
          onVerMesa: _irMesasConMesa,
          onIrCaja: () => _seleccionarSeccion('caja'),
          onIrFacturacion: _irFacturacionConPedido,
          onIrCocinaKds: () => _seleccionarSeccion('cocina_kds'),
          onNuevoPedido: () {
            setState(() {
              _pedidoIdAgregar = null;
              _itemIdReemplazar = null;
            });
            _seleccionarSeccion('nuevo_pedido');
          },
          onAgregarItems: (pedido, {String? itemIdReemplazar}) {
            setState(() {
              _pedidoIdAgregar = pedido.id;
              _itemIdReemplazar = itemIdReemplazar;
              _seccion = 'nuevo_pedido';
            });
          },
          ocultarCabecera: true,
        );
      case 'nuevo_pedido':
        return PedidoCajeroScreen(
          key: ValueKey(
            'pos-${_pedidoIdAgregar ?? 'nuevo'}-${_itemIdReemplazar ?? ''}',
          ),
          sucursalId: sucursalId,
          pedidoIdAgregar: _pedidoIdAgregar,
          itemIdReemplazar: _itemIdReemplazar,
          onPedidoModificado: () {
            setState(() {
              _pedidoIdAgregar = null;
              _itemIdReemplazar = null;
              _seccion = 'pedidos';
            });
          },
          onIrCaja: () => _seleccionarSeccion('caja'),
          ocultarCabecera: true,
        );
      case 'mesas':
        return MesasGridWidget(
          sucursalId: sucursalId,
          mesaIdInicial: _mesaIdPendiente,
          onMesaAbierta: () => setState(() => _mesaIdPendiente = null),
          ocultarCabecera: true,
        );
      case 'caja':
        return CajaAdminScreen(
          sucursalId: sucursalId,
          ocultarCabecera: true,
          onIrPedido: (pedidoId) {
            _irPedidosConPedido(pedidoId);
          },
        );
      case 'menu':
        return MenuAdminScreen(
          sucursalId: sucursalId,
          sucursalesOrigen: _puedeOperarMultiSucursal
              ? _sucursales
                  .where((s) => s['id'] != sucursalId)
                  .map((s) => Map<String, dynamic>.from(s))
                  .toList()
              : const [],
          onVerCostos: _irCostosConProducto,
        );
      case 'cocinas':
        return CocinasAdminScreen(
          sucursalId: sucursalId,
          onIrKds: () => _seleccionarSeccion('cocina_kds'),
        );
      case 'cocina_kds':
        return KdsScreen(
          sucursalId: sucursalId,
          onIrConfigCocinas: () => _seleccionarSeccion('cocinas'),
        );
      case 'zonas':
        return ZonasAdminScreen(sucursalId: sucursalId);
      case 'horarios':
        return HorariosAdminScreen(sucursalId: sucursalId);
      case 'domiciliarios':
        return DomiciliariosAdminScreen(
          sucursalId: sucursalId,
          onIrPedidosDomicilio: () {
            // Filtro tipo se aplica al abrir kanban via query no soportada;
            // al menos salta a pedidos (ADM2-14).
            _seleccionarSeccion('pedidos');
          },
        );
      case 'promociones':
        return PromocionesAdminScreen(
          sucursalId: sucursalId,
          onIrMenu: () => _seleccionarSeccion('menu'),
        );
      case 'sucursales':
        return SucursalesAdminScreen(
          onIrHorarios: () => _seleccionarSeccion('horarios'),
          onIrZonas: () => _seleccionarSeccion('zonas'),
        );
      case 'insumos':
      case 'inventario': // NAV-MC-31: alias legacy; ruta canónica = `insumos`
        return InventarioAdminScreen(
          sucursalId: sucursalId,
          onIrCostos: () => _seleccionarSeccion('costos_margenes'),
          filtroInicial: _insumosFiltroInicial,
          destacarIngredienteId: _insumosIngredienteId,
        );
      case 'costos_margenes':
        return CostosMargenesScreen(
          sucursalId: sucursalId,
          productoIdInicial: _productoCostosId,
          onVolverAlMenu: () => _seleccionarSeccion('menu'),
          onIrInsumos: () => _seleccionarSeccion('insumos'),
        );
      case 'reportes':
        return ReportesAdminScreen(
          sucursalId: sucursalId,
          onIrAnalitica: () => _seleccionarSeccion('analitica'),
        );
      case 'analitica':
        return AnaliticaScreen(
          sucursalId: sucursalId,
          esCorporativo: _puedeOperarMultiSucursal,
          puedeVerFinanzas:
              _sesion?.permisos.contains('ver_finanzas') ?? false,
          onIrReportes: () => _seleccionarSeccion('reportes'),
          tabInicial: _analiticaTabInicial,
        );
      case 'finanzas':
        return FinanzasAdminScreen(
          sucursalId: sucursalId,
          onVerRentabilidad: () {
            setState(() {
              _analiticaTabInicial = 'rentabilidad';
              _seccion = 'analitica';
            });
            context.go(
              Uri(
                path: '/admin/panel',
                queryParameters: {'seccion': 'analitica'},
              ).toString(),
            );
          },
        );
      case 'facturacion':
        return FacturacionAdminScreen(
          sucursalId: sucursalId,
          pedidoIdInicial: _pedidoFacturaId,
          pedidoNumeroInicial: _pedidoFacturaNumero,
          onPedidoSugeridoUsado: () {
            setState(() {
              _pedidoFacturaId = null;
              _pedidoFacturaNumero = null;
            });
          },
          onIrPedido: (pedidoId) {
            setState(() {
              _pedidoIdPendiente = pedidoId;
              _seccion = 'pedidos';
            });
            context.go(
              Uri(
                path: '/admin/panel',
                queryParameters: {'seccion': 'pedidos'},
              ).toString(),
            );
          },
        );
      case 'alertas':
        return AlertasAdminScreen(
          sucursalId: sucursalId,
          onNavegarReferencia: _navegarDesdeAlerta,
        );
      case 'usuarios':
        return UsuariosAdminScreen(
          sucursalId: sucursalId,
          puedeGestionarMultiSucursal: _puedeOperarMultiSucursal,
          onIrCocinas: () => _seleccionarSeccion('cocinas'),
        );
      default:
        return Center(
          child: Text('Módulo «$_seccion» en construcción'),
        );
    }
  }

  void _seleccionarSeccion(String ruta) {
    // NAV-MC-31: normalizar alias legacy a ruta canónica.
    if (ruta == 'inventario') ruta = 'insumos';
    setState(() {
      _seccion = ruta;
      if (ruta != 'costos_margenes') _productoCostosId = null;
      if (ruta != 'insumos') {
        _insumosFiltroInicial = null;
        _insumosIngredienteId = null;
      }
      if (ruta != 'mejorar_plan') _planSugeridoUpgrade = null;
      if (ruta != 'mesas') _mesaIdPendiente = null;
      if (ruta != 'facturacion') {
        _pedidoFacturaId = null;
        _pedidoFacturaNumero = null;
      }
      if (ruta != 'pedidos') _pedidoIdPendiente = null;
      if (ruta != 'nuevo_pedido') {
        _pedidoIdAgregar = null;
        _itemIdReemplazar = null;
      }
    });
    final params = <String, String>{'seccion': ruta};
    if (widget.pagoIdInicial != null && ruta == 'mejorar_plan') {
      params['pago_id'] = widget.pagoIdInicial!;
    }
    if (ruta == 'costos_margenes' && _productoCostosId != null) {
      params['producto_id'] = _productoCostosId!;
    }
    if (ruta == 'pedidos' && _pedidoIdPendiente != null) {
      params['pedido_id'] = _pedidoIdPendiente!;
    }
    if (ruta == 'insumos' && _insumosIngredienteId != null) {
      params['ingrediente_id'] = _insumosIngredienteId!;
    }
    context.go(Uri(path: '/admin/panel', queryParameters: params).toString());
  }

  /// NAV-ADM2-01/11: abrir Pedidos con sheet del pedido + URL sync.
  void _irPedidosConPedido(String pedidoId) {
    setState(() {
      _pedidoIdPendiente = pedidoId;
      _seccion = 'pedidos';
    });
    context.go(
      Uri(
        path: '/admin/panel',
        queryParameters: {
          'seccion': 'pedidos',
          'pedido_id': pedidoId,
        },
      ).toString(),
    );
  }

  /// NAV-MC-20: Menú → Costos con URL sync (refresh / deep-link).
  void _irCostosConProducto(String productoId) {
    setState(() {
      _productoCostosId = productoId;
      _seccion = 'costos_margenes';
    });
    context.go(
      Uri(
        path: '/admin/panel',
        queryParameters: {
          'seccion': 'costos_margenes',
          'producto_id': productoId,
        },
      ).toString(),
    );
  }

  Future<void> _mostrarSelectorSucursalMovil() async {
    if (!_puedeOperarMultiSucursal || _sucursales.length < 2) return;
    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                'Cambiar sucursal',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final s in _sucursales)
              ListTile(
                leading: Icon(
                  s['id'] == _sucursalIdEfectiva
                      ? Icons.store
                      : Icons.store_outlined,
                  color: s['id'] == _sucursalIdEfectiva
                      ? ColoresFoody.primario
                      : null,
                ),
                title: Text(s['nombre'] as String? ?? 'Sucursal'),
                selected: s['id'] == _sucursalIdEfectiva,
                onTap: () => Navigator.pop(ctx, s['id'] as String),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegida != null) await _cambiarSucursal(elegida);
  }

  void _irMesasConMesa(String mesaId) {
    setState(() {
      _mesaIdPendiente = mesaId;
      _seccion = 'mesas';
    });
    context.go(
      Uri(
        path: '/admin/panel',
        queryParameters: {'seccion': 'mesas', 'mesa_id': mesaId},
      ).toString(),
    );
  }

  void _irFacturacionConPedido(String pedidoId, String numeroPedido) {
    setState(() {
      _pedidoFacturaId = pedidoId;
      _pedidoFacturaNumero = numeroPedido;
      _seccion = 'facturacion';
    });
    context.go(
      Uri(
        path: '/admin/panel',
        queryParameters: {'seccion': 'facturacion'},
      ).toString(),
    );
  }

  void _navegarDesdeAlerta(String referenciaTipo, String referenciaId) {
    switch (referenciaTipo) {
      case 'pedido':
      case 'pedido_item':
        _irPedidosConPedido(referenciaId);
        break;
      case 'mesa':
        _irMesasConMesa(referenciaId);
        break;
      case 'ingrediente':
        setState(() {
          _insumosFiltroInicial = 'bajo_stock';
          _insumosIngredienteId = referenciaId;
          _seccion = 'insumos';
        });
        context.go(
          Uri(
            path: '/admin/panel',
            queryParameters: {
              'seccion': 'insumos',
              'ingrediente_id': referenciaId,
            },
          ).toString(),
        );
        break;
      case 'producto':
      case 'combo':
        // NAV-ADM2-05: costo/margen → Costos (producto_id abre ficha).
        _irCostosConProducto(referenciaId);
        break;
      case 'usuario':
        _seleccionarSeccion('usuarios');
        break;
      case 'caja':
        _seleccionarSeccion('caja');
        break;
      default:
        break;
    }
  }

  void _abrirBusquedaAdmin() {
    final sucursalId = _sucursalIdEfectiva;
    if (sucursalId == null) return;
    mostrarBusquedaAdmin(
      context: context,
      sucursalId: sucursalId,
      grupos: _gruposMenu,
      onIrSeccion: _seleccionarSeccion,
      onIrMesa: _irMesasConMesa,
      onIrPedido: (pedidoId) {
        _irPedidosConPedido(pedidoId);
      },
    );
  }

  String _tituloSeccionActual() {
    if (_seccion == 'mejorar_plan') return 'Plan y pagos';
    for (final g in _gruposMenu) {
      for (final item in g.items) {
        if (item.ruta == _seccion) return item.titulo;
      }
    }
    return 'Panel';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        body: FoodyEstadoUi.cargando(mensaje: 'Cargando panel…'),
      );
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final esMovil = PanelLayoutBreakpoints.esMovil(ancho);
    final esTablet = PanelLayoutBreakpoints.esTablet(ancho);
    final anchoSidebar = PanelLayoutBreakpoints.anchoSidebar(ancho);

    return Scaffold(
      backgroundColor: SaaSTokens.canvas(context),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: SaaSTokens.surface(context),
        foregroundColor: SaaSTokens.ink(context),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tituloSeccionActual(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: SaaSTokens.ink(context),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              _sesion?.usuario['nombre'] as String? ?? 'Staff',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: SaaSTokens.inkMuted(context),
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(temaModeProvider);
              final oscuro = mode == ThemeMode.dark ||
                  (mode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) ==
                          Brightness.dark);
              return IconButton(
                tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
                icon: Icon(
                  oscuro
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: SaaSTokens.inkMuted(context),
                ),
                onPressed: () =>
                    ref.read(temaModeProvider.notifier).alternar(),
              );
            },
          ),
          if (esMovil &&
              _puedeOperarMultiSucursal &&
              _sucursales.length > 1)
            IconButton(
              tooltip: 'Cambiar sucursal (${_nombreSucursalActiva()})',
              icon: Icon(
                Icons.storefront_outlined,
                color: SaaSTokens.inkMuted(context),
              ),
              onPressed: _mostrarSelectorSucursalMovil,
            )
          else if (!esMovil &&
              _puedeOperarMultiSucursal &&
              _sucursales.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: SaaSTokens.surface(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SaaSTokens.border(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sucursalIdEfectiva,
                    hint: Text(
                      'Sucursal',
                      style: TextStyle(
                        fontSize: 12,
                        color: SaaSTokens.inkMuted(context),
                      ),
                    ),
                    icon: Icon(
                      Icons.expand_more,
                      size: 18,
                      color: SaaSTokens.inkMuted(context),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: SaaSTokens.ink(context),
                      fontWeight: FontWeight.w600,
                    ),
                    dropdownColor: SaaSTokens.surface(context),
                    items: _sucursales
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['nombre'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: _cambiarSucursal,
                  ),
                ),
              ),
            )
          else if (!esMovil && _sucursalIdEfectiva != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: SaaSTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: SaaSTokens.border(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      size: 16,
                      color: SaaSTokens.inkMuted(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _nombreSucursalActiva(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SaaSTokens.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: Icon(
              Icons.refresh_rounded,
              color: SaaSTokens.inkMuted(context),
            ),
            onPressed: () => setState(() => _refreshTick++),
          ),
          IconButton(
            tooltip: 'Buscar módulo',
            icon: Icon(Icons.search, color: SaaSTokens.inkMuted(context)),
            onPressed: _abrirBusquedaAdmin,
          ),
          if (esMovil)
            PopupMenuButton<String>(
              tooltip: 'Más',
              icon: Icon(
                Icons.more_vert,
                color: SaaSTokens.inkMuted(context),
              ),
              onSelected: (v) {
                if (v == 'cliente') {
                  AbrirAppCliente.ejecutar(context);
                } else if (v == 'sucursal') {
                  unawaited(_mostrarSelectorSucursalMovil());
                } else if (v == 'logout') {
                  _cerrarSesion();
                }
              },
              itemBuilder: (_) => [
                if (_puedeOperarMultiSucursal && _sucursales.length > 1)
                  PopupMenuItem(
                    value: 'sucursal',
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text('Sucursal: ${_nombreSucursalActiva()}'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'cliente',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.storefront_outlined),
                    title: Text('Ir a cliente'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.logout_outlined),
                    title: Text('Cerrar sesión'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'Ir a cliente',
              icon: Icon(
                Icons.storefront_outlined,
                color: SaaSTokens.inkMuted(context),
              ),
              onPressed: () => AbrirAppCliente.ejecutar(context),
            ),
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: Icon(
                Icons.logout_outlined,
                color: SaaSTokens.inkMuted(context),
              ),
              onPressed: _cerrarSesion,
            ),
          ],
        ],
      ),
      drawer: esMovil
          ? Drawer(
              width: anchoSidebar.clamp(280.0, 320.0),
              child: _sidebar(compacto: false),
            )
          : null,
      body: Column(
        children: [
          if (!_bannerSuscripcionOculto)
            SuscripcionAvisoBanner(
              suscripcion: _suscripcion,
              onMejorarPlan: _irMejorarPlan,
              onDismiss: () => setState(() => _bannerSuscripcionOculto = true),
            ),
          const ApiOfflineBanner(),
          const RealtimeAvisoBanner(),
          Expanded(
            child: Row(
              children: [
                if (!esMovil)
                  SizedBox(
                    width: anchoSidebar,
                    child: _sidebar(compacto: esTablet),
                  ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AnaliticaTokens.surface,
                      border: Border(
                        left: esMovil
                            ? BorderSide.none
                            : const BorderSide(color: AnaliticaTokens.border),
                      ),
                    ),
                    child: ClipRect(child: _contenido()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar({required bool compacto}) {
    return PanelSidebarNav(
      grupos: _gruposMenu,
      seccionActiva: _seccion,
      anchoCompacto: compacto,
      nombreUsuario: _sesion?.usuario['nombre'] as String?,
      // NAV-MG-01: mostrar sede aunque sea única (gerente no cambia de sede).
      nombreSucursal: _nombreSucursalConocido(),
      onSeleccionar: (ruta) {
        _seleccionarSeccion(ruta);
        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      },
    );
  }
}
