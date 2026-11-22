import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';

/// Estados de pantalla reutilizables (carga, error, vacío, plan bloqueado).
class FoodyEstadoUi {
  FoodyEstadoUi._();

  static Widget cargando({String? mensaje}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: ColoresFoody.primario),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Error genérico o tarjeta de suscripción si aplica.
  static Widget desdeExcepcion({
    required Object error,
    String contexto = 'cargar',
    VoidCallback? onReintentar,
    VoidCallback? onReactivarPlan,
  }) {
    return Builder(
      builder: (context) {
        if (esErrorSuscripcion(error)) {
          return bloqueadoSuscripcion(
            onReactivarPlan: onReactivarPlan ??
                () => context.go('/admin/panel?seccion=mejorar_plan'),
          );
        }
        return errorUi(
          mensaje: mensajeErrorHttp(error, contexto: contexto),
          onReintentar: onReintentar,
        );
      },
    );
  }

  /// Cuando ya tienes el string (p. ej. `_error` de un State).
  static Widget desdeMensaje({
    required String mensaje,
    VoidCallback? onReintentar,
    VoidCallback? onReactivarPlan,
  }) {
    return Builder(
      builder: (context) {
        if (esMensajeSuscripcion(mensaje)) {
          return bloqueadoSuscripcion(
            onReactivarPlan: onReactivarPlan ??
                () => context.go('/admin/panel?seccion=mejorar_plan'),
          );
        }
        return errorUi(mensaje: mensaje, onReintentar: onReintentar);
      },
    );
  }

  static Widget bloqueadoSuscripcion({required VoidCallback onReactivarPlan}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ColoresFoody.error.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ColoresFoody.error.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 36,
                      color: ColoresFoody.error,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Plan no activo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    kMensajeSuscripcionBloqueada,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onReactivarPlan,
                      style: FilledButton.styleFrom(
                        backgroundColor: ColoresFoody.primario,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.workspace_premium_outlined),
                      label: const Text('Reactivar plan'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget error({
    required String mensaje,
    VoidCallback? onReintentar,
    String etiquetaReintentar = 'Reintentar',
    VoidCallback? onAccionSecundaria,
    String? etiquetaAccionSecundaria,
  }) {
    if (esMensajeSuscripcion(mensaje)) {
      return desdeMensaje(mensaje: mensaje);
    }
    return errorUi(
      mensaje: mensaje,
      onReintentar: onReintentar,
      etiquetaReintentar: etiquetaReintentar,
      onAccionSecundaria: onAccionSecundaria,
      etiquetaAccionSecundaria: etiquetaAccionSecundaria,
    );
  }

  static Widget errorUi({
    required String mensaje,
    VoidCallback? onReintentar,
    String etiquetaReintentar = 'Reintentar',
    VoidCallback? onAccionSecundaria,
    String? etiquetaAccionSecundaria,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onReintentar,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                ),
                child: Text(etiquetaReintentar),
              ),
            ],
            if (onAccionSecundaria != null &&
                etiquetaAccionSecundaria != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAccionSecundaria,
                child: Text(etiquetaAccionSecundaria),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget vacio({
    required String titulo,
    String? subtitulo,
    IconData icono = Icons.inbox_outlined,
    String? etiquetaAccion,
    VoidCallback? onAccion,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
            ],
            if (etiquetaAccion != null && onAccion != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onAccion,
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                ),
                child: Text(etiquetaAccion),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
