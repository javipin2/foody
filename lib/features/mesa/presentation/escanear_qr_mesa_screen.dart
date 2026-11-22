import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:reserva_canchas/core/rutas/ruta_mesa_util.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
import 'package:reserva_canchas/services/mesa_sesion_service.dart';

/// Escanea el QR impreso de la mesa con la cámara (móvil y web).
/// El cliente no pega enlaces: el QR ya apunta a `/mesa/{token}`.
class EscanearQrMesaScreen extends StatefulWidget {
  const EscanearQrMesaScreen({super.key});

  @override
  State<EscanearQrMesaScreen> createState() => _EscanearQrMesaScreenState();
}

class _EscanearQrMesaScreenState extends State<EscanearQrMesaScreen> {
  late final MobileScannerController _controlador = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _procesando = false;
  bool _sinCamara = false;
  bool _torchOn = false;
  String? _errorScan;
  MesaSesion? _sesionActiva;

  @override
  void initState() {
    super.initState();
    unawaited(_cargarSesion());
    if (!kIsWeb) {
      unawaited(_verificarPermisoCamara());
    }
  }

  Future<void> _cargarSesion() async {
    final s = await MesaSesionService.obtener();
    if (mounted) setState(() => _sesionActiva = s);
  }

  Future<void> _verificarPermisoCamara() async {
    final estado = await Permission.camera.status;
    if (estado.isDenied) {
      final pedido = await Permission.camera.request();
      if (!mounted) return;
      if (pedido.isPermanentlyDenied || pedido.isDenied) {
        setState(() => _sinCamara = true);
      }
    } else if (estado.isPermanentlyDenied) {
      setState(() => _sinCamara = true);
    }
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _irAMesa(String token) {
    if (_procesando) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _procesando = true;
      _errorScan = null;
    });
    context.go('/mesa/$token');
  }

  void _onDetectado(BarcodeCapture captura) {
    if (_procesando) return;
    final codigos = captura.barcodes;
    if (codigos.isEmpty) return;
    final raw = codigos.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    final token = RutaMesaUtil.tokenDesdeTextoQr(raw);
    if (token == null) {
      setState(() =>
          _errorScan = 'Ese QR no es de una mesa Foody. Escanea el de tu mesa.');
      return;
    }
    _irAMesa(token);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controlador.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Linterna no disponible en este dispositivo'),
        ),
      );
    }
  }

  Future<void> _reintentarCamara() async {
    setState(() {
      _sinCamara = false;
      _errorScan = null;
    });
    if (!kIsWeb) {
      await _verificarPermisoCamara();
    }
    try {
      await _controlador.start();
    } catch (_) {
      if (mounted) setState(() => _sinCamara = true);
    }
  }

  Widget _bannerSesion() {
    final s = _sesionActiva;
    if (s == null) return const SizedBox.shrink();
    return Material(
      color: AnaliticaTokens.surface,
      child: InkWell(
        onTap: () => context.go(s.rutaMenu),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AnaliticaTokens.border),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.table_restaurant_outlined,
                  color: AnaliticaTokens.ink, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ya estás en ${s.mesaNombre}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                    Text(
                      s.sucursalNombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Volver',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AnaliticaTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoSinCamara() {
    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surface,
                  borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                  border: Border.all(color: AnaliticaTokens.border),
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  size: 40,
                  color: AnaliticaTokens.ink,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Necesitamos la cámara',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AnaliticaTokens.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apunta al QR impreso en tu mesa para abrir el menú. '
                'Si el navegador bloqueó la cámara, permite el acceso y reintenta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _reintentarCamara,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Activar cámara'),
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text(
                    'Abrir ajustes del sistema',
                    style: TextStyle(color: AnaliticaTokens.inkMuted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaCamara() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controlador,
          onDetect: _onDetectado,
          errorBuilder: (context, error) {
            // Fallo al abrir cámara (permiso / HTTPS / sin device).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_sinCamara) {
                setState(() => _sinCamara = true);
              }
            });
            return const SizedBox.shrink();
          },
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
              ],
              stops: const [0, 0.22, 0.62, 1],
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton.filled(
            onPressed: _toggleTorch,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.45),
              foregroundColor: Colors.white,
            ),
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Linterna',
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Column(
            children: [
              if (_procesando)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              Text(
                _errorScan ?? 'Apunta al QR de tu mesa',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _errorScan != null
                      ? const Color(0xFFFFB4B4)
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  shadows: const [
                    Shadow(blurRadius: 10, color: Colors.black),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'El código está en la mesa del restaurante',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FoodyScaffoldCliente(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AnaliticaTokens.surface,
        foregroundColor: AnaliticaTokens.ink,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Escanear mesa',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AnaliticaTokens.ink,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          _bannerSesion(),
          Expanded(
            child: _sinCamara ? _estadoSinCamara() : _vistaCamara(),
          ),
        ],
      ),
    );
  }
}
