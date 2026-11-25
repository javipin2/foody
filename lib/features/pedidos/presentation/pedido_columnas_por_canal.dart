/// Columnas y CTAs del kanban según canal (mesa / llevar / domicilio / todos).
class PedidoColumnaDef {
  const PedidoColumnaDef({
    required this.clave,
    required this.titulo,
    this.estados = const [],
  });

  /// Clave usada en el mapa de agrupación.
  final String clave;
  final String titulo;

  /// Estados que caen en esta columna (vacío = solo [clave]).
  final List<String> estados;

  bool contieneEstado(String estadoKanban) {
    if (estados.isEmpty) return estadoKanban == clave;
    return estados.contains(estadoKanban);
  }
}

class PedidoColumnasPorCanal {
  PedidoColumnasPorCanal._();

  static const domicilio = [
    PedidoColumnaDef(clave: 'pendiente', titulo: 'Pendientes'),
    PedidoColumnaDef(clave: 'en_cocina', titulo: 'En preparación'),
    PedidoColumnaDef(clave: 'listo', titulo: 'Listos'),
    PedidoColumnaDef(clave: 'asignado', titulo: 'Asignados'),
    PedidoColumnaDef(clave: 'en_camino', titulo: 'En camino'),
    PedidoColumnaDef(
      clave: 'por_cobrar',
      titulo: 'Entregados · por cobrar',
      estados: ['entregado'],
    ),
  ];

  /// Vista «Todos»: pestañas compactas.
  static const todos = [
    PedidoColumnaDef(
      clave: 'pendiente',
      titulo: 'Pendientes',
      estados: ['pendiente', 'pendiente_aprobacion'],
    ),
    PedidoColumnaDef(clave: 'en_cocina', titulo: 'En preparación'),
    PedidoColumnaDef(clave: 'listo', titulo: 'Listos'),
    PedidoColumnaDef(
      clave: 'cobro_ruta',
      titulo: 'Cobro / Ruta',
      estados: ['pagando', 'asignado', 'en_camino'],
    ),
    PedidoColumnaDef(
      clave: 'por_cobrar',
      titulo: 'Por cobrar',
      estados: ['entregado'],
    ),
  ];

  static const mesero = [
    PedidoColumnaDef(clave: 'pendiente_aprobacion', titulo: 'Por confirmar'),
    PedidoColumnaDef(clave: 'en_cocina', titulo: 'Preparando'),
    PedidoColumnaDef(clave: 'listo', titulo: 'Listos'),
    PedidoColumnaDef(clave: 'pagando', titulo: 'Pagando'),
  ];

  static const mesa = [
    PedidoColumnaDef(clave: 'pendiente_aprobacion', titulo: 'Pendientes QR'),
    PedidoColumnaDef(clave: 'en_cocina', titulo: 'En preparación'),
    PedidoColumnaDef(clave: 'listo', titulo: 'Listos'),
    PedidoColumnaDef(clave: 'pagando', titulo: 'Pagando'),
  ];

  static const paraLlevar = [
    PedidoColumnaDef(
      clave: 'pendiente',
      titulo: 'Pendientes',
      estados: ['pendiente', 'pendiente_aprobacion'],
    ),
    PedidoColumnaDef(clave: 'en_cocina', titulo: 'En preparación'),
    PedidoColumnaDef(clave: 'listo', titulo: 'Listo / Recoger'),
    PedidoColumnaDef(clave: 'pagando', titulo: 'Pagando'),
  ];

  /// Tab virtual de cerrados (datos de cerrados-hoy).
  static const cerradosClave = 'cerrados_hoy';
  static const cerrados = PedidoColumnaDef(
    clave: cerradosClave,
    titulo: 'Cerrados',
  );

  static List<PedidoColumnaDef> para({
    required String filtroTipo,
    required bool modoMesero,
  }) {
    if (modoMesero) return mesero;
    return switch (filtroTipo) {
      'mesa' => mesa,
      'para_llevar' => paraLlevar,
      'domicilio' => domicilio,
      _ => todos,
    };
  }

  /// Tabs de estado + Cerrados (vista principal).
  static List<PedidoColumnaDef> tabsConCerrados({
    required String filtroTipo,
    required bool modoMesero,
  }) =>
      [...para(filtroTipo: filtroTipo, modoMesero: modoMesero), cerrados];

  /// Clave de columna para un estado kanban dado el set de columnas.
  static String claveColumna(
    String estadoKanban,
    List<PedidoColumnaDef> columnas,
  ) {
    for (final c in columnas) {
      if (c.contieneEstado(estadoKanban)) return c.clave;
    }
    return estadoKanban;
  }
}
