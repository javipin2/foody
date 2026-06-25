import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:reserva_canchas/services/plan_feature_service.dart';

/// Misma ventana de planes que el panel admin (evita duplicar lógica).
Future<void> showPlanSelectionDialog(
  BuildContext context, {
  VoidCallback? onPlanUpdated,
}) async {
  final currentPlan = await PlanFeatureService.getCurrentPlan();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      bool isSaving = false;

      Widget buildPlanCard({
        required LugarPlan plan,
        required String title,
        required String subtitle,
        required Color color,
        required List<String> beneficios,
      }) {
        final bool isCurrent = plan == currentPlan;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCurrent ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrent ? color : Colors.grey.shade300,
              width: isCurrent ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium, color: color, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  if (isCurrent)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'PLAN ACTUAL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...beneficios.map(
                (b) => Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isCurrent || isSaving
                      ? null
                      : () async {
                          if (isSaving) return;
                          try {
                            isSaving = true;
                            await PlanFeatureService.updatePlan(plan);
                            if (!context.mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Plan actualizado a $title',
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: color,
                              ),
                            );
                            onPlanUpdated?.call();
                          } catch (e) {
                            isSaving = false;
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al actualizar el plan: $e',
                                  style: GoogleFonts.inter(),
                                ),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                  child: Text(
                    isCurrent ? 'Plan actual' : 'Cambiar a este plan',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? Colors.grey : color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planes disponibles',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige el plan que mejor se adapte al tamaño de tu negocio.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                buildPlanCard(
                  plan: LugarPlan.basico,
                  title: 'Plan Básico',
                  subtitle: 'Ideal para una sede pequeña con pocas canchas.',
                  color: Colors.green.shade600,
                  beneficios: const [
                    '1 administrador',
                    'Hasta 1 sede',
                    'Hasta 2 canchas',
                    'Reservas simples y control básico',
                  ],
                ),
                buildPlanCard(
                  plan: LugarPlan.premium,
                  title: 'Plan Premium',
                  subtitle: 'Perfecto para centros deportivos en crecimiento.',
                  color: Colors.blue.shade600,
                  beneficios: const [
                    'Todo lo del Plan Básico',
                    'Hasta 3 sedes y 6 canchas',
                    'Gestión de clientes',
                    'Reservas fijas (recurrentes)',
                    'Promociones de horas',
                  ],
                ),
                buildPlanCard(
                  plan: LugarPlan.pro,
                  title: 'Plan Pro',
                  subtitle: 'Para operaciones grandes con control total.',
                  color: Colors.purple.shade600,
                  beneficios: const [
                    'Todo lo del Plan Premium',
                    'Sedes y canchas ilimitadas',
                    'Roles ilimitados',
                    'Auditoría completa y detección de acciones sospechosas',
                    'Rol superusuario y control total',
                  ],
                ),
                buildPlanCard(
                  plan: LugarPlan.prueba,
                  title: 'Plan Prueba',
                  subtitle: 'Para probar el sistema en un solo lugar.',
                  color: Colors.orange.shade600,
                  beneficios: const [
                    'Funciones limitadas del Plan Básico',
                    'Ideal para pruebas internas',
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
