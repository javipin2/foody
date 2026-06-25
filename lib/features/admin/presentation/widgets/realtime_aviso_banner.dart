import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/red/salud_repository.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Banner cuando Supabase Realtime no está operativo (P4.2 auditoría E2E).
class RealtimeAvisoBanner extends StatefulWidget {
  const RealtimeAvisoBanner({super.key});

  @override
  State<RealtimeAvisoBanner> createState() => _RealtimeAvisoBannerState();
}

class _RealtimeAvisoBannerState extends State<RealtimeAvisoBanner> {
  bool _oculto = false;
  bool? _conectado;
  String? _detalle;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    try {
      final r = await SaludRepository().verificarRealtime();
      if (!mounted) return;
      setState(() {
        _conectado = r.configurado && r.conectado;
        _detalle = r.detalle;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conectado = false;
        _detalle = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto || _conectado != false) return const SizedBox.shrink();

    final texto = _detalle != null && _detalle!.isNotEmpty
        ? 'Realtime desactivado: $_detalle. Kanban y mesas no se actualizan solos.'
        : 'Realtime desactivado. Kanban, mesas y cocina no se actualizan en vivo.';

    return Material(
      color: ColoresFoody.acento.withValues(alpha: 0.95),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 20, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _oculto = true),
                tooltip: 'Ocultar aviso',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
