import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';

/// Header premium — Centro de Inteligencia.
class AnaliticaHeader extends StatelessWidget {
  const AnaliticaHeader({
    super.key,
    required this.periodoLabel,
    required this.preset,
    required this.presets,
    required this.comparar,
    required this.filtrosActivos,
    required this.filtrosEtiqueta,
    required this.actualizadoEn,
    required this.onPreset,
    required this.onToggleComparar,
    required this.onCompararRango,
    required this.onFiltros,
    required this.onActualizar,
    required this.onExportar,
    this.onIrReportes,
    this.compararPersonalizado = false,
    this.onPersonalizado,
  });

  final String periodoLabel;
  final String preset;
  final List<(String, String)> presets;
  final bool comparar;
  final int filtrosActivos;
  final String filtrosEtiqueta;
  final DateTime actualizadoEn;
  final ValueChanged<String> onPreset;
  final ValueChanged<bool> onToggleComparar;
  final VoidCallback onCompararRango;
  final VoidCallback onFiltros;
  final VoidCallback onActualizar;
  final VoidCallback onExportar;
  final VoidCallback? onIrReportes;
  final bool compararPersonalizado;
  final VoidCallback? onPersonalizado;

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final hora = DateFormat('HH:mm').format(actualizadoEn);
    final meta = [
      if (periodoLabel.isNotEmpty) periodoLabel,
      'Act. $hora',
      if (comparar)
        compararPersonalizado ? 'Comparativa custom' : 'vs anterior',
      if (filtrosActivos > 0) '$filtrosActivos filtros',
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 20,
        12,
        compacto ? 12 : 20,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis',
                      style: TextStyle(
                        fontSize: 11,
                        color: SaaSTokens.inkSoft(context),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Centro de Inteligencia',
                      style: TextStyle(
                        fontSize: compacto ? 22 : 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: SaaSTokens.ink(context),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Visión ejecutiva de ventas, operación y riesgo en tiempo real.',
                      style: TextStyle(
                        fontSize: 13,
                        color: SaaSTokens.inkMuted(context),
                        height: 1.35,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        style: TextStyle(
                          fontSize: 12,
                          color: SaaSTokens.inkSoft(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              _acciones(context, compacto),
            ],
          ),
          const SizedBox(height: 14),
          SaaSFilterBar(
            presets: [
              for (final p in presets)
                SaaSFilterChip(id: p.$1, label: p.$2),
              const SaaSFilterChip(id: 'rango', label: 'Personalizado'),
            ],
            selectedId: preset,
            onSelect: (id) {
              if (id == 'rango') {
                (onPersonalizado ?? () => onPreset('rango'))();
              } else {
                onPreset(id);
              }
            },
            trailing: [
              SaaSActionChip(
                label: 'Comparar',
                selected: comparar,
                icono: Icons.compare_arrows_rounded,
                onTap: () => onToggleComparar(!comparar),
                onLongPress: comparar ? onCompararRango : null,
              ),
              const SizedBox(width: 6),
              Badge(
                isLabelVisible: filtrosActivos > 0,
                smallSize: 14,
                label: Text(
                  '$filtrosActivos',
                  style: const TextStyle(fontSize: 9),
                ),
                child: SaaSActionChip(
                  label: 'Filtro avanzado',
                  selected: filtrosActivos > 0,
                  icono: Icons.tune_rounded,
                  onTap: onFiltros,
                ),
              ),
            ],
          ),
          if (filtrosEtiqueta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              filtrosEtiqueta,
              style: TextStyle(
                fontSize: 11.5,
                color: SaaSTokens.inkMuted(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _acciones(BuildContext context, bool compacto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onIrReportes != null && !compacto)
          TextButton(
            onPressed: onIrReportes,
            style: TextButton.styleFrom(
              foregroundColor: SaaSTokens.inkMuted(context),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Reportes'),
          ),
        IconButton(
          tooltip: 'Exportar',
          onPressed: onExportar,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.download_rounded,
            size: 20,
            color: SaaSTokens.inkMuted(context),
          ),
        ),
        IconButton(
          tooltip: 'Actualizar',
          onPressed: onActualizar,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            Icons.refresh_rounded,
            size: 20,
            color: SaaSTokens.inkMuted(context),
          ),
        ),
      ],
    );
  }
}
