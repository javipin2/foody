import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/promociones/data/promocion_vistos_service.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;
import 'package:video_player/video_player.dart';

/// Visor de estados (WhatsApp): varios clips/fotos del mismo restaurante.
class PromocionStoryViewer extends StatefulWidget {
  const PromocionStoryViewer({
    super.key,
    required this.promociones,
    this.indiceInicial = 0,
    this.sucursalIdFallback,
    this.sucursalNombreFallback,
  });

  final List<Map<String, dynamic>> promociones;
  final int indiceInicial;
  final String? sucursalIdFallback;
  final String? sucursalNombreFallback;

  @override
  State<PromocionStoryViewer> createState() => _PromocionStoryViewerState();
}

class _PromocionStoryViewerState extends State<PromocionStoryViewer>
    with SingleTickerProviderStateMixin {
  static const _duracionImagen = Duration(seconds: 5);
  static const _maxVideo = Duration(seconds: 30);
  static const _timeoutInit = Duration(seconds: 20);
  static const _umbralCierre = 120.0;
  static const _velocidadCierre = 800.0;

  final _repo = PromocionesRepository();
  late final PageController _pageController;
  late final AnimationController _progreso;
  int _indice = 0;
  bool _pausado = false;
  bool _ocultarChrome = false;
  double _dragY = 0;
  bool _hapticCierre = false;
  VideoPlayerController? _video;
  int _videoGen = 0;
  bool _videoError = false;

  /// Chrome bloquea autoplay con audio: empezamos mute en web.
  bool _videoMuteWeb = kIsWeb;

  @override
  void initState() {
    super.initState();
    _indice = widget.indiceInicial.clamp(0, widget.promociones.length - 1);
    _pageController = PageController(initialPage: _indice);
    _progreso = AnimationController(
      vsync: this,
      duration: _duracionImagen,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _siguiente();
      });
    _registrarVista(_indice);
    _prepararMedia(_indice);
  }

  @override
  void dispose() {
    _liberarVideo();
    _progreso.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _liberarVideo() {
    final v = _video;
    _video = null;
    v?.dispose();
  }

  bool _esVideo(Map<String, dynamic> p) =>
      (p['tipo_media'] as String?) == 'video';

  /// Texto relativo estilo WA: `ahora`, `2 min`, `12 h`, `ayer`.
  static String? _haceCuanto(Object? raw) {
    if (raw == null) return null;
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return null;
    final d = DateTime.now().difference(dt);
    if (d.isNegative || d.inSeconds < 45) return 'ahora';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    if (d.inHours < 24) return '${d.inHours} h';
    if (d.inDays == 1) return 'ayer';
    return '${d.inDays} d';
  }

  Future<void> _falloVideo(int gen) async {
    if (gen != _videoGen || !mounted) return;
    _liberarVideo();
    setState(() => _videoError = true);
    _progreso.duration = const Duration(seconds: 2);
    if (!_pausado) _progreso.forward();
  }

  Future<void> _prepararMedia(int i) async {
    if (i < 0 || i >= widget.promociones.length) return;
    final gen = ++_videoGen;
    _liberarVideo();
    _progreso.stop();
    _progreso.reset();
    if (mounted) {
      setState(() => _videoError = false);
    }

    final p = widget.promociones[i];
    final url = p['imagen_url'] as String? ?? '';

    if (!_esVideo(p) || url.isEmpty) {
      _progreso.duration = _duracionImagen;
      if (!_pausado && mounted && gen == _videoGen) {
        _progreso.forward();
      }
      return;
    }

    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = ctrl;
    try {
      await ctrl.initialize().timeout(_timeoutInit);
      if (!mounted || gen != _videoGen) {
        await ctrl.dispose();
        return;
      }
      var dur = ctrl.value.duration;
      if (dur <= Duration.zero) dur = _duracionImagen;
      if (dur > _maxVideo) dur = _maxVideo;
      _progreso.duration = dur;
      await ctrl.setLooping(false);
      // ponytail: autoplay web exige mute; al primer tap se activa el audio.
      if (kIsWeb) {
        _videoMuteWeb = true;
        await ctrl.setVolume(0);
      } else {
        _videoMuteWeb = false;
        await ctrl.setVolume(1);
      }
      if (mounted) setState(() {});
      if (!_pausado) {
        try {
          await ctrl.play();
        } catch (_) {
          // Autoplay bloqueado: frame ya visible; reintento en el próximo tap.
        }
        if (mounted && gen == _videoGen) _progreso.forward();
      }
    } catch (_) {
      await _falloVideo(gen);
    }
  }

  void _activarAudioSiWeb() {
    if (!kIsWeb || !_videoMuteWeb) return;
    final v = _video;
    if (v == null || !v.value.isInitialized) return;
    _videoMuteWeb = false;
    v.setVolume(1);
    if (!v.value.isPlaying) {
      v.play();
    }
  }

  Future<void> _registrarVista(int i) async {
    if (i < 0 || i >= widget.promociones.length) return;
    final id = widget.promociones[i]['id'] as String?;
    if (id == null) return;
    await PromocionVistosService.marcarVisto(id);
    try {
      await _repo.registrarVista(id);
    } catch (_) {}
  }

  Map<String, dynamic> get _actual => widget.promociones[_indice];

  String? _sucursalDe(Map<String, dynamic> p) {
    final id = p['sucursal_id'] as String?;
    if (id != null && id.isNotEmpty) return id;
    return widget.sucursalIdFallback;
  }

  String? _productoId(Map<String, dynamic> p) {
    final id = p['producto_id'];
    if (id is String && id.isNotEmpty) return id;
    return null;
  }

  void _pausar() {
    if (_pausado) return;
    _pausado = true;
    _progreso.stop();
    _video?.pause();
  }

  void _reanudar() {
    if (!_pausado) return;
    _pausado = false;
    _activarAudioSiWeb();
    _progreso.forward();
    _video?.play();
  }

  void _iniciarHold() {
    _pausar();
    if (!_ocultarChrome) {
      setState(() => _ocultarChrome = true);
    }
  }

  void _finHold() {
    if (_ocultarChrome) {
      setState(() => _ocultarChrome = false);
    }
    if (_dragY <= 0) _reanudar();
  }

  void _onDragStart(DragStartDetails _) {
    _pausar();
    _hapticCierre = false;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final next = (_dragY + d.delta.dy).clamp(0.0, 420.0);
    if (next == _dragY) return;
    setState(() => _dragY = next);
    if (_dragY >= _umbralCierre && !_hapticCierre) {
      _hapticCierre = true;
      HapticFeedback.lightImpact();
    } else if (_dragY < _umbralCierre) {
      _hapticCierre = false;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragY >= _umbralCierre || v > _velocidadCierre) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _dragY = 0;
      _ocultarChrome = false;
    });
    _reanudar();
  }

  void _siguiente() {
    _activarAudioSiWeb();
    if (_indice >= widget.promociones.length - 1) {
      Navigator.pop(context);
      return;
    }
    _irA(_indice + 1);
  }

  void _anterior() {
    _activarAudioSiWeb();
    if (_indice <= 0) {
      _progreso
        ..reset()
        ..forward();
      _video?.seekTo(Duration.zero);
      _video?.play();
      return;
    }
    _irA(_indice - 1);
  }

  void _irA(int i) {
    setState(() {
      _indice = i;
      _pausado = false;
      _ocultarChrome = false;
      _dragY = 0;
      _videoError = false;
    });
    _pageController.jumpToPage(i);
    _registrarVista(i);
    _prepararMedia(i);
  }

  void _navegarMenu({String? productoId}) {
    final p = _actual;
    final sid = _sucursalDe(p);
    if (sid == null || sid.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final nombre = (p['restaurante_nombre'] as String?)?.trim() ??
        (p['sucursal_nombre'] as String?)?.trim() ??
        widget.sucursalNombreFallback?.trim() ??
        '';
    final params = <String, String>{
      if (nombre.isNotEmpty) 'nombre': nombre,
      if (productoId != null) 'producto_id': productoId,
    };
    final q = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final destino = '/menu/$sid$q';

    final rootCtx = appNavigatorKey.currentContext;
    if (rootCtx == null) {
      Navigator.pop(context);
      return;
    }
    final router = GoRouter.of(rootCtx);
    String pathActual = '';
    try {
      pathActual = GoRouterState.of(rootCtx).uri.path;
    } catch (_) {}

    Navigator.pop(context);
    HapticFeedback.selectionClick();
    if (pathActual.startsWith('/menu/')) {
      router.pushReplacement(destino);
    } else {
      router.push(destino);
    }
  }

  Widget _ctaOval({
    required String etiqueta,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: Alignment.center,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
              color: Colors.white.withValues(alpha: 0.12),
            ),
            child: Text(
              etiqueta,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chrome({required Widget child}) {
    return IgnorePointer(
      ignoring: _ocultarChrome || _dragY > 24,
      child: AnimatedOpacity(
        opacity: _ocultarChrome ? 0 : (1 - (_dragY / 280)).clamp(0.0, 1.0),
        duration: Duration(milliseconds: _ocultarChrome || _dragY > 0 ? 120 : 180),
        child: child,
      ),
    );
  }

  Widget _mediaPage(Map<String, dynamic> p, int i) {
    final url = p['imagen_url'] as String? ?? '';
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF1A1A2E),
        child: Center(
          child: Icon(
            Icons.local_offer_rounded,
            color: Colors.white38,
            size: 72,
          ),
        ),
      );
    }

    if (_esVideo(p) && i == _indice) {
      if (_videoError) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No se pudo reproducir el video',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        );
      }
      final v = _video;
      if (v == null || !v.value.isInitialized) {
        return const ColoredBox(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: ColoresFoody.primario),
          ),
        );
      }
      return ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio:
                    v.value.aspectRatio == 0 ? 9 / 16 : v.value.aspectRatio,
                child: VideoPlayer(v),
              ),
            ),
            if (kIsWeb && _videoMuteWeb)
              _chrome(
                child: const Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 16, bottom: 140),
                    child: Icon(
                      Icons.volume_off_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (_esVideo(p)) {
      return const ColoredBox(color: Colors.black);
    }

    return ColoredBox(
      color: Colors.black,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: ColoresFoody.primario),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Text(
            'No se pudo cargar la imagen',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final productoId = _productoId(_actual);
    final tieneMenu = _sucursalDe(_actual) != null;
    final nombre = (_actual['restaurante_nombre'] as String?) ??
        widget.sucursalNombreFallback ??
        'Promoción';
    final hace = _haceCuanto(_actual['created_at']);
    final dragFactor = (1 - _dragY / 500).clamp(0.55, 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragY),
          child: Opacity(
            opacity: dragFactor,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.promociones.length,
                  itemBuilder: (context, i) =>
                      _mediaPage(widget.promociones[i], i),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 120,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 35,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPressStart: (_) => _iniciarHold(),
                          onLongPressEnd: (_) => _finHold(),
                          onLongPressCancel: _finHold,
                          onTap: _anterior,
                        ),
                      ),
                      Expanded(
                        flex: 65,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPressStart: (_) => _iniciarHold(),
                          onLongPressEnd: (_) => _finHold(),
                          onLongPressCancel: _finHold,
                          onTap: _siguiente,
                        ),
                      ),
                    ],
                  ),
                ),
                _chrome(
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [Color(0x99000000), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                _chrome(
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [Color(0xE6000000), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _chrome(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, topPad + 6, 10, 0),
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _progreso,
                            builder: (_, __) {
                              return Row(
                                children: List.generate(
                                  widget.promociones.length,
                                  (i) {
                                    double valor = 0;
                                    if (i < _indice) valor = 1;
                                    if (i == _indice) valor = _progreso.value;
                                    return Expanded(
                                      child: Container(
                                        height: 2.5,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white24,
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: FractionallySizedBox(
                                          alignment: Alignment.centerLeft,
                                          widthFactor: valor.clamp(0.0, 1.0),
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _AvatarMini(
                                logoUrl: _actual['logo_url'] as String?,
                                nombre: nombre,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (hace != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        hace,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.75),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _chrome(
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (((_actual['titulo'] as String?) ?? '')
                                .isNotEmpty)
                              Text(
                                _actual['titulo'] as String,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            if (((_actual['descripcion'] as String?) ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _actual['descripcion'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (productoId != null || tieneMenu) ...[
                              const SizedBox(height: 14),
                              _ctaOval(
                                etiqueta: productoId != null
                                    ? 'Ver producto'
                                    : 'Ver menú',
                                onPressed: () => _navegarMenu(
                                  productoId: productoId,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarMini extends StatelessWidget {
  const _AvatarMini({this.logoUrl, required this.nombre});

  final String? logoUrl;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 1.5),
        color: Colors.white24,
      ),
      clipBehavior: Clip.antiAlias,
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? Image.network(logoUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'F',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}
