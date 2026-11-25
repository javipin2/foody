import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Pill pastel de estado (pedido / alerta).
class AnaliticaEstadoPill extends StatelessWidget {
  const AnaliticaEstadoPill({
    super.key,
    required this.etiqueta,
    this.tono = AnaliticaPillTono.neutro,
  });

  final String etiqueta;
  final AnaliticaPillTono tono;

  factory AnaliticaEstadoPill.pedido(String estado) {
    final e = estado.toLowerCase();
    final tono = switch (e) {
      'pendiente' ||
      'pendiente_aprobacion' ||
      'recibido' =>
        AnaliticaPillTono.pendiente,
      'en_cocina' || 'confirmado' || 'pagando' => AnaliticaPillTono.prep,
      'listo' || 'asignado' || 'en_camino' => AnaliticaPillTono.listo,
      'pagado' || 'entregado' => AnaliticaPillTono.ok,
      'cancelado' || 'rechazado' => AnaliticaPillTono.alerta,
      _ => AnaliticaPillTono.neutro,
    };
    return AnaliticaEstadoPill(
      etiqueta: _labelEstado(e),
      tono: tono,
    );
  }

  factory AnaliticaEstadoPill.alertaNivel(String nivel) {
    final n = nivel.toLowerCase();
    final tono = switch (n) {
      'critico' || 'alto' => AnaliticaPillTono.alerta,
      'medio' => AnaliticaPillTono.listo,
      _ => AnaliticaPillTono.prep,
    };
    return AnaliticaEstadoPill(etiqueta: n, tono: tono);
  }

  static String _labelEstado(String e) {
    return switch (e) {
      'pendiente_aprobacion' => 'Pendiente QR',
      'en_cocina' => 'En preparación',
      'para_llevar' => 'Para llevar',
      'en_camino' => 'En camino',
      _ => e.replaceAll('_', ' '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tono) {
      AnaliticaPillTono.pendiente => (
          const Color(0xFFFDE8E8),
          const Color(0xFFB42318),
        ),
      AnaliticaPillTono.prep => (
          ColoresFoody.secundario.withValues(alpha: 0.15),
          const Color(0xFF0F766E),
        ),
      AnaliticaPillTono.listo => (
          ColoresFoody.acento.withValues(alpha: 0.35),
          const Color(0xFF854F0B),
        ),
      AnaliticaPillTono.ok => (
          const Color(0xFFE3F6E8),
          const Color(0xFF16794C),
        ),
      AnaliticaPillTono.alerta => (
          ColoresFoody.primario.withValues(alpha: 0.12),
          ColoresFoody.primario,
        ),
      AnaliticaPillTono.neutro => (
          SaaSTokens.surfaceMuted(context),
          SaaSTokens.inkMuted(context),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

enum AnaliticaPillTono { pendiente, prep, listo, ok, alerta, neutro }
