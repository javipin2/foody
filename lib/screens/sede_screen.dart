import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/sede_provider.dart';
import '../models/ciudad.dart';
import '../models/lugar.dart';
import 'menu_sede_screen.dart';
import 'lugar_screen.dart';

class SedeScreen extends StatefulWidget {
  final Ciudad ciudad;
  final Lugar lugar;
  
  const SedeScreen({
    super.key,
    required this.ciudad,
    required this.lugar,
  });

  @override
  State<SedeScreen> createState() => _SedeScreenState();
}

class _SedeScreenState extends State<SedeScreen> {
  bool _isLoadingSedes = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sedeProvider = Provider.of<SedeProvider>(context, listen: false);
      sedeProvider.setLugar(widget.lugar.id);
      await sedeProvider.fetchSedes();

      if (!mounted) return;

      // Si el lugar tiene una única sede, evitamos mostrar el selector.
      final sedes = sedeProvider.sedes;
      if (sedes.length == 1) {
        final sedeNombre = (sedes.first['nombre'] as String? ?? '').trim();
        if (sedeNombre.isNotEmpty) {
          sedeProvider.setSede(sedeNombre);
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MenuSedeScreen(
                ciudad: widget.ciudad,
                lugar: widget.lugar,
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                );
                return FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 450),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      setState(() => _isLoadingSedes = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LugarScreen(ciudad: widget.ciudad),
          ),
        );
        return false;
      },
      child: Scaffold(
        body: _isLoadingSedes
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : SedeScreenContent(
                ciudad: widget.ciudad,
                lugar: widget.lugar,
              ),
      ),
    );
  }
}

// ==========================================
// SEDE SCREEN CONTENT
// ==========================================
class SedeScreenContent extends StatefulWidget {
  final Ciudad ciudad;
  final Lugar lugar;
  
  const SedeScreenContent({
    super.key,
    required this.ciudad,
    required this.lugar,
  });

  @override
  State<SedeScreenContent> createState() => _SedeScreenContentState();
}

class _SedeScreenContentState extends State<SedeScreenContent>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _scrollAnimationController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  final ScrollController _listScrollController = ScrollController();

  static const _primaryColor = Color(0xFF2E7D60);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scrollAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollAnimationController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }




  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  double _getMaxContentWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 1000;
    if (screenWidth > 768) return 700;
    return screenWidth;
  }

  double _getResponsiveSize(
      BuildContext context, double mobileSize, double desktopSize) {
    return _isLargeScreen(context) ? desktopSize : mobileSize;
  }

  void _seleccionarSede(BuildContext context, String sede) async {
    HapticFeedback.lightImpact();
    Provider.of<SedeProvider>(context, listen: false).setSede(sede);
    if (!mounted) return;

    final ciudad = widget.ciudad;
    final lugar = widget.lugar;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MenuSedeScreen(
              ciudad: ciudad,
              lugar: lugar,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curvedAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.95,
                  end: 1.0,
                ).animate(curvedAnimation),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  bool _sedePuedeAbrirMapa(Map<String, dynamic> sede) {
    final lat = (sede['latitud'] as num?)?.toDouble();
    final lon = (sede['longitud'] as num?)?.toDouble();
    final u = (sede['ubicacion'] as String?)?.trim() ?? '';
    return (lat != null && lon != null) || u.isNotEmpty;
  }

  String? _textoPieUbicacion(Map<String, dynamic> sede) {
    final u = (sede['ubicacion'] as String?)?.trim() ?? '';
    if (u.isNotEmpty) return u;
    final lat = (sede['latitud'] as num?)?.toDouble();
    final lon = (sede['longitud'] as num?)?.toDouble();
    if (lat != null && lon != null) return 'Ubicación';
    return null;
  }

  Future<void> _abrirUbicacionSedeEnMapa(
      BuildContext context, Map<String, dynamic> sede) async {
    final lat = (sede['latitud'] as num?)?.toDouble();
    final lon = (sede['longitud'] as num?)?.toDouble();
    final dir = (sede['ubicacion'] as String?)?.trim() ?? '';
    Uri? uri;
    if (lat != null && lon != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
      );
    } else if (dir.isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(dir)}',
      );
    }
    if (uri == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay ubicación registrada para esta sede.'),
        ),
      );
      return;
    }
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el mapa.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir mapa: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sedeProvider = Provider.of<SedeProvider>(context);
    final maxWidth = _getMaxContentWidth(context);

    return Container(
      color: Colors.grey[50],
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Stack(
        children: [
          Container(color: _headerBackground),
          Column(
            children: [
              _buildBlackHeader(context),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is ScrollUpdateNotification) {
                          final progress =
                              (notification.metrics.pixels / 200).clamp(0.0, 1.0);
                          _scrollAnimationController.value = progress;
                        }
                        return false;
                      },
                      child: _buildSedesList(context, sedeProvider, maxWidth),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    ),
    );
  }

  // Colores del header (diseño referencia)
  static const _headerBackground = Color(0xFF111624);
  static const _buttonBackground = Color(0xFF1A2033);
  static const _accentTeal = Color(0xFF2DD4BF);

  // Colores para tarjetas (diseño referencia sedes)
  static const _cardOverlayBg = Color(0xE6181818);
  static const _textPrimary = Color(0xFF1F2937);
  static const _textSecondary = Color(0xFF6B7280);
  static const _tagBg = Color(0xFFF3F4F6);

  Widget _buildBlackHeader(BuildContext context) {
    return AnimatedBuilder(
      animation: _scrollAnimationController,
      builder: (context, child) {
        final progress = _scrollAnimationController.value;
        final headerHeight = 80.0 + (120.0 * (1.0 - progress));
        final opacity = 1.0 - progress;
        return ClipPath(
          child: Container(
            height: headerHeight.clamp(80.0, 170.0),
            decoration: const BoxDecoration(
              color: _headerBackground,
            ),
            child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra superior: atrás | Sedes (centrado) | hueco simétrico
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  LugarScreen(ciudad: widget.ciudad),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: _buttonBackground,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Sedes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                  if (progress < 0.95) ...[
                    const SizedBox(height: 12),
                    Flexible(
                      child: Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Indicador de lugar: icono + nombre en verde/turquesa
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: _accentTeal,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    widget.lugar.nombre.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _accentTeal,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Selecciona una sede',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildSedesList(
      BuildContext context, SedeProvider sedeProvider, double maxWidth) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: sedeProvider.sedes.isEmpty
            ? _buildEmptyState(context)
            : _buildSedesListWithSoftwareLink(sedeProvider, context),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Icon(
                  Icons.location_off_outlined,
                  size: _getResponsiveSize(context, 64.0, 80.0),
                  color: Colors.grey[400],
                ),
              );
            },
          ),
          SizedBox(height: _getResponsiveSize(context, 16.0, 20.0)),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              'No hay sedes disponibles',
              style: TextStyle(
                fontSize: _getResponsiveSize(context, 18.0, 22.0),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSedesListWithSoftwareLink(
      SedeProvider sedeProvider, BuildContext context) {
    // Padding inferior generoso para que la última tarjeta no se recorte al bajar
    final bottomPadding = MediaQuery.of(context).padding.bottom + 56;
    return SingleChildScrollView(
      controller: _listScrollController,
      physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(255, 255, 255, 255)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: Color.fromARGB(255, 0, 0, 0),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Todas las sedes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(
            sedeProvider.sedes.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildSedeCardAnimated(sedeProvider, index, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSedeCardAnimated(
      SedeProvider sedeProvider, int index, BuildContext context) {
    final sede = sedeProvider.sedes[index];
    final nombreSede = sede['nombre'] as String;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 100 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, 0.5),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  0.3 + (index * 0.1),
                  0.7 + (index * 0.1),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
            child: Hero(
              tag: 'sede_$nombreSede',
              child: _buildSedeCard(context, sede),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSedeCard(BuildContext context, Map<String, dynamic> sedeData) {
    final title = sedeData['nombre'] as String;
    final imageUrl = sedeData['imagen'] as String;
    final sede = title;
    final descripcion = sedeData['descripcion'] as String? ?? '';
    final mapaOk = _sedePuedeAbrirMapa(sedeData);
    final pieUbicacion = _textoPieUbicacion(sedeData);

    const imageHeight = 180.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _seleccionarSede(context, sede),
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.black.withOpacity(0.06),
          highlightColor: Colors.black.withOpacity(0.04),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      width: double.infinity,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: CircularProgressIndicator(
                                color: _primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: _textSecondary,
                                size: 40,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          if (!mapaOk) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No hay ubicación registrada para esta sede (coordenadas o dirección).',
                                ),
                              ),
                            );
                            return;
                          }
                          HapticFeedback.lightImpact();
                          _abrirUbicacionSedeEnMapa(context, sedeData);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: _cardOverlayBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 20,
                            color: mapaOk ? _accentTeal : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    if (pieUbicacion != null)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: _cardOverlayBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  color: _accentTeal, size: 16),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  pieUbicacion,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (descripcion.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          descripcion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: _textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _tagBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'SEDE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _tagBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'CANCHAS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ],
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

