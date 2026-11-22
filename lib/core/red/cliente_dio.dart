import 'dart:async';

import 'package:dio/dio.dart';
import 'package:reserva_canchas/core/constantes/configuracion.dart';
import 'package:reserva_canchas/core/red/manejo_error_plan.dart';
import 'package:reserva_canchas/core/red/manejo_error_sesion.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/sesion/jwt_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';

/// Cliente HTTP hacia el backend NestJS (cerebro de Foody).
class ClienteDio {
  ClienteDio._();

  static Dio? _dio;

  /// Mutex refresh (AUTH-FLOW): una sola renovación concurrente.
  static Future<String?>? _refreshEnCurso;

  static const _extraRetry = 'foody_auth_retry';

  static bool _esAuthPublico(String path) =>
      path.contains('/auth/login') ||
      path.contains('/auth/login-google') ||
      path.contains('/auth/login-domiciliario') ||
      path.contains('/auth/registro') ||
      path.contains('/auth/refresh') ||
      path.contains('/auth/logout');

  static Future<String?> _extraerTokenRefresh(Response<dynamic> res) async {
    final cuerpo = res.data;
    if (cuerpo is! Map) return null;
    final datos = cuerpo['datos'];
    final mapa = datos is Map
        ? Map<String, dynamic>.from(datos)
        : Map<String, dynamic>.from(cuerpo);
    final nuevo = mapa['token'] as String?;
    if (nuevo == null || nuevo.isEmpty) return null;
    await SesionStaffService.actualizarToken(nuevo);
    final canalesRaw = mapa['realtime_canales'];
    if (canalesRaw is Map) {
      final canales = <String, String>{};
      canalesRaw.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          canales[k.toString()] = v.toString();
        }
      });
      if (canales.isNotEmpty) {
        await SesionStaffService.actualizarRealtimeCanales(canales);
        FoodyRealtime.aplicarCanalesStaff(canales);
      }
    }
    return nuevo;
  }

  static Future<String?> _llamarRefresh(String token) async {
    final bare = Dio(
      BaseOptions(
        baseUrl: Configuracion.urlBackend,
        connectTimeout: Configuracion.timeoutConexion,
        receiveTimeout: Configuracion.timeoutRespuesta,
        sendTimeout: Configuracion.timeoutEnvio,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final res = await bare.post<Map<String, dynamic>>('/auth/refresh');
    return _extraerTokenRefresh(res);
  }

  static Future<String?> _renovarSiHaceFalta(String token) async {
    if (!JwtStaff.porExpirar(token)) return token;
    if (_refreshEnCurso != null) return _refreshEnCurso;
    _refreshEnCurso = () async {
      try {
        return await _llamarRefresh(token) ?? token;
      } catch (_) {
        return token;
      } finally {
        _refreshEnCurso = null;
      }
    }();
    return _refreshEnCurso;
  }

  /// AUTH-FIX-04: un intento de refresh ante 401 (no revocación).
  static Future<String?> _refreshTras401(String? tokenViejo) async {
    if (tokenViejo == null || tokenViejo.isEmpty) return null;
    if (_refreshEnCurso != null) return _refreshEnCurso;
    _refreshEnCurso = () async {
      try {
        return await _llamarRefresh(tokenViejo);
      } catch (_) {
        return null;
      } finally {
        _refreshEnCurso = null;
      }
    }();
    return _refreshEnCurso;
  }

  static Dio instancia({bool conAuthStaff = false}) {
    if (_dio != null && !conAuthStaff) return _dio!;

    final dio = Dio(
      BaseOptions(
        baseUrl: Configuracion.urlBackend,
        connectTimeout: Configuracion.timeoutConexion,
        receiveTimeout: Configuracion.timeoutRespuesta,
        sendTimeout: Configuracion.timeoutEnvio,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (conAuthStaff) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final path = options.path;
            final esAuthPublico = _esAuthPublico(path);
            var token = await SesionStaffService.obtenerToken();
            if (token != null &&
                token.isNotEmpty &&
                !path.contains('/auth/refresh')) {
              token = await _renovarSiHaceFalta(token) ?? token;
            }
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
              handler.next(options);
              return;
            }
            if (!esAuthPublico) {
              unawaited(ManejoErrorSesion.solicitarReLogin());
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  error: 'SESION_EXPIRADA',
                  message: 'Sesión expirada. Vuelve a iniciar sesión.',
                ),
              );
              return;
            }
            handler.next(options);
          },
          onError: (error, handler) async {
            final path = error.requestOptions.path;
            if (_esAuthPublico(path)) {
              handler.next(error);
              return;
            }
            if (error.response?.statusCode == 401) {
              final yaRetried = error.requestOptions.extra[_extraRetry] == true;
              final authHeader =
                  error.requestOptions.headers['Authorization']?.toString();
              final tokenViejo = authHeader != null &&
                      authHeader.startsWith('Bearer ')
                  ? authHeader.substring(7)
                  : await SesionStaffService.obtenerToken();
              if (!yaRetried && tokenViejo != null && tokenViejo.isNotEmpty) {
                final nuevo = await _refreshTras401(tokenViejo);
                if (nuevo != null && nuevo.isNotEmpty) {
                  final req = error.requestOptions;
                  req.headers['Authorization'] = 'Bearer $nuevo';
                  req.extra[_extraRetry] = true;
                  try {
                    final clone = await dio.fetch<dynamic>(req);
                    handler.resolve(clone);
                    return;
                  } catch (_) {
                    // cae a re-login abajo
                  }
                }
              }
              ManejoErrorSesion.manejarDesdeInterceptor(error);
            } else if (error.response?.statusCode == 403) {
              ManejoErrorPlan.manejarDesdeInterceptor(error);
            }
            handler.next(error);
          },
        ),
      );
      return dio;
    }

    _dio = dio;
    return dio;
  }
}
