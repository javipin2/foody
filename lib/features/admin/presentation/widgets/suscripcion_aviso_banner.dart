import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Banner de vencimiento de suscripción (F4 self-service).
class SuscripcionAvisoBanner extends StatelessWidget {
  const SuscripcionAvisoBanner({
    super.key,
    this.suscripcion,
    this.onMejorarPlan,
    this.onDismiss,
  });

  final Map<String, dynamic>? suscripcion;
  final VoidCallback? onMejorarPlan;
  /// NAV-ADM2-08: ocultar en sesión (no persiste).
  final VoidCallback? onDismiss;

  void _irMejorarPlan(BuildContext context) {
    if (onMejorarPlan != null) {
      onMejorarPlan!();
      return;
    }
    context.go('/admin/panel?seccion=mejorar_plan');
  }

  @override
  Widget build(BuildContext context) {
    final s = suscripcion;
    if (s == null) return const SizedBox.shrink();

    final mostrarBanner = s['mostrar_banner'] == true;
    final plan = s['plan'] as String? ?? '';
    final esGratis = plan == 'gratis';

    if (!mostrarBanner && !esGratis) {
      return const SizedBox.shrink();
    }

    if (!mostrarBanner && esGratis) {
      return _bannerGratis(context);
    }

    final nivel = s['nivel_aviso'] as String? ?? 'ok';
    final dias = s['dias_restantes'] as int? ?? 0;

    late final String mensaje;
    late final Color fondo;
    late final IconData icono;
    final mostrarCta = nivel != 'ok';

    switch (nivel) {
      case 'bloqueada':
        mensaje =
            'Tu plan $plan está bloqueado. Reactiva tu suscripción para volver a operar.';
        fondo = ColoresFoody.error.withValues(alpha: 0.12);
        icono = Icons.lock_outline;
      case 'vencida':
        mensaje =
            'Tu plan $plan venció. Tus datos se conservan; renuévalo para desbloquear el panel.';
        fondo = ColoresFoody.error.withValues(alpha: 0.1);
        icono = Icons.warning_amber_rounded;
      case 'hoy':
        mensaje = 'Tu plan $plan vence hoy. Renueva para no interrumpir el servicio.';
        fondo = ColoresFoody.primario.withValues(alpha: 0.12);
        icono = Icons.event_busy_outlined;
      case 'proximo':
        mensaje =
            'Tu plan $plan vence en $dias día${dias == 1 ? '' : 's'}. Considera renovar pronto.';
        fondo = ColoresFoody.acento.withValues(alpha: 0.9);
        icono = Icons.schedule_outlined;
      default:
        return esGratis ? _bannerGratis(context) : const SizedBox.shrink();
    }

    return _contenedor(
      fondo: fondo,
      icono: icono,
      mensaje: mensaje,
      mostrarCta: mostrarCta,
      onCta: () => _irMejorarPlan(context),
      etiquetaCta: nivel == 'bloqueada' || nivel == 'vencida'
          ? 'Reactivar plan'
          : 'Renovar plan',
    );
  }

  Widget _bannerGratis(BuildContext context) {
    return _contenedor(
      fondo: ColoresFoody.secundario.withValues(alpha: 0.12),
      icono: Icons.auto_awesome_outlined,
      mensaje:
          'Estás en plan Gratis. Mejora a Pro para ver márgenes reales, inventario y cocina KDS.',
      mostrarCta: true,
      onCta: () => _irMejorarPlan(context),
      etiquetaCta: 'Mejorar plan',
    );
  }

  Widget _contenedor({
    required Color fondo,
    required IconData icono,
    required String mensaje,
    required bool mostrarCta,
    required VoidCallback onCta,
    required String etiquetaCta,
  }) {
    return Material(
      color: fondo,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icono, size: 20, color: const Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ),
              if (mostrarCta) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onCta,
                  style: TextButton.styleFrom(
                    foregroundColor: ColoresFoody.primario,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    etiquetaCta,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (onDismiss != null)
                IconButton(
                  tooltip: 'Ocultar',
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
