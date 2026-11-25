import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';

/// Navigation for the five inventory work areas.
///
/// Compact screens use an explicit section menu instead of hiding destinations
/// in a horizontally scrolling tab strip. The TabBarView remains swipeable.
class InventarioSeccionSelector extends StatelessWidget {
  const InventarioSeccionSelector({
    required this.controller,
    required this.compacto,
    super.key,
  });

  final TabController controller;
  final bool compacto;

  static const secciones = <({String titulo, IconData icono})>[
    (titulo: 'Mercado', icono: Icons.shopping_basket_outlined),
    (titulo: 'Movimientos', icono: Icons.swap_vert_rounded),
    (titulo: 'Subrecetas', icono: Icons.soup_kitchen_outlined),
    (titulo: 'Conteo', icono: Icons.fact_check_outlined),
    (titulo: 'Traslados', icono: Icons.compare_arrows_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    if (compacto) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final scheme = Theme.of(context).colorScheme;
          final actual = secciones[controller.index];
          return PopupMenuButton<int>(
            tooltip: 'Cambiar sección de inventario',
            initialValue: controller.index,
            onSelected: controller.animateTo,
            color: SaaSTokens.surface(context),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SaaSTokens.r12),
              side: BorderSide(color: SaaSTokens.border(context)),
            ),
            itemBuilder: (context) => [
              for (var i = 0; i < secciones.length; i++)
                PopupMenuItem<int>(
                  value: i,
                  height: 50,
                  child: Row(
                    children: [
                      Icon(
                        secciones[i].icono,
                        size: 19,
                        color: i == controller.index
                            ? scheme.primary
                            : SaaSTokens.inkMuted(context),
                      ),
                      const SizedBox(width: SaaSTokens.s12),
                      Expanded(
                        child: Text(
                          secciones[i].titulo,
                          style: TextStyle(
                            color: SaaSTokens.ink(context),
                            fontWeight: i == controller.index
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (i == controller.index)
                        Icon(Icons.check_rounded,
                            size: 18, color: scheme.primary),
                    ],
                  ),
                ),
            ],
            child: Material(
              color: SaaSTokens.surface(context),
              borderRadius: BorderRadius.circular(SaaSTokens.r12),
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.symmetric(
                  horizontal: SaaSTokens.s12,
                  vertical: SaaSTokens.s8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: SaaSTokens.border(context)),
                  borderRadius: BorderRadius.circular(SaaSTokens.r12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(SaaSTokens.r10),
                      ),
                      child:
                          Icon(actual.icono, color: scheme.primary, size: 19),
                    ),
                    const SizedBox(width: SaaSTokens.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            actual.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: SaaSTokens.ink(context),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sección ${controller.index + 1} de ${secciones.length} · toca para cambiar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: SaaSTokens.inkMuted(context),
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SaaSTokens.s8),
                    Icon(Icons.expand_more_rounded,
                        color: SaaSTokens.inkMuted(context)),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AnaliticaTokens.surfaceMutedOf(context),
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
      ),
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: AnaliticaTokens.inkSoftOf(context),
        indicator: BoxDecoration(
          color: AnaliticaTokens.inkOf(context),
          borderRadius: BorderRadius.circular(SaaSTokens.r10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(2),
        dividerColor: Colors.transparent,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.5),
        tabs: [
          for (final seccion in secciones)
            Tab(
              icon: Icon(seccion.icono, size: 17),
              text: seccion.titulo,
            ),
        ],
      ),
    );
  }
}
