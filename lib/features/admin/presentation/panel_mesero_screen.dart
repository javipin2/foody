import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/banner_qr_pendientes.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/pedidos_kanban_widget.dart';

/// Flujo mesero — Mesas + Pedidos (NAV-MS shell paridad cajero).
class PanelMeseroScreen extends StatefulWidget {
  const PanelMeseroScreen({
    super.key,
    this.mesaIdInicial,
    this.pedidoIdInicial,
    this.tabInicial = 0,
  });

  final String? mesaIdInicial;
  final String? pedidoIdInicial;
  final int tabInicial;

  @override
  State<PanelMeseroScreen> createState() => _PanelMeseroScreenState();
}

class _PanelMeseroScreenState extends State<PanelMeseroScreen> {
  SesionStaff? _sesion;
  int _tab = 0;
  bool _cargando = true;
  int _refreshTick = 0;
  String? _mesaFocusId;
  String? _pedidoFocusId;

  String? get _sucursalId => _sesion?.sucursalId;

  @override
  void initState() {
    super.initState();
    _tab = widget.tabInicial.clamp(0, 1);
    _mesaFocusId = widget.mesaIdInicial;
    _pedidoFocusId = widget.pedidoIdInicial;
    if (_pedidoFocusId != null && _pedidoFocusId!.isNotEmpty) {
      _tab = 1;
    } else if (_mesaFocusId != null && _mesaFocusId!.isNotEmpty) {
      _tab = 0;
    }
    _inicializar();
  }

  Future<void> _inicializar() async {
    final sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    if (sesion == null) {
      context.go('/admin/login');
      return;
    }
    setState(() {
      _sesion = sesion;
      _cargando = false;
    });
  }

  Future<void> _cerrarSesion() async {
    await cerrarSesionStaff(context);
  }

  void _irAMesa(String mesaId) {
    setState(() {
      _tab = 0;
      _mesaFocusId = mesaId;
      _refreshTick++;
    });
  }

  void _seleccionarTab(int i) {
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _sesion?.usuario['nombre'] as String? ?? 'Mesero';
    final meseraId = _sesion?.usuario['id'] as String?;
    final sid = _sucursalId;
    final ancho = MediaQuery.sizeOf(context).width;
    // NAV-MS-02: tabs arriba en tablet/PC (paridad NAV-CJ-06).
    final navSuperior = FoodyBreakpoints.esExpanded(ancho);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tab == 0 ? 'Mesas' : 'Pedidos',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              '$nombre · ${etiquetaRolStaff(_sesion?.rol)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {
              _mesaFocusId = null;
              _pedidoFocusId = null;
              _refreshTick++;
            }),
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
              color: Colors.white,
              child: _navBar(),
            ),
          Expanded(
            child: sid == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_outlined,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Sin sucursal asignada. Contacta al administrador.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: _cerrarSesion,
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _tab == 0
                    ? MesasGridWidget(
                        key: ValueKey('mesas-$sid-$_refreshTick-$_mesaFocusId'),
                        sucursalId: sid,
                        modoMesero: true,
                        meseraUsuarioId: meseraId,
                        ocultarCabecera: true,
                        mesaIdInicial: _mesaFocusId,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BannerQrPendientes(
                            sucursalId: sid,
                            onRevisar: () {
                              setState(() {
                                _tab = 0;
                                _mesaFocusId = null;
                                _refreshTick++;
                              });
                            },
                          ),
                          Expanded(
                            child: PedidosKanbanWidget(
                              key: ValueKey(
                                'kanban-$sid-$_refreshTick-$_pedidoFocusId',
                              ),
                              sucursalId: sid,
                              modoMesero: true,
                              meseraUsuarioId: meseraId,
                              ocultarCabecera: true,
                              pedidoIdInicial: _pedidoFocusId,
                              onPedidoAbierto: () {
                                if (_pedidoFocusId != null) {
                                  setState(() => _pedidoFocusId = null);
                                }
                              },
                              onVerMesa: _irAMesa,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: navSuperior ? null : _navBar(),
    );
  }

  Widget _navBar() {
    return NavigationBar(
      selectedIndex: _tab,
      height: 64,
      indicatorColor: ColoresFoody.primario.withValues(alpha: 0.15),
      onDestinationSelected: _seleccionarTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.table_restaurant_outlined),
          selectedIcon: Icon(Icons.table_restaurant),
          label: 'Mesas',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Pedidos',
        ),
      ],
    );
  }
}
