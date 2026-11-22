import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/pagos/domain/planes_comerciales.dart';

/// Módulo fuera del plan: esqueleto estático borroso (0 API) + CTA upgrade.
class ModuloBloqueadoPlaceholder extends StatelessWidget {
  const ModuloBloqueadoPlaceholder({
    super.key,
    required this.tituloModulo,
    required this.planMinimo,
    required this.beneficio,
    required this.onMejorarPlan,
  });

  final String tituloModulo;
  final String planMinimo;
  final String beneficio;
  final VoidCallback onMejorarPlan;

  @override
  Widget build(BuildContext context) {
    final planNombre = PlanesComercialesFoody.nombre(planMinimo);

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: const IgnorePointer(
            child: ExcludeSemantics(child: _PreviewEsqueletoModulo()),
          ),
        ),
        const ColoredBox(color: Color(0x66F7F8FA)),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                    decoration: BoxDecoration(
                      color: AnaliticaTokens.surface.withValues(alpha: 0.92),
                      borderRadius:
                          BorderRadius.circular(AnaliticaTokens.r16),
                      border: Border.all(color: AnaliticaTokens.border),
                      boxShadow: AnaliticaTokens.shadowLift,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ColoresFoody.primario.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 32,
                            color: ColoresFoody.primario,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tituloModulo,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AnaliticaTokens.ink,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta sesión no está incluida en tu plan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AnaliticaTokens.inkMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Disponible desde plan $planNombre',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ColoresFoody.primario,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (beneficio.trim().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            beneficio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AnaliticaTokens.inkSoft,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: onMejorarPlan,
                            icon: const Icon(Icons.rocket_launch_outlined),
                            label: const Text('Mejorar plan'),
                            style: FilledButton.styleFrom(
                              backgroundColor: ColoresFoody.primario,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AnaliticaTokens.r12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Silueta falsa de panel admin — solo paint local, sin datos ni red.
class _PreviewEsqueletoModulo extends StatelessWidget {
  const _PreviewEsqueletoModulo();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _tarjetaKpi(ColoresFoody.primario)),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKpi(ColoresFoody.secundario)),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKpi(AnaliticaTokens.pedidos)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _barra(width: 120, height: 12),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final h in [0.45, 0.7, 0.55, 0.9, 0.6, 0.8, 0.5])
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: FractionallySizedBox(
                                  heightFactor: h,
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: ColoresFoody.primario
                                          .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: _panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _barra(width: 100, height: 12),
                          const SizedBox(height: 14),
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            Row(
                              children: [
                                _circulo(28),
                                const SizedBox(width: 10),
                                Expanded(child: _barra(height: 10)),
                                const SizedBox(width: 8),
                                _barra(width: 48, height: 10),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _panel(
                      child: Column(
                        children: [
                          _barra(width: 90, height: 12),
                          const SizedBox(height: 20),
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ColoresFoody.secundario
                                          .withValues(alpha: 0.45),
                                      width: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tarjetaKpi(Color acento) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barra(width: 72, height: 10),
          const SizedBox(height: 12),
          _barra(width: 96, height: 18, color: acento.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          _barra(width: 56, height: 8),
        ],
      ),
    );
  }

  static Widget _panel({required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: AnaliticaTokens.border),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  static Widget _barra({
    double? width,
    double height = 10,
    Color color = AnaliticaTokens.surfaceMuted,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  static Widget _circulo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AnaliticaTokens.surfaceMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
