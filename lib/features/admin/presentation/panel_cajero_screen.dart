import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/caja/data/caja_repository.dart';
import 'package:reserva_canchas/features/caja/presentation/caja_admin_screen.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';

/// Flujo cajero (A-CAJ-1…5) — POS + mesas + caja con apertura obligatoria.
class PanelCajeroScreen extends StatefulWidget {
  const PanelCajeroScreen({super.key});

  @override
  State<PanelCajeroScreen> createState() => _PanelCajeroScreenState();
}

class _PanelCajeroScreenState extends State<PanelCajeroScreen> {
  final _cajaRepo = CajaRepository();

  /// Fuerza recarga de tabs al pulsar refresh (NAV-CJ-05).
  int _refreshTick = 0;
  SesionStaff? _sesion;
  int _tab = 0;
  bool _cargando = true;
  bool _cajaAbierta = false;

  String? get _sucursalId => _sesion?.sucursalId;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    if (sesion == null) {
      context.go('/admin/login');
      return;
    }
    setState(() => _sesion = sesion);
    await _verificarCaja();
  }

  Future<void> _verificarCaja() async {
    final sid = _sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _cajaAbierta = false;
      });
      return;
    }
    setState(() => _cargando = true);
    try {
      final caja = await _cajaRepo.cajaActiva(sid);
      if (!mounted) return;
      setState(() {
        _cajaAbierta = caja != null;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cajaAbierta = false;
        _cargando = false;
      });
    }
  }

  void _onCajaEstadoCambiado(bool abierta) {
    setState(() {
      _cajaAbierta = abierta;
      // NAV-CJ-02/04: tras abrir → POS; tras cerrar → Caja.
      if (abierta) _tab = 0;
    });
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesionStaff(context);
  }

  String get _tituloTab {
    switch (_tab) {
      case 0:
        return 'Punto de venta';
      case 1:
        return 'Mesas';
      default:
        return 'Caja y turno';
    }
  }

  void _seleccionarTab(int i) {
    if (!_cajaAbierta && i != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Abre la caja en la pestaña Caja para usar POS o Mesas',
          ),
        ),
      );
      // NAV-CJ-03
      setState(() => _tab = 2);
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _sesion?.usuario['nombre'] as String? ?? 'Cajero';
    final rol = etiquetaRolStaff(_sesion?.rol);
    final ancho = MediaQuery.sizeOf(context).width;
    final scheme = Theme.of(context).colorScheme;
    // NAV-CJ-06 / RS-20: tabs arriba desde FoodyBreakpoints.expanded.
    final navSuperior = FoodyBreakpoints.esExpanded(ancho);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tituloTab,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              '$nombre · $rol',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (!_cajaAbierta)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Caja cerrada',
                child: Icon(
                  Icons.lock_outline,
                  color: Colors.orange.shade800,
                  size: 22,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _refreshTick++);
              unawaited(_verificarCaja());
            },
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: Column(
        children: [
          if (navSuperior)
            Material(
              color: scheme.surface,
              elevation: 0,
              child: _navBar(),
            ),
          Expanded(child: _contenido()),
        ],
      ),
      bottomNavigationBar: navSuperior ? null : _navBar(),
    );
  }

  Widget _navBar() {
    return OperacionRoleNavBar(
      selectedIndex: _tab,
      onDestinationSelected: _seleccionarTab,
      compactTop: FoodyBreakpoints.esExpanded(MediaQuery.sizeOf(context).width),
      destinations: const [
        OperacionRoleNavItem(
          icon: Icons.point_of_sale_outlined,
          selectedIcon: Icons.point_of_sale,
          label: 'POS',
        ),
        OperacionRoleNavItem(
          icon: Icons.table_restaurant_outlined,
          selectedIcon: Icons.table_restaurant,
          label: 'Mesas',
        ),
        OperacionRoleNavItem(
          icon: Icons.account_balance_wallet_outlined,
          selectedIcon: Icons.account_balance_wallet,
          label: 'Caja',
        ),
      ],
    );
  }

  Widget _contenido() {
    final sid = _sucursalId;
    if (sid == null) {
      return const Center(
        child: Text(
          'Tu usuario no tiene sucursal asignada. Contacta al administrador.',
        ),
      );
    }

    if (_tab == 2) {
      return CajaAdminScreen(
        key: ValueKey('caja-$sid-$_refreshTick'),
        sucursalId: sid,
        ocultarCabecera: true,
        permitirArqueoCiego: false,
        onCajaEstadoCambiado: _onCajaEstadoCambiado,
        onRevisarOperaciones: () => _seleccionarTab(1),
        etiquetaAccionTurnoLargo: 'Ver mesas',
        textoAvisoTurnoLargo:
            'Revisa las mesas y cuentas abiertas antes de cerrar.',
        onIrPedido: (pedidoId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Pedido $pedidoId — búscalo en Mesas (cuenta abierta)',
              ),
              action: SnackBarAction(
                label: 'Mesas',
                onPressed: () {
                  if (_cajaAbierta) setState(() => _tab = 1);
                },
              ),
            ),
          );
        },
      );
    }

    if (!_cajaAbierta) {
      return _pantallaAperturaObligatoria(sid);
    }

    if (_tab == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Text(
              'Toca una mesa libre para registrar consumo o una ocupada para cobrar. '
              'Los pedidos QR los aprueba un mesero.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: MesasGridWidget(
              key: ValueKey('mesas-cajero-$sid-$_refreshTick'),
              sucursalId: sid,
              modoCajero: true,
              ocultarCabecera: true,
            ),
          ),
        ],
      );
    }

    return PedidoCajeroScreen(
      key: ValueKey('pos-$sid-$_refreshTick'),
      sucursalId: sid,
      ocultarCabecera: true,
    );
  }

  Widget _pantallaAperturaObligatoria(String sucursalId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColoresFoody.primario.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ColoresFoody.primario.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_clock,
                  color: ColoresFoody.primario, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Abre la caja para vender',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Antes de tomar pedidos o cobrar mesas debes abrir turno con el monto inicial en efectivo.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: CajaAdminScreen(
            key: ValueKey('apertura-$sucursalId'),
            sucursalId: sucursalId,
            ocultarCabecera: true,
            permitirArqueoCiego: false,
            onCajaEstadoCambiado: _onCajaEstadoCambiado,
          ),
        ),
      ],
    );
  }
}
