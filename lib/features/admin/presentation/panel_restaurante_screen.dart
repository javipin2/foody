import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/realtime_aviso_banner.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/modulo_bloqueado_placeholder.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/suscripcion_aviso_banner.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/panel_sidebar_nav.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/dashboard_resumen_widget.dart';
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
import 'package:reserva_canchas/features/reportes/presentation/reportes_admin_screen.dart';
import 'package:reserva_canchas/features/facturacion/presentation/facturacion_admin_screen.dart';
import 'package:reserva_canchas/features/domiciliarios/presentation/domiciliarios_admin_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';
import 'package:reserva_canchas/features/promociones/presentation/promociones_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/presentation/horarios_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/presentation/sucursales_admin_screen.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/pagos/presentation/mejorar_plan_screen.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';

/// Panel restaurante (A02…) — sidebar dinámico según permisos del backend.
class PanelRestauranteScreen extends StatefulWidget {
  const PanelRestauranteScreen({
    super.key,
    this.seccionInicial,
    this.pagoIdInicial,
  });

  /// Ruta interna del sidebar (p. ej. `pedidos`, `menu`). Ver `MenuAdminItem.ruta`.
  final String? seccionInicial;
  final String? pagoIdInicial;

  @override
  State<PanelRestauranteScreen> createState() => _PanelRestauranteScreenState();
}

class _PanelRestauranteScreenState extends State<PanelRestauranteScreen> {
  SesionStaff? _sesion;
  List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> _gruposMenu = [];
  String _seccion = 'dashboard';
  String? _productoCostosId;
  bool _cargando = true;
  List<Map<String, dynamic>> _sucursales = [];
  String? _sucursalActivaId;
  Map<String, dynamic>? _suscripcion;
  String? _planSugeridoUpgrade;

  String? get _sucursalIdEfectiva =>
      _sucursalActivaId ?? _sesion?.sucursalId;

  bool get _puedeOperarMultiSucursal =>
      _sesion?.permisos.contains('gestionar_sucursales') ?? false;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  Future<void> _cargarSesion() async {
    var sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    if (sesion == null) {
      context.go('/admin/login');
      return;
    }
    try {
      final perfil = await AuthRepository().sincronizarPerfil();
      sesion = SesionStaff(
        token: sesion.token,
        dashboard: sesion.dashboard,
        rol: sesion.rol,
        permisos: perfil.permisos,
        usuario: sesion.usuario,
        plan: perfil.plan,
        modulos: perfil.modulos,
      );
      _suscripcion = perfil.suscripcion;
    } catch (_) {}
    final sesionActiva = sesion!;
    final grupos = MenuAdminGrupoData.construir(
      sesionActiva.permisos,
      modulosPlan: sesionActiva.modulos,
      planActual: sesionActiva.plan,
      rol: sesionActiva.rol,
    );
    final rutas = grupos.expand((g) => g.items.map((i) => i.ruta)).toList();
    var sucursales = <Map<String, dynamic>>[];
    if (sesionActiva.permisos.contains('gestionar_sucursales')) {
      try {
        sucursales = await SucursalesRepository().listarMiRestaurante();
      } catch (_) {}
    }
    if (!mounted) return;
    var seccion = widget.seccionInicial;
    if (seccion != null && !rutas.contains(seccion)) {
      seccion = null;
    }
    setState(() {
      _sesion = sesionActiva;
      _gruposMenu = grupos;
      _seccion = seccion ?? (rutas.isNotEmpty ? rutas.first : 'dashboard');
      _sucursales = sucursales;
      _sucursalActivaId = sesionActiva.sucursalId;
      _cargando = false;
    });
  }

  Future<void> _cambiarSucursal(String? id) async {
    if (id == null || id == _sucursalIdEfectiva) return;
    if (!_puedeOperarMultiSucursal) return;
    await SesionStaffService.actualizarSucursalId(id);
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
        );
      }
    });
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository().logout();
    if (mounted) context.go('/splash');
  }

  String _nombreSucursalActiva() {
    for (final s in _sucursales) {
      if (s['id'] == _sucursalIdEfectiva) {
        return s['nombre'] as String? ?? 'Sucursal';
      }
    }
    return 'Sucursal';
  }

  Widget _contenido() {
    final sucursalId = _sucursalIdEfectiva;
    // Al cambiar sede (admin multi-sucursal) forzar recarga de cada módulo.
    return KeyedSubtree(
      key: ValueKey('panel-$sucursalId-$_seccion'),
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

  Future<void> _recargarPerfilTrasPago() async {
    try {
      final perfil = await AuthRepository().sincronizarPerfil();
      if (!mounted || _sesion == null) return;
      setState(() {
        _sesion = SesionStaff(
          token: _sesion!.token,
          dashboard: _sesion!.dashboard,
          rol: _sesion!.rol,
          permisos: perfil.permisos,
          usuario: _sesion!.usuario,
          plan: perfil.plan,
          modulos: perfil.modulos,
        );
        _suscripcion = perfil.suscripcion;
        _gruposMenu = MenuAdminGrupoData.construir(
          perfil.permisos,
          modulosPlan: perfil.modulos,
          planActual: perfil.plan,
          rol: _sesion!.rol,
        );
      });
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
        pagoIdInicial: widget.pagoIdInicial,
        onPlanActualizado: _recargarPerfilTrasPago,
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
      case 'dashboard':
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              DashboardResumenWidget(
                sucursalId: sucursalId,
                onIrPedidos: () => setState(() => _seccion = 'pedidos'),
                onIrMesas: () => setState(() => _seccion = 'mesas'),
                onIrAlertas: () => setState(() => _seccion = 'alertas'),
              ),
            ],
          ),
        );
      case 'pedidos':
        return PedidosKanbanWidget(sucursalId: sucursalId);
      case 'nuevo_pedido':
        return PedidoCajeroScreen(sucursalId: sucursalId);
      case 'mesas':
        return MesasGridWidget(sucursalId: sucursalId);
      case 'caja':
        return CajaAdminScreen(sucursalId: sucursalId);
      case 'menu':
        return MenuAdminScreen(
          sucursalId: sucursalId,
          onVerCostos: (productoId) {
            setState(() {
              _seccion = 'costos_margenes';
              _productoCostosId = productoId;
            });
          },
        );
      case 'cocinas':
        return CocinasAdminScreen(sucursalId: sucursalId);
      case 'cocina_kds':
        return KdsScreen(sucursalId: sucursalId);
      case 'zonas':
        return ZonasAdminScreen(sucursalId: sucursalId);
      case 'horarios':
        return HorariosAdminScreen(sucursalId: sucursalId);
      case 'domiciliarios':
        return DomiciliariosAdminScreen(sucursalId: sucursalId);
      case 'promociones':
        return PromocionesAdminScreen(sucursalId: sucursalId);
      case 'sucursales':
        return const SucursalesAdminScreen();
      case 'insumos':
      case 'inventario':
        return InventarioAdminScreen(sucursalId: sucursalId);
      case 'costos_margenes':
        return CostosMargenesScreen(
          sucursalId: sucursalId,
          productoIdInicial: _productoCostosId,
        );
      case 'reportes':
        return ReportesAdminScreen(sucursalId: sucursalId);
      case 'facturacion':
        return FacturacionAdminScreen(sucursalId: sucursalId);
      case 'alertas':
        return AlertasAdminScreen(sucursalId: sucursalId);
      case 'usuarios':
        return UsuariosAdminScreen(
          sucursalId: sucursalId,
          puedeGestionarMultiSucursal: _puedeOperarMultiSucursal,
        );
      default:
        return Center(
          child: Text('Módulo «$_seccion» en construcción'),
        );
    }
  }

  void _seleccionarSeccion(String ruta) {
    setState(() {
      _seccion = ruta;
      if (ruta != 'costos_margenes') _productoCostosId = null;
      if (ruta != 'mejorar_plan') _planSugeridoUpgrade = null;
    });
  }

  String _tituloSeccionActual() {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final esMovil = PanelLayoutBreakpoints.esMovil(ancho);
    final esTablet = PanelLayoutBreakpoints.esTablet(ancho);
    final anchoSidebar = PanelLayoutBreakpoints.anchoSidebar(ancho);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tituloSeccionActual(),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              _sesion?.usuario['nombre'] as String? ?? 'Staff',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (_puedeOperarMultiSucursal && _sucursales.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sucursalIdEfectiva,
                  hint: const Text('Sucursal'),
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
            )
          else if (_sucursalIdEfectiva != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Chip(
                avatar: const Icon(Icons.store, size: 18),
                label: Text(
                  _nombreSucursalActiva(),
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            tooltip: 'Ir a cliente',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.go('/cliente'),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _cerrarSesion,
          ),
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
          SuscripcionAvisoBanner(
            suscripcion: _suscripcion,
            onMejorarPlan: _irMejorarPlan,
          ),
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
                      color: Colors.white,
                      border: Border(
                        left: esMovil
                            ? BorderSide.none
                            : BorderSide(color: Colors.grey.shade200),
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
      nombreSucursal: _sucursales.length <= 1 ? null : _nombreSucursalActiva(),
      onSeleccionar: (ruta) {
        _seleccionarSeccion(ruta);
        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      },
    );
  }
}
