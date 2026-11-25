import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kMensajeSuscripcionBloqueada =
    'Tu suscripción no está activa. Reactiva tu plan para usar el panel. '
    'Tus datos se conservan.';

/// ¿403 por plan/suscripción vencida o bloqueada?
bool esErrorSuscripcion(Object error) {
  if (error is DioException) {
    if (error.response?.statusCode != 403) return false;
    final data = error.response?.data;
    if (data is Map) {
      final codigo = data['error']?.toString() ?? '';
      if (codigo == 'RESTAURANTE_BLOQUEADO' ||
          codigo == 'PLAN_NO_INCLUYE_MODULO' ||
          codigo == 'PLAN_LIMITE_EXCEDIDO') {
        return true;
      }
      final msg =
          '${data['mensaje'] ?? ''} ${data['message'] ?? ''}'.toLowerCase();
      if (msg.contains('suscrip') ||
          msg.contains('plan') &&
              (msg.contains('venc') ||
                  msg.contains('bloque') ||
                  msg.contains('reactiva') ||
                  msg.contains('no activa'))) {
        return true;
      }
    }
  }
  final t = error.toString().toLowerCase();
  return t.contains('restaurante_bloqueado') ||
      (t.contains('suscrip') && (t.contains('403') || t.contains('bloque')));
}

bool esMensajeSuscripcion(String mensaje) {
  final l = mensaje.toLowerCase();
  return l.contains('suscrip') ||
      (l.contains('plan') &&
          (l.contains('venc') ||
              l.contains('reactiva') ||
              l.contains('bloque') ||
              l.contains('renueva')));
}

/// Código técnico del envelope Nest (`error`) si viene en DioException.
String? codigoErrorApi(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final c = data['error']?.toString();
      if (c != null && c.isNotEmpty) return c;
    }
  }
  return null;
}

/// Mensaje legible para el usuario a partir de errores HTTP, Auth o Exception.
String mensajeErrorHttp(Object error, {String contexto = 'operación'}) {
  final desdeAuth = _mensajeDesdeAuthSupabase(error);
  if (desdeAuth != null) return desdeAuth;

  final desdeExcepcion = _mensajeDesdeExcepcionDart(error);
  if (desdeExcepcion != null) return desdeExcepcion;

  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] == 'STOCK_INSUFICIENTE') {
      return _mensajeStockInsuficiente(data);
    }
    if (data is Map && data['error'] == 'RESTAURANTE_BLOQUEADO') {
      return data['mensaje']?.toString() ?? kMensajeSuscripcionBloqueada;
    }
    final desdeApi = _mensajeDesdeRespuestaApi(data);
    if (desdeApi != null) {
      if (esErrorSuscripcion(error) || esMensajeSuscripcion(desdeApi)) {
        return desdeApi.contains('Reactiva') || desdeApi.contains('renueva')
            ? desdeApi
            : kMensajeSuscripcionBloqueada;
      }
      return desdeApi;
    }

    final codigo = error.response?.statusCode;
    switch (codigo) {
      case 401:
        if (error.requestOptions.path.endsWith('/auth/login') ||
            error.requestOptions.path.endsWith('/auth/login-google')) {
          final msg401 = error.response?.data;
          if (error.requestOptions.path.endsWith('/auth/login-google') &&
              msg401 is Map &&
              msg401['message'] != null) {
            return msg401['message'].toString();
          }
          if (error.requestOptions.path.endsWith('/auth/login')) {
            if (kDebugMode) {
              return 'Correo o contraseña incorrectos. Demo: admin@foody.demo / 123456 '
                  '(super y domi en la misma pantalla; repartidor en enlace inferior).';
            }
            return 'Correo o contraseña incorrectos.';
          }
        }
        return 'Sesión expirada. Cierra sesión y vuelve a entrar con tu usuario.';
      case 403:
        if (esErrorSuscripcion(error)) {
          return kMensajeSuscripcionBloqueada;
        }
        final msg = error.response?.data;
        if (msg is Map) {
          if (msg['error'] == 'PLAN_NO_INCLUYE_MODULO' ||
              msg['error'] == 'PLAN_LIMITE_EXCEDIDO') {
            return msg['mensaje']?.toString() ??
                'Tu plan no incluye esta función. Mejora tu plan para desbloquearla.';
          }
          if (msg['mensaje'] != null) {
            final m = msg['mensaje'].toString();
            if (esMensajeSuscripcion(m)) return kMensajeSuscripcionBloqueada;
            return m;
          }
        }
        return 'No tienes permiso para $contexto. Cierra sesión y vuelve a entrar.';
      case 404:
        final ruta = error.requestOptions.uri.path;
        return 'Ruta no encontrada en el API ($ruta). Reinicia el backend '
            '(npm run build && node dist/main.js en foody_backend).';
      case 409:
        return 'El correo ya está registrado.';
      case 500:
      case 502:
      case 503:
        return 'El servidor no está disponible. Comprueba que la API esté encendida en el puerto 3000.';
      default:
        break;
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Sin conexión con el servidor (${Configuracion.urlBackend}). '
          'Comprueba que la API y el túnel estén encendidos.';
    }
  }

  final texto = error.toString();
  if (texto.contains('SESION_EXPIRADA') || texto.contains('401')) {
    return 'Sesión expirada. Vuelve a iniciar sesión.';
  }
  if (texto.contains('404')) {
    return 'Recurso no encontrado. Reinicia el backend si acabas de actualizar el código.';
  }
  // Nunca devolver el toString crudo de Dio al usuario.
  if (texto.toLowerCase().contains('dioexception')) {
    if (esErrorSuscripcion(error)) return kMensajeSuscripcionBloqueada;
    return 'Error al $contexto. Intenta de nuevo.';
  }
  return 'Error al $contexto. Intenta de nuevo.';
}

/// Mensajes para el cliente final (sin jerga de desarrollo / infra).
String mensajeErrorCliente(Object error,
    {String contexto = 'cargar la información'}) {
  final raw = mensajeErrorHttp(error, contexto: contexto);
  final lower = raw.toLowerCase();
  const bloqueados = [
    'localhost',
    'npm run',
    'docker',
    'dioexception',
    'puerto 3000',
    'ruta no encontrada en el api',
    'reinicia el backend',
    'comprueba que la api',
    'sin conexión con el servidor',
  ];
  for (final b in bloqueados) {
    if (lower.contains(b)) {
      return 'No pudimos conectar. Revisa tu internet e intenta de nuevo.';
    }
  }
  return raw;
}

/// Extrae texto legible del cuerpo `{ exito, error, mensaje }` o NestJS.
String? _mensajeDesdeRespuestaApi(dynamic data) {
  if (data is! Map) return null;

  final mensaje = data['mensaje'];
  if (mensaje != null) {
    final s = mensaje.toString().trim();
    if (s.isNotEmpty && s != 'Ocurrió un error inesperado') return s;
  }

  final message = data['message'];
  if (message is String) {
    final s = message.trim();
    if (s.isNotEmpty) return s;
  }
  if (message is List && message.isNotEmpty) {
    return message.map((e) => e.toString()).join('\n');
  }
  if (message is Map) {
    final anidado = _mensajeDesdeRespuestaApi(message);
    if (anidado != null) return anidado;
  }

  final codigo = data['error']?.toString();
  if (codigo != null && _mensajesPorCodigo.containsKey(codigo)) {
    return _mensajesPorCodigo[codigo];
  }

  return null;
}

const _mensajesPorCodigo = <String, String>{
  'CAJA_CIERRE_OPERACION_ABIERTA':
      'No puedes cerrar la caja con pedidos activos, mesas ocupadas o domicilios sin cobrar. '
          'Cierra o cobra todo antes de cerrar el turno.',
  'CAJA_NO_ABIERTA':
      'No hay caja abierta. Abre un turno de caja antes de esta operación.',
  'CAJA_YA_ABIERTA':
      'Ya hay una caja abierta en esta sucursal. Usa ese turno o ciérralo primero.',
  'SOLICITUD_INVALIDA':
      'Datos incorrectos. Revisa los campos e intenta de nuevo.',
  'MESA_NO_ENCONTRADA': 'La mesa no existe o está inactiva.',
  'ITEMS_EXCEDEN_SALDO':
      'El total de los ítems seleccionados supera el saldo pendiente. '
          'Cobra solo lo pendiente o usa abono parcial.',
  'ITEMS_INVALIDOS':
      'Algunos ítems ya fueron cobrados o no pertenecen a esta mesa.',
  'SUCURSAL_SIN_COORDENADAS':
      'Configura la ubicación GPS de la sucursal para usar domicilios.',
};

String? _mensajeDesdeAuthSupabase(Object error) {
  if (error is AuthException) {
    final msg = error.message.trim();
    if (msg.isNotEmpty) {
      if (msg.toLowerCase().contains('code verifier') ||
          msg.toLowerCase().contains('pkce') ||
          msg.toLowerCase().contains('both auth code and code verifier')) {
        return 'El retorno de Google ya fue procesado o expiró. '
            'Cierra esta pestaña, vuelve a /admin/login y pulsa «Continuar con Google» de nuevo.';
      }
      return msg;
    }
    return 'No se pudo completar el inicio con Google. Intenta de nuevo.';
  }
  if (error is StateError) {
    return error.message;
  }
  return null;
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
