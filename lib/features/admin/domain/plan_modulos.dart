/// Mapeo ruta sidebar → módulo comercial (docs/PLANES_SUSCRIPCION.md).
class PlanModulosFoody {
  PlanModulosFoody._();

  static const modulosPorRuta = <String, String>{
    'insumos': 'inventario',
    'costos_margenes': 'costeo',
    'cocinas': 'cocina',
    'cocina_kds': 'cocina',
    'domiciliarios': 'domiciliarios',
    'zonas': 'zonas_domicilio',
    'reportes': 'reportes',
    'analitica': 'analitica',
    'facturacion': 'facturacion',
  };

  static const planMinimoPorModulo = <String, String>{
    'inventario': 'gratis',
    'costeo': 'gratis',
    'cocina': 'gratis',
    'domiciliarios': 'gratis',
    'zonas_domicilio': 'gratis',
    'reportes': 'gratis',
    'analitica': 'pro',
    'facturacion': 'enterprise',
  };

  static const beneficioPorRuta = <String, String>{
    'insumos': 'Controla stock de insumos y evita quiebres en hora pico.',
    'costos_margenes':
        'Ve el margen real de cada plato y cuánto pierdes si sube un insumo.',
    'cocinas': 'Organiza cocinas e impresoras por estación.',
    'cocina_kds': 'Pantalla de cocina en tiempo real para no perder pedidos.',
    'domiciliarios': 'Asigna repartidores y sigue entregas desde el panel.',
    'zonas': 'Cobra domicilio por zona y distancia automáticamente.',
    'reportes': 'Cuadre de caja y reportes para decidir con datos.',
    'analitica': 'KPIs, gráficas y riesgo operativo en un solo lugar.',
    'facturacion': 'Emite facturación electrónica desde Foody.',
  };

  static String? moduloPorRuta(String ruta) => modulosPorRuta[ruta];

  static String? planMinimoPorRuta(String ruta) {
    final modulo = moduloPorRuta(ruta);
    if (modulo == null) return null;
    return planMinimoPorModulo[modulo];
  }

  static String beneficioUpgrade(String ruta) {
    return beneficioPorRuta[ruta] ??
        'Desbloquea herramientas para crecer sin perder control.';
  }

  static bool rutaPermitidaPorPlan(String ruta, List<String> modulosPlan) {
    final modulo = modulosPorRuta[ruta];
    if (modulo == null) return true;
    return modulosPlan.contains(modulo);
  }
}
