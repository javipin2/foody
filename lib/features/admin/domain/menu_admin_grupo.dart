import 'package:flutter/material.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';

/// Agrupación lógica del menú admin (acordeones colapsables).
class MenuAdminGrupo {
  const MenuAdminGrupo({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.rutas,
  });

  final String id;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  /// Orden de rutas dentro del grupo.
  final List<String> rutas;
}

class MenuAdminGrupoData {
  static const definicion = [
    MenuAdminGrupo(
      id: 'inicio',
      titulo: 'Inicio',
      subtitulo: 'Resumen del día',
      icono: Icons.home_outlined,
      rutas: ['dashboard'],
    ),
    MenuAdminGrupo(
      id: 'operacion',
      titulo: 'Operación',
      subtitulo: 'Pedidos, caja y mesas',
      icono: Icons.receipt_long_outlined,
      rutas: ['pedidos', 'nuevo_pedido', 'caja', 'mesas'],
    ),
    MenuAdminGrupo(
      id: 'menu_inventario',
      titulo: 'Menú e inventario',
      subtitulo: 'Carta, insumos y costos',
      icono: Icons.restaurant_menu_outlined,
      rutas: ['menu', 'insumos', 'costos_margenes', 'promociones'],
    ),
    MenuAdminGrupo(
      id: 'cocina',
      titulo: 'Cocina',
      subtitulo: 'KDS e impresoras',
      icono: Icons.soup_kitchen_outlined,
      rutas: ['cocinas', 'cocina_kds'],
    ),
    MenuAdminGrupo(
      id: 'domicilio',
      titulo: 'Domicilio',
      subtitulo: 'Reparto y zonas',
      icono: Icons.delivery_dining_outlined,
      rutas: ['domiciliarios', 'zonas'],
    ),
    MenuAdminGrupo(
      id: 'sucursal',
      titulo: 'Sucursal',
      subtitulo: 'Sedes y horarios',
      icono: Icons.store_outlined,
      rutas: ['sucursales', 'horarios'],
    ),
    MenuAdminGrupo(
      id: 'finanzas',
      titulo: 'Finanzas',
      subtitulo: 'Reportes, gastos, plan y facturación',
      icono: Icons.account_balance_wallet_outlined,
      rutas: ['reportes', 'analitica', 'finanzas', 'facturacion', 'mejorar_plan'],
    ),
    MenuAdminGrupo(
      id: 'equipo',
      titulo: 'Equipo',
      subtitulo: 'Usuarios y permisos',
      icono: Icons.people_outline_rounded,
      rutas: ['usuarios'],
    ),
    MenuAdminGrupo(
      id: 'sistema',
      titulo: 'Sistema',
      subtitulo: 'Alertas',
      icono: Icons.notifications_outlined,
      rutas: ['alertas'],
    ),
  ];

  /// Grupos con ítems filtrados por permisos; omite grupos vacíos.
  static List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> construir(
    List<String> permisos, {
    List<String> modulosPlan = const [],
    String? planActual,
    String? rol,
  }) {
    final items = MenuAdminDinamico.construir(
      permisos,
      modulosPlan: modulosPlan,
    );
    // Banner gratis = CTA urgente; «Plan y pagos» en Finanzas = entrada permanente
    // (sin banner, en Pro/Enterprise no había forma de abrir la pantalla).
    final todos = [...items];
    final porRuta = {for (final i in todos) i.ruta: i};
    final resultado =
        <({MenuAdminGrupo grupo, List<MenuAdminItem> items})>[];

    for (final grupo in definicion) {
      final hijos = <MenuAdminItem>[];
      for (final ruta in grupo.rutas) {
        final item = porRuta[ruta];
        if (item != null) hijos.add(item);
      }
      if (hijos.isNotEmpty) {
        resultado.add((grupo: grupo, items: hijos));
      }
    }

    // Ítems huérfanos (rutas nuevas sin grupo definido).
    final rutasEnGrupo = definicion
        .expand((g) => g.rutas)
        .toSet();
    final huerfanos = items.where((i) => !rutasEnGrupo.contains(i.ruta)).toList();
    if (huerfanos.isNotEmpty) {
      resultado.add((
        grupo: const MenuAdminGrupo(
          id: 'otros',
          titulo: 'Más',
          subtitulo: 'Otros módulos',
          icono: Icons.more_horiz_rounded,
          rutas: [],
        ),
        items: huerfanos,
      ));
    }

    return resultado;
  }

  /// Id del grupo que contiene [ruta], o null.
  static String? grupoIdParaRuta(String ruta) {
    for (final g in definicion) {
      if (g.rutas.contains(ruta)) return g.id;
    }
    if (ruta.isNotEmpty) return 'otros';
    return null;
  }
}
