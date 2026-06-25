/// Conversión de unidades alineada con `foody_backend/.../unidad-costeo.util.ts`.
String normalizarUnidadCosteo(String unidad) {
  final u = unidad.trim().toLowerCase();
  const map = {
    'gr': 'g',
    'g': 'g',
    'gramo': 'g',
    'gramos': 'g',
    'kg': 'kg',
    'kilo': 'kg',
    'kilogramo': 'kg',
    'ml': 'ml',
    'mililitro': 'ml',
    'l': 'L',
    'lt': 'L',
    'litro': 'L',
    'litros': 'L',
    'und': 'und',
    'un': 'und',
    'unidad': 'und',
    'unidades': 'und',
  };
  return map[u] ?? u;
}

const _grupoPeso = {'g', 'kg'};
const _grupoVolumen = {'ml', 'L'};

bool unidadesCosteoCompatibles(String unidadLinea, String unidadBase) {
  final a = normalizarUnidadCosteo(unidadLinea);
  final b = normalizarUnidadCosteo(unidadBase);
  if (a == b) return true;
  if (_grupoPeso.contains(a) && _grupoPeso.contains(b)) return true;
  if (_grupoVolumen.contains(a) && _grupoVolumen.contains(b)) return true;
  return false;
}

/// Convierte cantidad de [desde] hacia [hacia] (g↔kg, ml↔L).
double convertirCantidadCosteo(
  double cantidad,
  String desde,
  String hacia,
) {
  final d = normalizarUnidadCosteo(desde);
  final h = normalizarUnidadCosteo(hacia);
  if (d == h) return cantidad;
  if (d == 'kg' && h == 'g') return cantidad * 1000;
  if (d == 'g' && h == 'kg') return cantidad / 1000;
  if (d == 'L' && h == 'ml') return cantidad * 1000;
  if (d == 'ml' && h == 'L') return cantidad / 1000;
  return cantidad;
}

/// Alineado con `CosteoService.costoRealUnitario` (NestJS).
double costoRealUnitarioUi(double costoUnitario, double rendimientoPorcentaje) {
  final rend = rendimientoPorcentaje > 0 ? rendimientoPorcentaje : 100;
  return costoUnitario * (100 / rend);
}

/// Costo de una línea de receta (misma lógica que NestJS `costoLineaIngrediente`).
double costoLineaIngredienteUi({
  required double cantidad,
  required String unidadLinea,
  required String unidadBaseInsumo,
  required double costoUnitarioBase,
  double? rendimientoPorcentaje,
  double? pesoNeto,
}) {
  final cantidadBase = convertirCantidadCosteo(
    cantidad,
    unidadLinea,
    unidadBaseInsumo,
  );
  final modoMercado = pesoNeto != null && pesoNeto > 0;
  final costoRealUnit = modoMercado
      ? costoUnitarioBase
      : costoRealUnitarioUi(
          costoUnitarioBase,
          rendimientoPorcentaje ?? 100,
        );
  return costoRealUnit * cantidadBase;
}

/// Alineado con `CosteoService.calcularPrecioSugerido` (NestJS).
int calcularPrecioSugeridoUi(double costo, double margenObjetivoPct) {
  if (margenObjetivoPct >= 100) return (costo * 2).round();
  return (costo / (1 - margenObjetivoPct / 100)).round();
}

/// Precio unitario expresado en la unidad de la línea (ej. $/g si la receta usa g).
double costoUnitarioEnUnidadLinea({
  required String unidadLinea,
  required String unidadBaseInsumo,
  required double costoUnitarioBase,
}) {
  final factor = convertirCantidadCosteo(1, unidadLinea, unidadBaseInsumo);
  return costoUnitarioBase * factor;
}
