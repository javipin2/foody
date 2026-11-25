import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';

/// Estados de pantalla reutilizables (carga, error, vacío, plan bloqueado).
class FoodyEstadoUi {
  FoodyEstadoUi._();

  static Widget cargando({String? mensaje}) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                  color: scheme.primary, semanticsLabel: mensaje ?? 'Cargando'),
              if (mensaje != null) ...[
                const SizedBox(height: 16),
                Text(
                  mensaje,
                  style:
                      TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
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
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.25),
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
                          color: scheme.error.withValues(alpha: 0.1),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 36,
                          color: scheme.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Plan no activo',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        kMensajeSuscripcionBloqueada,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onReactivarPlan,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
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
      },
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
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return LayoutBuilder(
          builder: (context, constraints) {
            final estrecho = constraints.maxWidth < 420;
            return Center(
              child: Padding(
                padding: EdgeInsets.all(estrecho ? 16 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(estrecho ? 20 : 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: scheme.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.cloud_off_outlined,
                              size: 28,
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            mensaje,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(height: 1.5),
                          ),
                          if (onReintentar != null) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: estrecho ? double.infinity : 240,
                              height: 48,
                              child: FilledButton(
                                onPressed: onReintentar,
                                child: Text(etiquetaReintentar),
                              ),
                            ),
                          ],
                          if (onAccionSecundaria != null &&
                              etiquetaAccionSecundaria != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: TextButton(
                                onPressed: onAccionSecundaria,
                                child: Text(etiquetaAccionSecundaria),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget vacio({
    required String titulo,
    String? subtitulo,
    IconData icono = Icons.inbox_outlined,
    String? etiquetaAccion,
    VoidCallback? onAccion,
  }) {
    return Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return LayoutBuilder(
          builder: (context, constraints) {
            final estrecho = constraints.maxWidth < 380;
            return Center(
              child: Padding(
                padding: EdgeInsets.all(estrecho ? 24 : 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surfaceContainerHigh,
                        ),
                        alignment: Alignment.center,
                        child: Icon(icono, size: 30, color: scheme.primary),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        titulo,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitulo,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                        ),
                      ],
                      if (etiquetaAccion != null && onAccion != null) ...[
                        const SizedBox(height: 20),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 160,
                            minHeight: 48,
                            maxWidth: 280,
                          ),
                          child: FilledButton(
                            onPressed: onAccion,
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              minimumSize: const Size(160, 48),
                            ),
                            child: Text(etiquetaAccion),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
