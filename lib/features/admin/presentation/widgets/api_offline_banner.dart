import 'dart:async';

import 'package:flutter/material.dart';
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
  bool _verificando = false;
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
    if (_verificando) return;
    _verificando = true;
    final viva = await SaludRepository().apiViva();
    _verificando = false;
    if (!mounted) return;
    if (_offline == !viva) return;
    setState(() {
      _offline = !viva;
      if (viva) _oculto = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_oculto || !_offline) return const SizedBox.shrink();

    final esquema = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: esquema.errorContainer,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 20, color: esquema.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin conexión con el servidor Foody. Los cambios pueden fallar hasta que vuelva.',
                    style: TextStyle(
                      fontSize: 12,
                      color: esquema.onErrorContainer,
                      height: 1.35,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.refresh,
                      size: 18, color: esquema.onErrorContainer),
                  onPressed: _verificar,
                  tooltip: 'Reintentar',
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(Icons.close,
                      size: 18, color: esquema.onErrorContainer),
                  onPressed: () => setState(() => _oculto = true),
                  tooltip: 'Ocultar',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
