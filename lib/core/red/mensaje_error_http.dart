import 'package:dio/dio.dart';

/// Mensaje legible para errores HTTP (evita mostrar el stack de Dio al usuario).
String mensajeErrorHttp(Object error, {String contexto = 'operación'}) {
  final desdeExcepcion = _mensajeDesdeExcepcionDart(error);
  if (desdeExcepcion != null) return desdeExcepcion;

  if (error is DioException) {
    final codigo = error.response?.statusCode;
    switch (codigo) {
      case 401:
        if (error.requestOptions.path.contains('/auth/login')) {
          return 'Correo o contraseña incorrectos. Demo: admin@foody.demo / 123456 '
              '(super y domi en la misma pantalla; repartidor en enlace inferior).';
        }
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      case 403:
        final msg = error.response?.data;
        if (msg is Map) {
          if (msg['error'] == 'PLAN_NO_INCLUYE_MODULO' ||
              msg['error'] == 'PLAN_LIMITE_EXCEDIDO') {
            return msg['mensaje']?.toString() ??
                'Tu plan no incluye esta función. Contacta al administrador.';
          }
          if (msg['mensaje'] != null) {
            return '${msg['mensaje']} ($contexto). Si acabas de actualizar el sistema, cierra sesión y vuelve a entrar.';
          }
        }
        return 'No tienes permiso para $contexto. Cierra sesión y vuelve a entrar con admin@foody.demo.';
      case 404:
        final ruta = error.requestOptions.uri.path;
        return 'Ruta no encontrada en el API ($ruta). Detén el backend, ejecuta '
            'scripts\\iniciar-backend-wsl.bat (debe compilar sin errores) y recarga.';
      case 409:
        return 'El correo ya está registrado.';
      case 502:
      case 503:
        return 'El servidor no está disponible. Comprueba que la API esté encendida.';
      default:
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError) {
          return 'Sin conexión con el servidor. ¿Está la API en http://localhost:3000?';
        }
        final msg = error.response?.data;
        if (msg is Map) {
          if (msg['error'] == 'STOCK_INSUFICIENTE') {
            return _mensajeStockInsuficiente(msg);
          }
          if (msg['mensaje'] != null) {
            return msg['mensaje'].toString();
          }
        }
    }
  }
  final texto = error.toString();
  if (texto.contains('401')) return 'Sesión expirada. Vuelve a iniciar sesión.';
  if (texto.contains('404')) {
    return 'Recurso no encontrado. Reinicia el backend si acabas de actualizar el código.';
  }
  return 'Error al cargar $contexto. Intenta de nuevo.';
}

String _mensajeStockInsuficiente(Map<dynamic, dynamic> msg) {
  final detalles = msg['detalles'];
  if (detalles is List && detalles.isNotEmpty) {
    final lineas = detalles.map((d) {
      if (d is! Map) return null;
      final nombre = d['nombre'] ?? 'Insumo';
      final necesita = d['necesita'];
      final disponible = d['disponible'];
      final unidad = d['unidad'] ?? '';
      return '$nombre: necesitas $necesita $unidad, hay $disponible';
    }).whereType<String>();
    if (lineas.isNotEmpty) {
      return 'Stock insuficiente:\n${lineas.join('\n')}';
    }
  }
  final texto = msg['mensaje']?.toString() ?? '';
  if (texto.isNotEmpty && !texto.contains('suficiente stock')) {
    return 'Stock insuficiente: $texto';
  }
  return 'No hay suficiente stock para preparar este pedido. '
      'Revisa Insumos en el panel admin.';
}

String? _mensajeDesdeExcepcionDart(Object error) {
  if (error is! Exception) return null;
  final texto = error.toString();
  if (!texto.startsWith('Exception: ')) return null;
  final mensaje = texto.substring('Exception: '.length).trim();
  return mensaje.isEmpty ? null : mensaje;
}
