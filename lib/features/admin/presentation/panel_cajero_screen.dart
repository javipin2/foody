import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
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

  Future<void> _cerrarSesion() async {
    await AuthRepository().logout();
    if (mounted) context.go('/splash');
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _sesion?.usuario['nombre'] as String? ?? 'Cajero';
    final rol = etiquetaRolStaff(_sesion?.rol);

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
              _tituloTab,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            Text(
              '$nombre · $rol',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          if (!_cajaAbierta)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Caja cerrada', style: TextStyle(fontSize: 11)),
                backgroundColor: Colors.orange.shade50,
                side: BorderSide(color: Colors.orange.shade200),
                padding: EdgeInsets.zero,
              ),
            ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _verificarCaja,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: _contenido(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        indicatorColor: ColoresFoody.primario.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.table_restaurant_outlined),
            selectedIcon: Icon(Icons.table_restaurant),
            label: 'Mesas',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Caja',
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    final sid = _sucursalId;
    if (sid == null) {
      return const Center(
        child: Text('Tu usuario no tiene sucursal asignada. Contacta al administrador.'),
      );
    }

    if (_tab == 2) {
      return CajaAdminScreen(
        key: ValueKey('caja-$sid'),
        sucursalId: sid,
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
              'Toca una mesa libre para registrar consumo o una ocupada para ver cuenta y cobrar. '
              'El turno de mesas lo llevan los meseros.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Expanded(
            child: MesasGridWidget(
              key: ValueKey('mesas-cajero-$sid'),
              sucursalId: sid,
              modoCajero: true,
            ),
          ),
        ],
      );
    }

    return PedidoCajeroScreen(
      key: ValueKey('pos-$sid'),
      sucursalId: sid,
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
            border: Border.all(color: ColoresFoody.primario.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_clock, color: ColoresFoody.primario, size: 32),
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
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
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
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _verificarCaja,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Ya abrí la caja — continuar'),
          ),
        ),
      ],
    );
  }
}
