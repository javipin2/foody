import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/mesas_grid_widget.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/pedidos_kanban_widget.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';

/// Flujo mesero (A-MES-1…4) — mesas como pantalla principal + pedidos activos.
class PanelMeseroScreen extends StatefulWidget {
  const PanelMeseroScreen({super.key});

  @override
  State<PanelMeseroScreen> createState() => _PanelMeseroScreenState();
}

class _PanelMeseroScreenState extends State<PanelMeseroScreen> {
  SesionStaff? _sesion;
  int _tab = 0;
  bool _cargando = true;

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
    setState(() {
      _sesion = sesion;
      _cargando = false;
    });
  }

  Future<void> _cerrarSesion() async {
    await AuthRepository().logout();
    if (mounted) context.go('/splash');
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
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_outlined),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      body: sid == null
          ? const Center(
              child: Text('Sin sucursal asignada. Contacta al administrador.'),
            )
          : _tab == 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _leyendaMesas(),
                    Expanded(
                      child: MesasGridWidget(
                        key: ValueKey('mesas-$sid'),
                        sucursalId: sid,
                        modoMesero: true,
                        meseraUsuarioId: meseraId,
                      ),
                    ),
                  ],
                )
              : PedidosKanbanWidget(
                  key: ValueKey('kanban-$sid'),
                  sucursalId: sid,
                  modoMesero: true,
                ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        indicatorColor: ColoresFoody.primario.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _tab = i),
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
      ),
    );
  }

  Widget _leyendaMesas() {
    Widget chip(Color color, String texto) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 11)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          chip(ColoresFoody.exito, 'Libre · toca para pedir'),
          chip(ColoresFoody.primario, 'Ocupada'),
          chip(const Color(0xFFFF9800), 'QR por confirmar'),
          chip(ColoresFoody.secundario, 'Listo en cocina'),
        ],
      ),
    );
  }
}
