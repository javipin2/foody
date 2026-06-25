import 'package:reserva_canchas/core/rutas/ruta_mesa_util.dart';

/// Variante de app compilada (mismo repo, distinto listing en stores).
///
/// Solo **dos** apps publicables:
/// - [cliente] — consumidor final
/// - [equipo] — dueño, domiciliario, cajero, mesero, cocina (mismo APK)
///
/// Build: `--dart-define=APP_FLAVOR=cliente|equipo`
/// Android: `--flavor cliente|equipo`
/// Ver [INFRAESTRUCTURA/foody_multi_app_flavors.md].
enum AppFlavor {
  /// Público: ciudades, menú, carrito, pedidos, mesa QR.
  cliente('cliente', 'Foody', 'app.foody.cliente'),

  /// Operación: dueño, repartidor, staff de sede (login y panel según rol).
  equipo('equipo', 'Foody Equipo', 'app.foody.equipo');

  const AppFlavor(this.id, this.nombreVisible, this.applicationId);

  final String id;
  final String nombreVisible;

  /// Android applicationId / iOS bundle identifier de esta variante.
  final String applicationId;

  static const String _raw =
      String.fromEnvironment('APP_FLAVOR', defaultValue: 'cliente');

  /// Valor activo en este build (por defecto [cliente] en desarrollo).
  static AppFlavor get actual => _porId(_raw);

  static AppFlavor _porId(String id) {
    // Alias legacy → equipo (una sola app operativa).
    const aliasEquipo = {'domiciliario', 'dueno', 'staff'};
    final normalizado = aliasEquipo.contains(id) ? 'equipo' : id;
    for (final flavor in AppFlavor.values) {
      if (flavor.id == normalizado) return flavor;
    }
    return AppFlavor.cliente;
  }

  bool get esCliente => this == AppFlavor.cliente;
  bool get esEquipo => this == AppFlavor.equipo;

  /// Ruta inicial de go_router (sin deep link web).
  String get rutaInicial {
    switch (this) {
      case AppFlavor.cliente:
        return '/splash';
      case AppFlavor.equipo:
        return '/admin/login';
    }
  }

  /// Si la ruta pertenece al flujo público del cliente.
  bool esRutaCliente(String path) {
    if (path == '/splash' || path == '/cliente') return true;
    if (path.startsWith('/cliente/')) return true;
    if (path.startsWith('/ciudades/')) return true;
    if (path.startsWith('/restaurantes/')) return true;
    if (path.startsWith('/menu/')) return true;
    if (path.startsWith('/carrito/')) return true;
    if (path.startsWith('/checkout/')) return true;
    if (path.startsWith('/pedidos/') && path.contains('/seguimiento')) {
      return true;
    }
    if (RutaMesaUtil.esEntradaMesa(path)) return true;
    return false;
  }

  /// Rutas de dueño, staff de sede y domiciliarios.
  bool esRutaEquipo(String path) {
    if (path.startsWith('/admin')) return true;
    if (path.startsWith('/domiciliario')) return true;
    return false;
  }

  /// Bloqueo cruzado entre apps en el mismo binario compilado.
  String? redirigirSiRutaProhibida(String path) {
    if (esCliente && esRutaEquipo(path)) return rutaInicial;
    if (esEquipo && esRutaCliente(path)) return rutaInicial;
    return null;
  }
}
