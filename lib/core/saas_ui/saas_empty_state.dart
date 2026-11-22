import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

class SaaSEmptyState extends StatelessWidget {
  const SaaSEmptyState({
    super.key,
    required this.titulo,
    this.descripcion,
    this.icono = Icons.inbox_outlined,
    this.compacto = false,
  });

  final String titulo;
  final String? descripcion;
  final IconData icono;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: compacto ? 24 : 40,
      ),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: compacto ? 28 : 36, color: SaaSTokens.inkSoft(context)),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SaaSTokens.ink(context),
            ),
          ),
          if (descripcion != null) ...[
            const SizedBox(height: 6),
            Text(
              descripcion!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: SaaSTokens.inkMuted(context),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SaaSPriorityAlert extends StatelessWidget {
  const SaaSPriorityAlert({
    super.key,
    required this.titulo,
    this.detalle,
    this.prioridad = 'media',
    this.onTap,
  });

  final String titulo;
  final String? detalle;
  /// alta | media | baja
  final String prioridad;
  final VoidCallback? onTap;

  Color _color() {
    switch (prioridad.toLowerCase()) {
      case 'alta':
      case 'critica':
      case 'crítico':
        return SaaSTokens.prioridadAlta;
      case 'baja':
        return SaaSTokens.prioridadBaja;
      default:
        return SaaSTokens.prioridadMedia;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(SaaSTokens.r12),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            prioridad.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: SaaSTokens.ink(context),
                      ),
                    ),
                    if (detalle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        detalle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: SaaSTokens.inkMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SaaSInsightCard extends StatelessWidget {
  const SaaSInsightCard({
    super.key,
    required this.texto,
    this.icono = Icons.auto_awesome_outlined,
  });

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
        border: Border.all(color: SaaSTokens.borderSoft(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: SaaSTokens.inkMuted(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: SaaSTokens.ink(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
