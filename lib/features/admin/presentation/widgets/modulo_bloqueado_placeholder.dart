import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/pagos/domain/planes_comerciales.dart';

/// Placeholder cuando un módulo requiere plan superior (candado F6).
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ColoresFoody.grisSuave,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tituloModulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Requiere plan $planNombre',
                style: TextStyle(
                  color: ColoresFoody.primario,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                beneficio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onMejorarPlan,
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Mejorar plan'),
                style: FilledButton.styleFrom(
                  backgroundColor: ColoresFoody.primario,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
