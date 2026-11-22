import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/salud_repository.dart';

/// Banner global cuando Nest no responde (INFRA-EXT-DOWN-01).
class ApiOfflineBanner extends StatefulWidget {
  const ApiOfflineBanner({super.key});

  @override
  State<ApiOfflineBanner> createState() => _ApiOfflineBannerState();
}

class _ApiOfflineBannerState extends State<ApiOfflineBanner> {
  bool _oculto = false;
  bool _offline = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _verificar();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _verificar());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _verificar() async {
    final viva = await SaludRepository().apiViva();
    if (!mounted) return;
    setState(() {
      _offline = !viva;
      if (viva) _oculto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto || !_offline) return const SizedBox.shrink();

    return Material(
      color: ColoresFoody.primario.withValues(alpha: 0.95),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_outlined, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sin conexión con el servidor Foody. Los cambios pueden fallar hasta que vuelva.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                onPressed: _verificar,
                tooltip: 'Reintentar',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.close, size: 18, color: Colors.white),
                onPressed: () => setState(() => _oculto = true),
                tooltip: 'Ocultar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
