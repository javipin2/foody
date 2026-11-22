/// Metadatos de planes comerciales (UI; precios vienen del API en checkout).
class PlanesComercialesFoody {
  PlanesComercialesFoody._();

  static const orden = ['gratis', 'basico', 'pro', 'enterprise'];

  static const nombres = {
    'gratis': 'Gratis',
    'basico': 'Básico',
    'pro': 'Pro',
    'enterprise': 'Enterprise',
  };

  /// Precios mensuales COP (referencia UI; checkout usa centavos del backend).
  static const preciosCop = {
    'basico': 50000,
    'pro': 100000,
    'enterprise': 130000,
  };

  static const modulosPorPlan = {
    'gratis': <String>[
      'Menú, pedidos, caja y mesas QR',
      'Inventario, costeo y cocina (con límites)',
      'Hasta 2 mesas · 5 productos · 5 insumos · 2 usuarios',
    ],
    'basico': <String>[
      'Todo lo gratis',
      'Más usuarios y operación estable',
      'Hasta 1 sucursal · 8 usuarios',
    ],
    'pro': <String>[
      'Todo lo gratis sin límites operativos',
      'Inventario y costeo (márgenes reales)',
      'Cocina KDS e impresoras',
      'Domicilios y zonas',
      'Reportes avanzados',
      'Hasta 3 sucursales · 25 usuarios',
    ],
    'enterprise': <String>[
      'Todo Pro',
      'Facturación electrónica',
      'Sucursales ilimitadas',
    ],
  };

  static String nombre(String plan) => nombres[plan] ?? plan;

  static int nivel(String plan) {
    final i = orden.indexOf(plan);
    return i < 0 ? 0 : i;
  }

  static bool planCubre(String planActual, String planRequerido) {
    return nivel(planActual) >= nivel(planRequerido);
  }

  /// Planes de pago disponibles para checkout (excluye gratis).
  static const planesPago = ['basico', 'pro', 'enterprise'];
}
