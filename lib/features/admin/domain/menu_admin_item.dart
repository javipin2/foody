import 'package:flutter/material.dart';

import 'package:reserva_canchas/features/admin/domain/plan_modulos.dart';

class MenuAdminItem {
  const MenuAdminItem({
    required this.permiso,
    required this.titulo,
    required this.icono,
    required this.ruta,
    this.bloqueadoPorPlan = false,
    this.planMinimo,
    this.beneficioUpgrade,
  });

  final String permiso;
  final String titulo;
  final IconData icono;
  final String ruta;
  final bool bloqueadoPorPlan;
  final String? planMinimo;
  final String? beneficioUpgrade;
}

class MenuAdminDinamico {
  static List<MenuAdminItem> construir(
    List<String> permisos, {
    List<String> modulosPlan = const [],
  }) {
    const catalogo = [
      MenuAdminItem(
        permiso: 'configurar_establecimiento',
        titulo: 'Configuración',
        icono: Icons.settings_outlined,
        ruta: 'configuracion',
      ),
      MenuAdminItem(
        permiso: 'ver_dashboard',
        titulo: 'Dashboard',
        icono: Icons.dashboard_rounded,
        ruta: 'dashboard',
      ),
      MenuAdminItem(
        permiso: 'ver_pedidos',
        titulo: 'Pedidos',
        icono: Icons.receipt_long_rounded,
        ruta: 'pedidos',
      ),
      MenuAdminItem(
        permiso: 'crear_pedido',
        titulo: 'Nuevo pedido',
        icono: Icons.add_shopping_cart_rounded,
        ruta: 'nuevo_pedido',
      ),
      MenuAdminItem(
        permiso: 'editar_productos',
        titulo: 'Menú',
        icono: Icons.restaurant_menu_rounded,
        ruta: 'menu',
      ),
      MenuAdminItem(
        permiso: 'editar_productos',
        titulo: 'Config. cocinas e impresoras',
        icono: Icons.soup_kitchen_rounded,
        ruta: 'cocinas',
      ),
      MenuAdminItem(
        permiso: 'ver_cocina',
        titulo: 'Cocina en vivo (KDS)',
        icono: Icons.kitchen_rounded,
        ruta: 'cocina_kds',
      ),
      MenuAdminItem(
        permiso: 'gestionar_sucursales',
        titulo: 'Mis sucursales',
        icono: Icons.store_mall_directory_outlined,
        ruta: 'sucursales',
      ),
      MenuAdminItem(
        permiso: 'gestionar_sucursales',
        titulo: 'Zonas de domicilio',
        icono: Icons.map_outlined,
        ruta: 'zonas',
      ),
      MenuAdminItem(
        permiso: 'gestionar_sucursales',
        titulo: 'Horarios',
        icono: Icons.schedule_outlined,
        ruta: 'horarios',
      ),
      MenuAdminItem(
        permiso: 'ver_inventario',
        titulo: 'Insumos',
        icono: Icons.inventory_2_rounded,
        ruta: 'insumos',
      ),
      MenuAdminItem(
        permiso: 'ver_inventario',
        titulo: 'Costos y márgenes',
        icono: Icons.pie_chart_outline_rounded,
        ruta: 'costos_margenes',
      ),
      MenuAdminItem(
        permiso: 'gestionar_domiciliarios',
        titulo: 'Gestionar repartidores',
        icono: Icons.delivery_dining_rounded,
        ruta: 'domiciliarios',
      ),
      MenuAdminItem(
        permiso: 'ver_caja',
        titulo: 'Caja',
        icono: Icons.point_of_sale_rounded,
        ruta: 'caja',
      ),
      MenuAdminItem(
        permiso: 'gestionar_mesas',
        titulo: 'Mesas',
        icono: Icons.table_restaurant_rounded,
        ruta: 'mesas',
      ),
      MenuAdminItem(
        permiso: 'ver_analitica',
        titulo: 'Análisis (insights)',
        icono: Icons.insights_rounded,
        ruta: 'analitica',
      ),
      MenuAdminItem(
        permiso: 'ver_finanzas',
        titulo: 'Gastos y nómina',
        icono: Icons.account_balance_outlined,
        ruta: 'finanzas',
      ),
      MenuAdminItem(
        permiso: 'ver_reportes',
        titulo: 'Reportes (exportar)',
        icono: Icons.bar_chart_rounded,
        ruta: 'reportes',
      ),
      MenuAdminItem(
        permiso: 'ver_facturacion',
        titulo: 'Facturas internas',
        icono: Icons.receipt_rounded,
        ruta: 'facturacion',
      ),
      // Visible siempre al admin: en Pro el banner gratis desaparece y sin esto no hay entrada.
      MenuAdminItem(
        permiso: 'gestionar_usuarios',
        titulo: 'Plan y pagos',
        icono: Icons.workspace_premium_outlined,
        ruta: 'mejorar_plan',
      ),
      MenuAdminItem(
        permiso: 'ver_alertas',
        titulo: 'Alertas',
        icono: Icons.warning_amber_rounded,
        ruta: 'alertas',
      ),
      MenuAdminItem(
        permiso: 'editar_productos',
        titulo: 'Promociones',
        icono: Icons.auto_awesome_outlined,
        ruta: 'promociones',
      ),
      MenuAdminItem(
        permiso: 'gestionar_usuarios',
        titulo: 'Usuarios',
        icono: Icons.people_rounded,
        ruta: 'usuarios',
      ),
    ];

    const orden = [
      'dashboard',
      'configuracion',
      'pedidos',
      'nuevo_pedido',
      'menu',
      'insumos',
      'costos_margenes',
      'cocinas',
      'cocina_kds',
      'sucursales',
      'zonas',
      'horarios',
      'domiciliarios',
      'caja',
      'mesas',
      'reportes',
      'analitica',
      'finanzas',
      'facturacion',
      'mejorar_plan',
      'alertas',
      'promociones',
      'usuarios',
    ];

    final filtrados = catalogo.where((i) {
      if (i.ruta == 'configuracion') {
        return permisos.any(const {
          'gestionar_sucursales',
          'editar_productos',
          'gestionar_usuarios',
        }.contains);
      }
      if (i.ruta == 'analitica') {
        return permisos.contains('ver_analitica') ||
            permisos.contains('ver_reportes');
      }
      return permisos.contains(i.permiso);
    }).map((i) {
      if (i.ruta == 'configuracion') return i;
      if (PlanModulosFoody.rutaPermitidaPorPlan(i.ruta, modulosPlan)) {
        return i;
      }
      final planMin = PlanModulosFoody.planMinimoPorRuta(i.ruta);
      if (planMin == null) return i;
      return MenuAdminItem(
        permiso: i.permiso,
        titulo: i.titulo,
        icono: i.icono,
        ruta: i.ruta,
        bloqueadoPorPlan: true,
        planMinimo: planMin,
        beneficioUpgrade: PlanModulosFoody.beneficioUpgrade(i.ruta),
      );
    }).toList();
    int idx(String ruta) {
      final i = orden.indexOf(ruta);
      return i < 0 ? 999 : i;
    }

    filtrados.sort((a, b) => idx(a.ruta).compareTo(idx(b.ruta)));
    return filtrados;
  }
}
