import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/mesa/data/mesa_repository.dart';
import 'package:reserva_canchas/models/ciudad.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

/// Entrada por QR de mesa → carga menú y abre flujo cliente con mesa_id.
class MesaQrEntradaScreen extends StatefulWidget {
  const MesaQrEntradaScreen({super.key, required this.qrToken});

  final String qrToken;

  @override
  State<MesaQrEntradaScreen> createState() => _MesaQrEntradaScreenState();
}

class _MesaQrEntradaScreenState extends State<MesaQrEntradaScreen> {
  final _repo = MesaRepository();

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    try {
      final r = await _repo.menuPorQr(widget.qrToken);
      if (!mounted) return;
      if (!r.menu.sucursal.horarioActivo) {
        setState(() => _error = 'El restaurante está cerrado en este momento.');
        return;
      }

      final ciudad = r.menu.sucursal.ciudad;
      if (ciudad != null) {
        await CiudadPreferenceService.saveSelectedCiudad(
          Ciudad(
            id: ciudad.id,
            nombre: ciudad.nombre,
            codigo: ciudad.slug,
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      await MesaSesionService.activar(
        mesaId: r.mesaId,
        mesaNombre: r.mesaNombre,
        sucursalId: r.menu.sucursal.id,
        sucursalNombre: r.menu.sucursal.nombre,
        qrToken: widget.qrToken,
      );

      if (!mounted) return;
      context.go(
        '/menu/${r.menu.sucursal.id}'
        '?nombre=${Uri.encodeComponent(r.menu.sucursal.nombre)}'
        '&mesa_id=${r.mesaId}'
        '&mesa_nombre=${Uri.encodeComponent(r.mesaNombre)}',
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 48, color: ColoresFoody.error),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go('/cliente'),
                      child: const Text('Ir al inicio'),
                    ),
                  ],
                ),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando menú de tu mesa...'),
                ],
              ),
      ),
    );
  }
}
