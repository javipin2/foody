import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/red/salud_repository.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Banner cuando Supabase Realtime no está operativo (R9).
class RealtimeAvisoBanner extends StatefulWidget {
  const RealtimeAvisoBanner({super.key, this.repository});

  final SaludRepository? repository;

  @override
  State<RealtimeAvisoBanner> createState() => _RealtimeAvisoBannerState();
}

class _RealtimeAvisoBannerState extends State<RealtimeAvisoBanner> {
  bool _oculto = false;
  bool? _conectado;
  bool? _configurado;
  Timer? _reverificacion;

  @override
  void initState() {
    super.initState();
    _verificar();
    _reverificacion = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _verificar(),
    );
  }

  @override
  void dispose() {
    _reverificacion?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    try {
      final r = await (widget.repository ?? SaludRepository()).verificarRealtime();
      if (!mounted) return;
      setState(() {
        _conectado = r.configurado && r.conectado;
        _configurado = r.configurado;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _conectado = false;
        _configurado = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto || _conectado != false) return const SizedBox.shrink();

    final texto = switch (_configurado) {
      false => 'Las actualizaciones en vivo no están configuradas. '
          'Foody seguirá actualizando Kanban, mesas y cocina cada 45–90 s; '
          'Inicio, cada ~75 s.',
      true => 'Las actualizaciones en vivo no están disponibles temporalmente. '
          'Foody seguirá actualizando Kanban, mesas y cocina cada 45–90 s; '
          'Inicio, cada ~75 s.',
      _ => 'No se pudo comprobar la conexión en vivo. '
          'Foody seguirá actualizando Kanban, mesas y cocina cada 45–90 s; '
          'Inicio, cada ~75 s.',
    };

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
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _verificar,
                tooltip: 'Reverificar Realtime',
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
