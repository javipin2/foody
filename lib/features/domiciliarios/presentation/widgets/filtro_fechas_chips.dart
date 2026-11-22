import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

enum RangoFechasDomi { hoy, sieteDias, mes, custom }

class FiltroFechasResultado {
  const FiltroFechasResultado({
    required this.rango,
    this.desde,
    this.hasta,
  });

  final RangoFechasDomi rango;
  final DateTime? desde;
  final DateTime? hasta;

  /// ISO date (yyyy-MM-dd) para query API.
  String? get desdeIso {
    final d = desde ?? _inicioRango(rango);
    return d?.toIso8601String().split('T').first;
  }

  String? get hastaIso {
    final d = hasta ?? _finRango(rango);
    return d?.toIso8601String().split('T').first;
  }

  static DateTime? _inicioRango(RangoFechasDomi r) {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    switch (r) {
      case RangoFechasDomi.hoy:
        return hoy;
      case RangoFechasDomi.sieteDias:
        return hoy.subtract(const Duration(days: 6));
      case RangoFechasDomi.mes:
        return DateTime(now.year, now.month, 1);
      case RangoFechasDomi.custom:
        return null;
    }
  }

  static DateTime? _finRango(RangoFechasDomi r) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

class FiltroFechasChips extends StatelessWidget {
  const FiltroFechasChips({
    super.key,
    required this.seleccionado,
    required this.onChanged,
  });

  final FiltroFechasResultado seleccionado;
  final ValueChanged<FiltroFechasResultado> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, RangoFechasDomi r) {
      final sel = seleccionado.rango == r;
      return ChoiceChip(
        label: Text(label),
        selected: sel,
        selectedColor: ColoresFoody.primario.withValues(alpha: 0.2),
        onSelected: (_) {
          if (r == RangoFechasDomi.custom) {
            _elegirCustom(context);
          } else {
            onChanged(FiltroFechasResultado(rango: r));
          }
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Hoy', RangoFechasDomi.hoy),
        chip('7 días', RangoFechasDomi.sieteDias),
        chip('Mes', RangoFechasDomi.mes),
        chip('Rango', RangoFechasDomi.custom),
      ],
    );
  }

  Future<void> _elegirCustom(BuildContext context) async {
    final ahora = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: ahora.subtract(const Duration(days: 365)),
      lastDate: ahora,
      initialDateRange: DateTimeRange(
        start: ahora.subtract(const Duration(days: 7)),
        end: ahora,
      ),
    );
    if (rango == null) return;
    onChanged(
      FiltroFechasResultado(
        rango: RangoFechasDomi.custom,
        desde: rango.start,
        hasta: rango.end,
      ),
    );
  }
}
