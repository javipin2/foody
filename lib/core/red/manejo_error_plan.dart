import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/paywall_limite_plan_dialog.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;

/// Errores de plan comercial (límite freemium o módulo bloqueado).
class ManejoErrorPlan {
  ManejoErrorPlan._();

  static DateTime? _ultimoDialogo;
  static String? _ultimoMensaje;

  static const _codigosPlan = {
    'PLAN_LIMITE_EXCEDIDO',
    'PLAN_NO_INCLUYE_MODULO',
  };

  static String? codigoError(Object error) {
    final data = _datosError(error);
    if (data == null) return null;
    return data['error']?.toString();
  }

  static bool esErrorPlan(Object error) {
    final codigo = codigoError(error);
    return codigo != null && _codigosPlan.contains(codigo);
  }

  static bool esLimiteExcedido(Object error) =>
      codigoError(error) == 'PLAN_LIMITE_EXCEDIDO';

  /// Interceptor Dio (staff): muestra paywall sin depender del BuildContext de la pantalla.
  static void manejarDesdeInterceptor(DioException error) {
    if (!esErrorPlan(error)) return;
    final ctx = appNavigatorKey.currentContext;
    if (ctx == null) return;
    _mostrarPaywall(ctx, error);
  }

  /// En `catch` de pantallas: devuelve `true` si ya mostró paywall/snack de plan.
  static bool manejarEnPantalla(BuildContext context, Object error) {
    if (!esErrorPlan(error)) return false;
    _mostrarPaywall(context, error);
    return true;
  }

  /// Snack compacto (legacy mesas). Preferir [manejarEnPantalla].
  static bool mostrarSnackSiAplica(
    BuildContext context,
    Object error, {
    VoidCallback? onMejorarPlan,
  }) {
    if (!esErrorPlan(error)) return false;

    final texto = mensajeErrorHttp(error, contexto: 'tu plan');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        action: SnackBarAction(
          label: 'Ver planes',
          onPressed: () {
            if (onMejorarPlan != null) {
              onMejorarPlan();
            } else {
              context.push('/admin/mejorar-plan');
            }
          },
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    return true;
  }

  static void _mostrarPaywall(BuildContext context, Object error) {
    final data = _datosError(error);
    final mensaje = mensajeErrorHttp(error, contexto: 'tu plan');
    if (_esDuplicado(mensaje)) return;

    final limite = _entero(data?['limite']);
    final actual = _entero(data?['actual']);

    PaywallLimitePlanDialog.mostrar(
      context,
      mensaje: mensaje,
      limite: limite,
      actual: actual,
    );
  }

  static bool _esDuplicado(String mensaje) {
    final ahora = DateTime.now();
    if (_ultimoMensaje == mensaje &&
        _ultimoDialogo != null &&
        ahora.difference(_ultimoDialogo!) < const Duration(seconds: 2)) {
      return true;
    }
    _ultimoMensaje = mensaje;
    _ultimoDialogo = ahora;
    return false;
  }

  static Map<String, dynamic>? _datosError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    return null;
  }

  static int? _entero(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
