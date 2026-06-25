import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:collection';
import 'dart:math' as math;

import '../providers/lugar_provider.dart';
import '../services/push_notification_service.dart';
import '../services/lugar_ambient_music_service.dart';
import '../services/shared_lugar_link_service.dart';
import '../services/index_error_service.dart';
import '../models/ciudad.dart';
import '../models/lugar.dart';
import '../models/cancha.dart';
import '../models/horario.dart';
import 'sede_screen.dart';
import 'ciudad_screen.dart';
import 'detalles_screen.dart';
import 'admin/admin_login_screen.dart';
import 'package:intl/intl.dart';

/// Máx. valores en `whereIn` (Firestore). Una búsqueda de disponibilidad usa ~4 consultas por lote de lugares.
const int _kDisponibilidadWhereInMax = 30;

List<List<T>> _chunkDisponibilidad<T>(List<T> list, int size) {
  if (list.isEmpty) return [];
  final out = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    final end = math.min(i + size, list.length);
    out.add(list.sublist(i, end));
  }
  return out;
}

/// Una fila de disponibilidad por cancha en el modal de búsqueda (fecha/hora).
class _CanchaSlotDisponibilidad {
  final String canchaId;
  final String nombre;
  final String sedeId;
  final String sedeNombre;
  /// disponible | apartada | procesando
  final String estado;
  final double? precio;
  final bool tienePromo;

  const _CanchaSlotDisponibilidad({
    required this.canchaId,
    required this.nombre,
    required this.sedeId,
    required this.sedeNombre,
    required this.estado,
    this.precio,
    this.tienePromo = false,
  });
}

/// Nombre y ubicación de sede para el modal de disponibilidad.
class _SedeDatosUbicacion {
  final String nombre;
  final double? latitud;
  final double? longitud;
  final String? direccion;

  const _SedeDatosUbicacion({
    required this.nombre,
    this.latitud,
    this.longitud,
    this.direccion,
  });

  bool get tieneCoordenadas =>
      latitud != null && longitud != null;
  bool get tieneDireccion =>
      (direccion != null && direccion!.trim().isNotEmpty);
  bool get puedeMostrarEnMapa => tieneCoordenadas || tieneDireccion;
}

class _SedeUbicacionInfo {
  final List<Map<String, dynamic>> sedes;

  const _SedeUbicacionInfo({required this.sedes});

  bool get tieneSedes => sedes.isNotEmpty;
  bool get tieneUbicacionDisponible =>
      sedes.any((s) => (s['latitud'] as double?) != null && (s['longitud'] as double?) != null);
}

class LugarScreen extends StatefulWidget {
  final Ciudad ciudad;

  /// `true` al venir de la sesión **Ciudades** (o splash): reinicia la música desde el inicio.
  /// `false` al volver desde sede/canchas/etc.: la música sigue sin repetirse desde cero.
  final bool restartAmbientMusic;

  const LugarScreen({
    super.key,
    required this.ciudad,
    this.restartAmbientMusic = false,
  });

  @override
  State<LugarScreen> createState() => _LugarScreenState();
}

class _LugarScreenState extends State<LugarScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _scrollAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _headerOpacityAnimation;
  late Animation<double> _headerScaleAnimation;
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // Estado para favoritos
  Set<String> _favoriteLugares = {};
  int _currentPageIndex = 0; // 0 = Disponible, 1 = Favoritos
  late PageController _pageController;

  // Control de cambio de pestañas para evitar spam rápido (especialmente en web)
  DateTime _lastTabChange = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _minTabChangeInterval = Duration(milliseconds: 600);

  // Promociones
  String _todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  
  // ✅ NUEVO: Información de promoción activa
  Map<String, dynamic>? _promocionActiva; // {precio_promocional, promoId, cancha_id, horario}

  // Colores del header (mismo diseño que sede_screen)
  static const _headerBackground = Color(0xFF111624);
  static const _buttonBackground = Color(0xFF1A2033);
  static const _accentTeal = Color(0xFF2DD4BF);

  // Colores para tarjetas (mismo estilo que sedes)
  static const _cardOverlayBg = Color(0xE6181818);
  static const _textPrimary = Color(0xFF1F2937);
  static const _textSecondary = Color(0xFF6B7280);
  static const _tagBg = Color(0xFFF3F4F6);
  static const _primaryGreen = Color(0xFF2E7D60);
  bool _resolviendoLugarCompartido = false;
  final Map<String, Future<_SedeUbicacionInfo>> _sedeUbicacionFutures = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPageIndex);
    
    // Animación principal de entrada
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación para efectos de scroll
    _scrollAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Animaciones para el header dinámico
    _headerOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.easeInOut,
    ));

    _headerScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _scrollAnimationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
    
    // Cargar lugares al inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (LugarAmbientMusicService.ambientMusicEnabled) {
        LugarAmbientMusicService.instance.ensurePlayingFromLugaresEntry(
          fromCiudadFlow: widget.restartAmbientMusic,
        );
      }
      final lugarProvider = Provider.of<LugarProvider>(context, listen: false);
      await lugarProvider.fetchLugaresPorCiudad(widget.ciudad.id);
      _loadFavorites();
      // Asegurar que el token FCM quede registrado con la ciudad actual en caché.
      PushNotificationService().registerTokenWithCurrentCiudad();
      await _intentarAbrirLugarCompartidoPendiente();
    });
  }
  
  void _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final favoritesJson = prefs.getString('favorite_lugares_${widget.ciudad.id}');
    if (favoritesJson != null) {
      final List<dynamic> favoritesList = json.decode(favoritesJson);
      setState(() {
        _favoriteLugares = favoritesList.map((e) => e.toString()).toSet();
      });
    }
  }
  
  void _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = json.encode(_favoriteLugares.toList());
    await prefs.setString('favorite_lugares_${widget.ciudad.id}', favoritesJson);
  }
  
  void _toggleFavorite(String lugarId) {
    setState(() {
      if (_favoriteLugares.contains(lugarId)) {
        _favoriteLugares.remove(lugarId);
      } else {
        _favoriteLugares.add(lugarId);
      }
    });
    _saveFavorites();
  }

  Future<void> _compartirLugar(Lugar lugar) async {
    try {
      final uri = SharedLugarLinkService.buildShareUri(
        lugarId: lugar.id,
        ciudadId: widget.ciudad.id,
      );
      final texto =
          'Te comparto este lugar en TuCanchaFacil:\n${lugar.nombre}\n${lugar.direccion}\n\n$uri';
      await SharePlus.instance.share(
        ShareParams(
          text: texto,
          subject: 'Lugar recomendado: ${lugar.nombre}',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo compartir el lugar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<_SedeUbicacionInfo> _getSedeUbicacionInfo(String lugarId) {
    return _sedeUbicacionFutures.putIfAbsent(lugarId, () async {
      final snapshot = await FirebaseFirestore.instance
          .collection('sede')
          .where('lugarId', isEqualTo: lugarId)
          .where('activa', isEqualTo: true)
          .orderBy('nombre')
          .get();

      final sedes = snapshot.docs.map((doc) {
        final d = doc.data();
        final lat = (d['latitud'] as num?)?.toDouble();
        final lon = (d['longitud'] as num?)?.toDouble();
        return <String, dynamic>{
          'id': doc.id,
          'nombre': (d['nombre'] as String? ?? '').trim(),
          'latitud': lat,
          'longitud': lon,
          'tieneUbicacion': lat != null && lon != null,
        };
      }).toList();

      return _SedeUbicacionInfo(sedes: sedes);
    });
  }

  Future<void> _abrirUbicacionLugar(Lugar lugar, _SedeUbicacionInfo info) async {
    if (!info.tieneUbicacionDisponible) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Este lugar no tiene ubicaciones configuradas'),
          backgroundColor: Colors.orange.shade700,
        ),
      );
      return;
    }

    if (info.sedes.length <= 1) {
      final sede = info.sedes.firstWhere(
        (s) => s['tieneUbicacion'] == true,
        orElse: () => <String, dynamic>{},
      );
      final lat = sede['latitud'] as double?;
      final lon = sede['longitud'] as double?;
      if (lat != null && lon != null) {
        await _abrirCoordenadasEnMapa(lat, lon);
      }
      return;
    }

    await _mostrarModalSelectorSedeUbicacion(lugar, info);
  }

  Future<void> _abrirCoordenadasEnMapa(double latitud, double longitud) async {
    final urls = [
      Uri.parse('google.navigation:q=$latitud,$longitud'),
      Uri.parse('geo:0,0?q=$latitud,$longitud'),
      Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud'),
    ];

    for (final url in urls) {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No se pudo abrir la ubicación'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _mostrarModalSelectorSedeUbicacion(
    Lugar lugar,
    _SedeUbicacionInfo info,
  ) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ubicaciones de ${lugar.nombre}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...info.sedes.map((sede) {
                    final nombre = (sede['nombre'] as String?) ?? 'Sede';
                    final disponible = sede['tieneUbicacion'] == true;
                    final lat = sede['latitud'] as double?;
                    final lon = sede['longitud'] as double?;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.location_on_rounded,
                        color: disponible ? const Color(0xFF2DD4BF) : Colors.grey,
                      ),
                      title: Text(nombre),
                      subtitle: Text(
                        disponible ? 'Ubicación disponible' : 'Ubicación no configurada',
                        style: TextStyle(
                          color: disponible ? Colors.black54 : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      enabled: disponible,
                      trailing: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: disponible ? Colors.black54 : Colors.grey,
                      ),
                      onTap: !disponible
                          ? null
                          : () async {
                              Navigator.pop(context);
                              if (lat != null && lon != null) {
                                await _abrirCoordenadasEnMapa(lat, lon);
                              }
                            },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _intentarAbrirLugarCompartidoPendiente() async {
    if (_resolviendoLugarCompartido || !mounted) return;
    _resolviendoLugarCompartido = true;
    try {
      final payload =
          await SharedLugarLinkService.consumeIfMatchesCity(widget.ciudad.id);
      if (payload == null || !mounted) return;

      final lugarProvider = Provider.of<LugarProvider>(context, listen: false);
      Lugar? destino;
      for (final l in lugarProvider.lugares) {
        if (l.id == payload.lugarId) {
          destino = l;
          break;
        }
      }

      if (destino == null) {
        final doc = await FirebaseFirestore.instance
            .collection('lugares')
            .doc(payload.lugarId)
            .get();
        final data = doc.data();
        if (doc.exists &&
            data != null &&
            data['ciudadId'] == widget.ciudad.id) {
          destino = Lugar.fromFirestore(data, doc.id);
        }
      }

      if (destino == null || !mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SedeScreen(ciudad: widget.ciudad, lugar: destino!),
        ),
      );
    } finally {
      _resolviendoLugarCompartido = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildLugarMusicControl({required bool floating}) {
    if (!LugarAmbientMusicService.ambientMusicEnabled) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: LugarAmbientMusicService.instance,
      builder: (context, _) {
        final muted = LugarAmbientMusicService.instance.isMuted;
        final button = Tooltip(
          message: muted ? 'Activar música' : 'Silenciar música',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => LugarAmbientMusicService.instance.toggleMuted(),
              customBorder: const CircleBorder(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: _buttonBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        );
        if (floating) {
          return Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: button,
              ),
            ),
          );
        }
        return button;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navegar a CiudadScreen al presionar atrás
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CiudadScreen()),
        );
        return false;
      },
      child: Scaffold(
      backgroundColor: Colors.grey[50],
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<LugarProvider>(
            builder: (context, lugarProvider, child) {
              if (lugarProvider.isLoading) {
                return Stack(
                  children: [
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2E7D60)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Cargando lugares...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildLugarMusicControl(floating: true),
                  ],
                );
              }

              if (lugarProvider.errorMessage != null) {
                return Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lugarProvider.errorMessage!,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => lugarProvider.fetchLugaresPorCiudad(widget.ciudad.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                    _buildLugarMusicControl(floating: true),
                  ],
                );
              }

              if (lugarProvider.lugares.isEmpty) {
                return Stack(
                  children: [
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No hay lugares disponibles',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildLugarMusicControl(floating: true),
                  ],
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                _intentarAbrirLugarCompartidoPendiente();
              });
              return _buildCustomScrollView(lugarProvider.lugares);
            },
          ),
        ),
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentPageIndex,
          height: 68,
          indicatorColor: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.12),
          surfaceTintColor: Colors.white,
          overlayColor: WidgetStateProperty.resolveWith((_) => Colors.transparent),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on, color: Color.fromARGB(255, 0, 0, 0)),
              label: 'Disponible',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite, color: Color.fromARGB(255, 0, 0, 0)),
              label: 'Favoritos',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_offer_outlined),
              selectedIcon: Icon(Icons.local_offer, color: Color.fromARGB(255, 0, 0, 0)),
              label: 'Promociones',
            ),
          ],
          onDestinationSelected: (index) {
            final now = DateTime.now();
            // Evitar cambios muy rápidos de pestaña (debounce)
            if (index == _currentPageIndex ||
                now.difference(_lastTabChange) < _minTabChangeInterval) {
              return;
            }
            _lastTabChange = now;

            setState(() {
              _currentPageIndex = index;
            });
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
      ),
    );
  }

  Widget _buildCustomScrollView(List<Lugar> lugares) {
  return Stack(
    children: [
      Container(color: _headerBackground),
      Column(
        children: [
          AnimatedBuilder(
            animation: _scrollAnimationController,
            builder: (context, child) {
              final progress = _scrollAnimationController.value;
              final headerHeight = 80.0 + (120.0 * (1.0 - progress));
              final opacity = 1.0 - progress;

              return Container(
                height: headerHeight.clamp(80.0, 200.0),
                decoration: const BoxDecoration(
                  color: _headerBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Descubre',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            _buildLugarMusicControl(floating: false),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showSearchFilter,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: _buttonBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.search, color: Colors.white, size: 22),
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 48),
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: _buttonBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                              ),
                              tooltip: 'Opciones',
                              onSelected: (value) async {
                                if (value == 'change_city') {
                                  _showChangeCityDialog();
                                } else if (value == 'admin_access') {
                                  if (LugarAmbientMusicService.ambientMusicEnabled) {
                                    await LugarAmbientMusicService.instance
                                        .stopForAdministrativeSession();
                                  }
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(
                                  value: 'change_city',
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_city, color: Color.fromARGB(255, 0, 0, 0)),
                                      SizedBox(width: 8),
                                      Text('Cambiar Ciudad'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'admin_access',
                                  child: Row(
                                    children: [
                                      Icon(Icons.admin_panel_settings, color: Color.fromARGB(255, 0, 0, 0)),
                                      SizedBox(width: 8),
                                      Text('Acceso administrativo'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (progress < 0.95) ...[
                          const SizedBox(height: 12),
                          Flexible(
                            child: Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Lugares Deportivos',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Encuentra los mejores lugares en ${widget.ciudad.nombre}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.85),
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Text(
                                          'Categorías',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildCategoryChip('Fútbol', Icons.sports_soccer, _accentTeal),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Contenido blanco principal
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
              child: Column(
                children: [
                  // Indicador de filtros aplicados (solo en pestaña Disponible)
                  if (_selectedDate != null && _selectedTime != null && _currentPageIndex == 0)
                    _buildFilterIndicator(),
                  // Contenido principal con detección de scroll
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is ScrollUpdateNotification) {
                          // Calcular el progreso del scroll (0.0 a 1.0)
                          final scrollProgress = (notification.metrics.pixels / 200).clamp(0.0, 1.0);
                          _scrollAnimationController.value = scrollProgress;
                        }
                        return false;
                      },
                      child: _buildPageView(lugares),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}


  Widget _buildCategoryChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
              borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }


  // Reemplazado por BottomNavigationBar

  Widget _buildPageView(List<Lugar> lugares) {
    return PageView(
      controller: _pageController,
      physics: const ClampingScrollPhysics(),
      onPageChanged: (index) {
        if (!mounted) return;
        _lastTabChange = DateTime.now();
        setState(() {
          _currentPageIndex = index;
        });
      },
      children: [
        _buildAvailableContent(lugares),
        _buildFavoritesContent(lugares),
        _buildPromotionsContent(lugares),
      ],
    );
  }

  static const double _kLugarGridBreakpoint = 880.0;

  int _crossAxisCountForLugares(double maxWidth) {
    if (maxWidth >= 1500) return 4;
    if (maxWidth >= 1180) return 3;
    if (maxWidth >= _kLugarGridBreakpoint) return 2;
    return 1;
  }

  /// `width / height` por celda del grid (tarjeta más alta que ancha → ratio > 1).
  double _lugarGridChildAspectRatio(int crossAxisCount) {
    switch (crossAxisCount) {
      case 4:
        return 1.10;
      case 3:
        return 1.22;
      case 2:
        return 1.42;
      default:
        return 1.45;
    }
  }

  Widget _buildLugaresSectionHeader({
    required IconData icon,
    required List<Color> iconGradient,
    required Color iconColor,
    required String title,
    double iconPadding = 5,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(iconPadding),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: iconGradient.last.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableContent(List<Lugar> lugares) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final cross = _crossAxisCountForLugares(maxW);
        final header = _buildLugaresSectionHeader(
          icon: Icons.location_city,
          iconGradient: const [
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 255, 255, 255),
          ],
          iconColor: const Color.fromARGB(255, 0, 0, 0),
          title: 'Todos los Lugares',
        );

        if (cross == 1) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                ...lugares.map((lugar) => _buildEnhancedFavoriteCard(lugar)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: _lugarGridChildAspectRatio(cross),
                ),
                itemCount: lugares.length,
                itemBuilder: (context, i) =>
                    _buildEnhancedFavoriteCard(lugares[i], gridTile: true),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoritesContent(List<Lugar> lugares) {
    final favoriteLugares = lugares.where((lugar) => _favoriteLugares.contains(lugar.id)).toList();
    
    if (favoriteLugares.isEmpty) {
      return Center(
                      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                        children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
                          Text(
              'No tienes lugares favoritos',
                            style: TextStyle(
                fontSize: 18,
                              color: Colors.grey[600],
                fontWeight: FontWeight.w500,
                            ),
                          ),
            const SizedBox(height: 8),
                          Text(
              'Toca el corazón en cualquier lugar para agregarlo a favoritos',
                            style: TextStyle(
                fontSize: 14,
                              color: Colors.grey[500],
                            ),
              textAlign: TextAlign.center,
                          ),
                        ],
                      ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = _crossAxisCountForLugares(constraints.maxWidth);
        final favHeader = Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D60), Color(0xFF4CAF50)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2E7D60).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Mis Favoritos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );

        if (cross == 1) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                favHeader,
                ...favoriteLugares.map((lugar) => _buildEnhancedFavoriteCard(lugar)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              favHeader,
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: _lugarGridChildAspectRatio(cross),
                ),
                itemCount: favoriteLugares.length,
                itemBuilder: (context, i) =>
                    _buildEnhancedFavoriteCard(favoriteLugares[i], gridTile: true),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildPromotionsContent(List<Lugar> lugares) {
    // Solo construir los streams cuando la pestaña de Promociones está activa (index 2)
    // Esto evita crear/destruir listeners de Firestore al cambiar de tab
    if (_currentPageIndex != 2) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD4A843).withOpacity(0.5), width: 1),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: Color(0xFFD4A843),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Promociones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          ...lugares.map((lugar) => _buildLugarPromotions(lugar)).toList(),
          // Mensaje cuando no hay promociones visibles
          Builder(builder: (context) {
            // Verificar si algún lugar tiene promos visibles (los widgets no-vacíos)
            // Usamos un StreamBuilder ligero solo para saber si hay datos
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('promociones')
                  .where('activo', isEqualTo: true)
                  .where('fecha', isGreaterThanOrEqualTo: _todayStr)
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                final hayPromos = snap.hasData && snap.data!.docs.isNotEmpty;
                if (hayPromos) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.local_offer_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Sin promociones por el momento',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Las ofertas aparecerán aquí cuando estén disponibles',
                          style: TextStyle(fontSize: 12, color: Colors.grey[350]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLugarPromotions(Lugar lugar) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('promociones')
          .where('lugarId', isEqualTo: lugar.id)
          .where('activo', isEqualTo: true)
          .where('fecha', isGreaterThanOrEqualTo: _todayStr)
          .orderBy('fecha')
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF2E7D60),
              backgroundColor: Colors.transparent,
            ),
          );
        }

        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        // Un solo stream de reservas por lugar (evita muchos listeners y el error del SDK en web)
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservas')
              .where('lugarId', isEqualTo: lugar.id)
              .where('fecha', isGreaterThanOrEqualTo: _todayStr)
              .limit(100)
              .snapshots(),
          builder: (context, resSnap) {
            if (resSnap.hasError) {
              return _buildPromocionesBlock(lugar, docs, []);
            }
            final reservasDocs = resSnap.data?.docs ?? [];

            return _buildPromocionesBlock(lugar, docs, reservasDocs);
          },
        );
      },
    );
  }

  /// Construye el bloque de promos de un lugar, agrupadas por fecha.
  Widget _buildPromocionesBlock(
    Lugar lugar,
    List<QueryDocumentSnapshot<Object?>> promoDocs,
    List<QueryDocumentSnapshot<Object?>> reservasDocs,
  ) {
    // Filtrar promos válidas (sin reserva, no vencidas) y agrupar por fecha
    final List<_PromoVisible> visibles = [];
    final now = DateTime.now();
    final hoyStr = DateFormat('yyyy-MM-dd').format(now);

    for (final d in promoDocs) {
      final data = (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final promoId = d.id;
      final fecha = (data['fecha'] as String? ?? '').trim();
      final canchaId = (data['cancha_id'] as String? ?? '').trim();
      final horarioPromo = (data['horario'] as String? ?? '').trim();

      if (fecha.isEmpty || canchaId.isEmpty) continue;

      // Filtrar promociones vencidas: si es hoy y la hora ya pasó, no mostrar
      if (fecha == hoyStr && horarioPromo.isNotEmpty) {
        final hora24 = _convertirHora12A24(horarioPromo);
        if (now.hour >= hora24) continue;
      }
      // Fechas anteriores a hoy ya están filtradas por la query (fecha >= _todayStr)

      final horarioPromoNormalizado = Horario.normalizarHora(horarioPromo);
      bool ocultar = false;

      for (final r in reservasDocs) {
        final rd = (r.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        if ((rd['fecha'] as String? ?? '').trim() != fecha) continue;
        if ((rd['cancha_id'] as String? ?? '').trim() != canchaId) continue;
        final hRes = Horario.normalizarHora((rd['horario'] as String? ?? '').trim());
        if (hRes == horarioPromoNormalizado) {
          ocultar = true;
          break;
        }
      }

      if (!ocultar) {
        visibles.add(_PromoVisible(fecha: fecha, data: data, promoId: promoId));
      }
    }

    // ✅ Deduplicar: solo una promoción por (fecha, cancha, horario). Si hay varias, mostrar la de mejor precio (menor precio_promocional).
    final Map<String, _PromoVisible> unicasPorSlot = {};
    for (final p in visibles) {
      final fechaP = (p.data['fecha'] as String? ?? '').trim();
      final canchaIdP = (p.data['cancha_id'] as String? ?? '').trim();
      final horarioNorm = Horario.normalizarHora((p.data['horario'] as String? ?? '').trim());
      final key = '$fechaP|$canchaIdP|$horarioNorm';
      final precioPromo = (p.data['precio_promocional'] as num?)?.toDouble();
      final existente = unicasPorSlot[key];
      if (existente == null) {
        unicasPorSlot[key] = p;
      } else {
        final precioExistente = (existente.data['precio_promocional'] as num?)?.toDouble();
        if (precioPromo != null && (precioExistente == null || precioPromo < precioExistente)) {
          unicasPorSlot[key] = p;
        }
      }
    }
    final visiblesUnicas = unicasPorSlot.values.toList();

    if (visiblesUnicas.isEmpty) return const SizedBox.shrink();

    // Agrupar por fecha preservando orden
    final LinkedHashMap<String, List<_PromoVisible>> porFecha = LinkedHashMap();
    for (final p in visiblesUnicas) {
      porFecha.putIfAbsent(p.fecha, () => []).add(p);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del lugar minimalista
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lugar.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.grey[600],
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${visiblesUnicas.length} oferta${visiblesUnicas.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Promos agrupadas por fecha
          ...porFecha.entries.map((entry) {
            final fechaStr = entry.key;
            final promos = entry.value;
            String label = '';
            try {
              final dt = DateTime.parse(fechaStr);
              final now = DateTime.now();
              final hoy = DateTime(now.year, now.month, now.day);
              final diff = dt.difference(hoy).inDays;
              if (diff == 0) {
                label = 'Hoy';
              } else if (diff == 1) {
                label = 'Mañana';
              } else {
                label = DateFormat('EEEE d MMM', 'es').format(dt);
                label = label[0].toUpperCase() + label.substring(1);
              }
            } catch (_) {
              label = fechaStr;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado de fecha
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6, left: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A843),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(height: 0.5, color: Colors.grey[300]),
                      ),
                    ],
                  ),
                ),
                ...promos.map((p) => _buildPromoCard(lugar, p.data, p.promoId)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPromoCard(Lugar lugar, Map<String, dynamic> data, String promoId) {
    final fechaStr = (data['fecha'] as String? ?? '').trim();
    final horario = (data['horario'] as String? ?? '').trim();
    final precioPromo = (data['precio_promocional'] as num?)?.toDouble();
    final precioOriginal = (data['precio_original'] as num?)?.toDouble();
    final canchaNombre = (data['cancha_nombre'] as String? ?? '').trim();
    final nota = (data['nota'] as String? ?? '').trim();
    DateTime? fecha;
    String fechaBonita = '';
    try {
      fecha = DateTime.parse(fechaStr);
      fechaBonita = DateFormat('EEE d MMM', 'es').format(fecha).toUpperCase();
    } catch (_) {}

    double? descuentoPct;
    if (precioOriginal != null && precioPromo != null && precioOriginal > 0 && precioPromo < precioOriginal) {
      descuentoPct = (1 - (precioPromo / precioOriginal)) * 100;
    }

    return _PremiumPromoCard(
      lugar: lugar,
      fechaBonita: fechaBonita,
      horario: horario,
      canchaNombre: canchaNombre,
      nota: nota,
      precioPromo: precioPromo,
      precioOriginal: precioOriginal,
      descuentoPct: descuentoPct,
      onReservar: () => _onSelectPromotion(lugar, data, promoId),
    );
  }

  void _onSelectPromotion(Lugar lugar, Map<String, dynamic> promo, String promoId) async {
    try {
      final fechaStr = (promo['fecha'] as String? ?? '').trim();
      final horarioStr = (promo['horario'] as String? ?? '').trim();
      final precioPromocional = (promo['precio_promocional'] as num?)?.toDouble();
      final canchaId = (promo['cancha_id'] as String? ?? '').trim();
      
      if (fechaStr.isEmpty || horarioStr.isEmpty || precioPromocional == null || canchaId.isEmpty) {
        debugPrint('❌ Datos de promoción incompletos');
        return;
      }
      
      final fecha = DateTime.parse(fechaStr);
      final hora24 = _convertirHora12A24(horarioStr);
      
      // ✅ GUARDAR INFORMACIÓN DE LA PROMOCIÓN
      setState(() {
        _selectedDate = fecha;
        _selectedTime = TimeOfDay(hour: hora24, minute: 0);
        _promocionActiva = {
          'precio_promocional': precioPromocional,
          'promoId': promoId,
          'cancha_id': canchaId,
          'horario': horarioStr,
          'fecha': fechaStr,
        };
      });
      
      debugPrint('🎯 Promoción seleccionada:');
      debugPrint('   - Precio: COP ${precioPromocional.toStringAsFixed(0)}');
      debugPrint('   - Cancha ID: $canchaId');
      debugPrint('   - Horario: $horarioStr');
      
      _navegarAReserva(lugar);
    } catch (e) {
      debugPrint('❌ Error seleccionando promoción: $e');
    }
  }
  Widget _buildEnhancedFavoriteCard(Lugar lugar, {bool gridTile = false}) {
    final isFavorite = _favoriteLugares.contains(lugar.id);
    final imageHeight = gridTile ? 148.0 : 180.0;
    final cardMargin =
        gridTile ? EdgeInsets.zero : const EdgeInsets.only(bottom: 20);
    final iconPad = gridTile ? 8.0 : 10.0;
    final iconSize = gridTile ? 18.0 : 20.0;
    final stackTop = gridTile ? 8.0 : 12.0;
    final stackRight = gridTile ? 8.0 : 12.0;
    final stackBottom = gridTile ? 8.0 : 12.0;
    final stackLeft = gridTile ? 8.0 : 12.0;
    final chipMaxW = gridTile ? 96.0 : 140.0;
    final titleSize = gridTile ? 16.0 : 18.0;
    final addressSize = gridTile ? 13.0 : 14.0;
    final bodyPadding =
        gridTile ? const EdgeInsets.fromLTRB(12, 10, 12, 12) : const EdgeInsets.fromLTRB(16, 14, 16, 16);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 24 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: cardMargin,
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SedeScreen(
                          ciudad: widget.ciudad,
                          lugar: lugar,
                        ),
                      ),
                    );
                  },
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
                              child: (lugar.fotoUrl != null && lugar.fotoUrl!.isNotEmpty)
                                  ? Image.network(
                                      lugar.fotoUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                      loadingProgress.expectedTotalBytes!
                                                  : null,
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(_primaryGreen),
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildPlaceholderImage(),
                                    )
                                  : _buildPlaceholderImage(),
                            ),
                            Positioned(
                              top: stackTop,
                              right: stackRight,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleFavorite(lugar.id),
                                    child: Container(
                                      padding: EdgeInsets.all(iconPad),
                                      decoration: BoxDecoration(
                                        color: _cardOverlayBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: iconSize,
                                        color: isFavorite ? const Color(0xFFE53E3E) : Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: gridTile ? 6 : 8),
                                  GestureDetector(
                                    onTap: () => _compartirLugar(lugar),
                                    child: Container(
                                      padding: EdgeInsets.all(iconPad),
                                      decoration: BoxDecoration(
                                        color: _cardOverlayBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.share_rounded,
                                        size: iconSize,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: gridTile ? 6 : 8),
                                  FutureBuilder<_SedeUbicacionInfo>(
                                    future: _getSedeUbicacionInfo(lugar.id),
                                    builder: (context, snap) {
                                      final info = snap.data;
                                      final disponible = info?.tieneUbicacionDisponible ?? false;

                                      return GestureDetector(
                                        onTap: (info == null || !disponible)
                                            ? null
                                            : () => _abrirUbicacionLugar(lugar, info),
                                        child: Container(
                                          padding: EdgeInsets.all(iconPad),
                                          decoration: BoxDecoration(
                                            color: _cardOverlayBg,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.location_on_rounded,
                                            size: iconSize,
                                            color: disponible ? _accentTeal : Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: stackBottom,
                              left: stackLeft,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: gridTile ? 6 : 8,
                                  vertical: gridTile ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _cardOverlayBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      color: _accentTeal,
                                      size: gridTile ? 14 : 16,
                                    ),
                                    const SizedBox(width: 4),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(maxWidth: chipMaxW),
                                      child: Text(
                                        lugar.direccion,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: gridTile ? 11 : 12,
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
                          padding: bodyPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lugar.nombre,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: gridTile ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: gridTile ? 4 : 6),
                              Text(
                                lugar.direccion,
                                style: TextStyle(
                                  fontSize: addressSize,
                                  fontWeight: FontWeight.w400,
                                  color: _textSecondary,
                                  height: 1.35,
                                ),
                                maxLines: gridTile ? 2 : 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: gridTile ? 8 : 10),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: gridTile ? 8 : 10,
                                      vertical: gridTile ? 4 : 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tagBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'LUGAR',
                                      style: TextStyle(
                                        fontSize: gridTile ? 10 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: _textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: gridTile ? 6 : 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: gridTile ? 8 : 10,
                                      vertical: gridTile ? 4 : 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _tagBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'FÚTBOL',
                                      style: TextStyle(
                                        fontSize: gridTile ? 10 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: _textSecondary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: gridTile ? 12 : 14,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E7D60).withOpacity(0.8),
            const Color(0xFF43A077).withOpacity(0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.sports_soccer_rounded,
                size: 40,
                color: const Color(0xFF2E7D60),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Imagen no disponible',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterIndicator() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedDate != null && _selectedTime != null) {
                  _showAvailabilityResults();
                }
              },
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E7D60).withOpacity(0.08),
                    const Color(0xFF4CAF50).withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2E7D60).withOpacity(0.25),
                  width: 1.5,
                ),
              ),
      child: Row(
        children: [
          Icon(
              Icons.filter_alt,
            color: const Color(0xFF2E7D60),
              size: 20,
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Filtros aplicados',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF2E7D60).withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('EEE d MMM', 'es').format(_selectedDate!)} · ${_formatHora12h(_selectedTime!.hour)}',
                  style: const TextStyle(
                    color: Color(0xFF2E7D60),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = null;
                _selectedTime = null;
              });
              Provider.of<LugarProvider>(context, listen: false)
                  .fetchLugaresPorCiudad(widget.ciudad.id);
            },
            icon: const Icon(Icons.close, color: Color(0xFF2E7D60)),
            iconSize: 20,
          ),
        ],
      ),
      ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildSearchFilterModal(),
    );
  }

  Widget _buildSearchFilterModal() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: Color.fromARGB(255, 0, 0, 0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Filtrar por fecha y hora',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Verás disponibilidad y precios por lugar',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Fecha
                Text(
                  'Seleccionar Fecha',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await _selectDate();
                    if (mounted) setModalState(() {});
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _selectedDate != null ? const Color(0xFF2E7D60) : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedDate != null
                              ? DateFormat('EEEE d MMM yyyy', 'es').format(_selectedDate!)
                              : 'Toca para elegir fecha',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                            color: _selectedDate != null ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (_selectedDate != null)
                          Icon(Icons.check_circle, color: const Color(0xFF2E7D60), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Hora
                Text(
                  'Seleccionar Hora',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    await _selectTime();
                    if (mounted) setModalState(() {});
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: _selectedTime != null ? const Color(0xFF2E7D60) : Colors.grey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _selectedTime != null
                              ? _formatHora12h(_selectedTime!.hour)
                              : 'Toca para elegir hora',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedTime != null ? FontWeight.w600 : FontWeight.normal,
                            color: _selectedTime != null ? Colors.black87 : Colors.grey[600],
                          ),
                        ),
                        const Spacer(),
                        if (_selectedTime != null)
                          Icon(Icons.check_circle, color: const Color(0xFF2E7D60), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                          _selectedTime = null;
                        });
                        Navigator.pop(context);
                        Provider.of<LugarProvider>(context, listen: false)
                            .fetchLugaresPorCiudad(widget.ciudad.id);
                      },
                      child: const Text(
                        'Limpiar Filtros',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (_selectedDate != null && _selectedTime != null) {
                          if (mounted) {
                            _showAvailabilityResults();
                          }
                        } else {
                          Provider.of<LugarProvider>(context, listen: false)
                              .fetchLugaresPorCiudad(widget.ciudad.id);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Aplicar y ver resultados'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D60),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final hora24 = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.access_time, color: Color(0xFF2E7D60), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Seleccionar hora',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D60),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Elige la hora para ver disponibilidad y precios',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(24, (index) {
                    final h12 = _convertirHora24A12(index);
                    final label = '${h12['hora']}:00 ${h12['periodo']}';
                    return ActionChip(
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: _selectedTime?.hour == index
                          ? const Color(0xFF2E7D60).withOpacity(0.15)
                          : Colors.grey[100],
                      side: BorderSide(
                        color: _selectedTime?.hour == index
                            ? const Color(0xFF2E7D60)
                            : Colors.grey[300]!,
                        width: _selectedTime?.hour == index ? 2 : 1,
                      ),
                      onPressed: () => Navigator.pop(context, index),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (hora24 != null && mounted) {
      setState(() {
        _selectedTime = TimeOfDay(hour: hora24, minute: 0);
      });
    }
  }


  void _showChangeCityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_city, color: Color.fromARGB(255, 0, 0, 0)),
            SizedBox(width: 8),
            Text('Cambiar Ciudad'),
          ],
        ),
        content: const Text(
          '¿Deseas cambiar la ciudad actual? Se te llevará a la pantalla de selección de ciudades.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
                        onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                  builder: (context) => const CiudadScreen(),
                            ),
                          );
                        },
                              style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                                foregroundColor: Colors.white,
            ),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  // Disponibilidad: consultas agregadas (≈3–4 por lote de hasta 30 lugares; ver _kDisponibilidadWhereInMax).

  Future<Map<String, Map<String, dynamic>>> _cargarDisponibilidadTodosLugares(
    List<Lugar> lugares,
  ) async {
    final out = <String, Map<String, dynamic>>{};
    final vacio = {
      'total': 0,
      'disponibles': 0,
      'apartadas': 0,
      'procesando': 0,
      'sedeDatosPorId': <String, _SedeDatosUbicacion>{},
    };
    if (lugares.isEmpty) return out;
    if (_selectedDate == null || _selectedTime == null) {
      for (final l in lugares) {
        out[l.id] = Map<String, dynamic>.from(vacio);
      }
      return out;
    }

    final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final horaStr =
        '${_selectedTime!.hour.toString().padLeft(2, '0')}:00';
    final incluirPromos = fechaStr.compareTo(_todayStr) >= 0;

    final lugarIds =
        lugares.map((e) => e.id).where((id) => id.isNotEmpty).toList();
    final chunks = _chunkDisponibilidad(lugarIds, _kDisponibilidadWhereInMax);

    final canchasPorLugar = <String, List<Cancha>>{};
    final sedesPorLugar =
        <String, Map<String, _SedeDatosUbicacion>>{};
    final precioPromoGlobal = <String, double>{};
    final reservasPorCancha =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    var consultasFirestore = 0;
    final fs = FirebaseFirestore.instance;

    try {
      for (final chunk in chunks) {
        if (chunk.isEmpty) continue;

        final canchasQ =
            fs.collection('canchas').where('lugarId', whereIn: chunk);
        final sedesQ = fs.collection('sede').where('lugarId', whereIn: chunk);
        final reservasQ = fs
            .collection('reservas')
            .where('lugarId', whereIn: chunk)
            .where('fecha', isEqualTo: fechaStr);

        if (incluirPromos) {
          final promosQ = fs
              .collection('promociones')
              .where('lugarId', whereIn: chunk)
              .where('fecha', isEqualTo: fechaStr)
              .where('activo', isEqualTo: true);
          final r = await Future.wait([
            canchasQ.get(),
            sedesQ.get(),
            reservasQ.get(),
            promosQ.get(),
          ]);
          consultasFirestore += 4;
          _fusionarDatosDisponibilidad(
            canchasSnap: r[0],
            sedesSnap: r[1],
            reservasSnap: r[2],
            promosSnap: r[3],
            canchasPorLugar: canchasPorLugar,
            sedesPorLugar: sedesPorLugar,
            precioPromoGlobal: precioPromoGlobal,
            reservasPorCancha: reservasPorCancha,
          );
        } else {
          final r = await Future.wait([
            canchasQ.get(),
            sedesQ.get(),
            reservasQ.get(),
          ]);
          consultasFirestore += 3;
          _fusionarDatosDisponibilidad(
            canchasSnap: r[0],
            sedesSnap: r[1],
            reservasSnap: r[2],
            promosSnap: null,
            canchasPorLugar: canchasPorLugar,
            sedesPorLugar: sedesPorLugar,
            precioPromoGlobal: precioPromoGlobal,
            reservasPorCancha: reservasPorCancha,
          );
        }
      }
    } catch (e, st) {
      debugPrint('⚠️ Disponibilidad agregada (Firestore): $e\n$st');
      IndexErrorService.handleFirestoreError(e, 'disponibilidadAgregada');
      final err = {
        'total': 0,
        'disponibles': 0,
        'apartadas': 0,
        'procesando': 0,
        'sedeDatosPorId': <String, _SedeDatosUbicacion>{},
        'error': e.toString(),
      };
      for (final l in lugares) {
        out[l.id] = Map<String, dynamic>.from(err);
      }
      return out;
    }

    if (kDebugMode) {
      debugPrint(
        '📊 Disponibilidad agregada: $consultasFirestore consultas Firestore '
        '(${chunks.length} lote(s), hasta $_kDisponibilidadWhereInMax lugares/lote)',
      );
    }

    for (final lugar in lugares) {
      out[lugar.id] = _computarDisponibilidadUnLugar(
        canchas: canchasPorLugar[lugar.id] ?? const [],
        sedeDatosPorId: sedesPorLugar[lugar.id] ?? const {},
        precioPromoPorCanchaHorario: precioPromoGlobal,
        reservasPorCancha: reservasPorCancha,
        fechaStr: fechaStr,
        horaStr: horaStr,
      );
    }

    return out;
  }

  void _fusionarDatosDisponibilidad({
    required QuerySnapshot<Map<String, dynamic>> canchasSnap,
    required QuerySnapshot<Map<String, dynamic>> sedesSnap,
    required QuerySnapshot<Map<String, dynamic>> reservasSnap,
    QuerySnapshot<Map<String, dynamic>>? promosSnap,
    required Map<String, List<Cancha>> canchasPorLugar,
    required Map<String, Map<String, _SedeDatosUbicacion>> sedesPorLugar,
    required Map<String, double> precioPromoGlobal,
    required Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        reservasPorCancha,
  }) {
    for (final doc in canchasSnap.docs) {
      final c = Cancha.fromFirestore(doc);
      final lid = c.lugarId;
      if (lid == null || lid.isEmpty) continue;
      canchasPorLugar.putIfAbsent(lid, () => []).add(c);
    }

    for (final d in sedesSnap.docs) {
      final data = d.data();
      final lid = data['lugarId'] as String? ?? '';
      if (lid.isEmpty) continue;
      if (data['activa'] == false) continue;
      final n = (data['nombre'] as String?)?.trim();
      final nombre = (n == null || n.isEmpty) ? 'Sede' : n;
      final lat = (data['latitud'] as num?)?.toDouble();
      final lon = (data['longitud'] as num?)?.toDouble();
      final ubi = (data['ubicacion'] as String?)?.trim();
      sedesPorLugar.putIfAbsent(lid, () => {})[d.id] = _SedeDatosUbicacion(
        nombre: nombre,
        latitud: lat,
        longitud: lon,
        direccion: (ubi == null || ubi.isEmpty) ? null : ubi,
      );
    }

    if (promosSnap != null) {
      for (final doc in promosSnap.docs) {
        final d = doc.data();
        final canchaId = (d['cancha_id'] as String? ?? '').trim();
        final horario = (d['horario'] as String? ?? '').trim();
        final precioPromo = (d['precio_promocional'] as num?)?.toDouble();
        if (canchaId.isNotEmpty &&
            horario.isNotEmpty &&
            precioPromo != null &&
            precioPromo > 0) {
          final key =
              '${canchaId}_${Horario.normalizarHora(horario)}';
          precioPromoGlobal[key] = precioPromo;
        }
      }
    }

    for (final doc in reservasSnap.docs) {
      final data = doc.data();
      final cid = data['cancha_id'] as String? ?? '';
      if (cid.isEmpty) continue;
      reservasPorCancha.putIfAbsent(cid, () => []).add(doc);
    }
  }

  Map<String, dynamic> _computarDisponibilidadUnLugar({
    required List<Cancha> canchas,
    required Map<String, _SedeDatosUbicacion> sedeDatosPorId,
    required Map<String, double> precioPromoPorCanchaHorario,
    required Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        reservasPorCancha,
    required String fechaStr,
    required String horaStr,
  }) {
    var totalCanchas = 0;
    var canchasDisponibles = 0;
    var canchasApartadas = 0;
    var canchasProcesando = 0;
    final preciosDisponibles = <double>[];
    final detalleCanchas = <_CanchaSlotDisponibilidad>[];
    var tieneAlMenosUnaPromo = false;

    (String nombre, String idKey) metaSede(Cancha cancha) {
      final sid = cancha.sedeId.trim();
      if (sid.isNotEmpty && sedeDatosPorId.containsKey(sid)) {
        return (sedeDatosPorId[sid]!.nombre, sid);
      }
      if (sid.isNotEmpty) {
        return ('Sede', sid);
      }
      if (sedeDatosPorId.length == 1) {
        final e = sedeDatosPorId.entries.first;
        return (e.value.nombre, e.key);
      }
      return ('Sin sede asignada', '__sin_sede__');
    }

    for (final cancha in canchas) {
      final day =
          DateFormat('EEEE', 'es').format(_selectedDate!).toLowerCase();
      final preciosPorDia = cancha.preciosPorHorario[day] ?? {};
      final hora24 = _selectedTime!.hour;
      final hora12 = _convertirHora24A12(hora24);
      final horaStr12 = '${hora12['hora']}:00 ${hora12['periodo']}';
      final horaConfig = preciosPorDia[horaStr12];
      if (horaConfig == null || horaConfig['habilitada'] != true) {
        continue;
      }

      totalCanchas++;

      var tieneReservaConfirmada = false;
      var tieneReservaPendiente = false;
      final docsRes = reservasPorCancha[cancha.id] ?? const [];
      for (final reservaDoc in docsRes) {
        final reservaData = reservaDoc.data();
        final horarioReserva = reservaData['horario'] as String? ?? '';
        final confirmada = reservaData['confirmada'] as bool? ?? false;
        final horaReserva24h = _convertirHora12A24(horarioReserva);
        if (horaReserva24h == hora24) {
          if (confirmada) {
            tieneReservaConfirmada = true;
          } else {
            tieneReservaPendiente = true;
          }
        }
      }

      final sm = metaSede(cancha);
      if (tieneReservaConfirmada) {
        canchasApartadas++;
        detalleCanchas.add(_CanchaSlotDisponibilidad(
          canchaId: cancha.id,
          nombre: cancha.nombre,
          sedeId: sm.$2,
          sedeNombre: sm.$1,
          estado: 'apartada',
        ));
      } else if (tieneReservaPendiente) {
        canchasProcesando++;
        detalleCanchas.add(_CanchaSlotDisponibilidad(
          canchaId: cancha.id,
          nombre: cancha.nombre,
          sedeId: sm.$2,
          sedeNombre: sm.$1,
          estado: 'procesando',
        ));
      } else {
        canchasDisponibles++;
        final promoKey =
            '${cancha.id}_${Horario.normalizarHora(horaStr12)}';
        final precioPromo = precioPromoPorCanchaHorario[promoKey];
        if (precioPromo != null) tieneAlMenosUnaPromo = true;
        final precio = precioPromo ??
            ((horaConfig['precio'] is num)
                ? (horaConfig['precio'] as num).toDouble()
                : cancha.precio);
        preciosDisponibles.add(precio);
        detalleCanchas.add(_CanchaSlotDisponibilidad(
          canchaId: cancha.id,
          nombre: cancha.nombre,
          sedeId: sm.$2,
          sedeNombre: sm.$1,
          estado: 'disponible',
          precio: precio,
          tienePromo: precioPromo != null,
        ));
      }
    }

    double? precioDesde;
    if (preciosDisponibles.isNotEmpty) {
      preciosDisponibles.sort();
      precioDesde = preciosDisponibles.first;
    }

    final tienePromo = tieneAlMenosUnaPromo;

    detalleCanchas.sort((a, b) {
      final bySede =
          a.sedeNombre.toLowerCase().compareTo(b.sedeNombre.toLowerCase());
      if (bySede != 0) return bySede;
      int rank(String e) {
        if (e == 'disponible') return 0;
        if (e == 'procesando') return 1;
        return 2;
      }

      final c = rank(a.estado).compareTo(rank(b.estado));
      if (c != 0) return c;
      return a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
    });

    return {
      'total': totalCanchas,
      'disponibles': canchasDisponibles,
      'apartadas': canchasApartadas,
      'procesando': canchasProcesando,
      'precioDesde': precioDesde,
      'precios': preciosDisponibles,
      'tienePromo': tienePromo,
      'detalleCanchas': detalleCanchas,
      'sedeDatosPorId': sedeDatosPorId,
    };
  }

  String _soloDigitosTelefono(String raw) =>
      raw.replaceAll(RegExp(r'\D'), '');

  Future<void> _mostrarOpcionesTelefonoLugar(Lugar lugar) async {
    final raw = lugar.telefono.trim();
    if (raw.isEmpty) return;
    final digitos = _soloDigitosTelefono(raw);
    if (digitos.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo leer el número de teléfono.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lugar.telefono,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.chat_rounded, color: Colors.green.shade700),
              title: const Text('Enviar mensaje por WhatsApp'),
              subtitle: const Text('Se abrirá WhatsApp con este número'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('https://wa.me/+57$digitos');
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_page_outlined, color: Color(0xFF2E7D60)),
              title: const Text('Guardar contacto'),
              subtitle: const Text('Compartir tarjeta para añadir a contactos'),
              onTap: () async {
                Navigator.pop(ctx);
                final vcf = 'BEGIN:VCARD\n'
                    'VERSION:3.0\n'
                    'FN:${lugar.nombre}\n'
                    'ORG:${lugar.nombre}\n'
                    'TEL;TYPE=CELL:$digitos\n'
                    'END:VCARD';
                try {
                  await Share.share(
                    vcf,
                    subject: 'Contacto: ${lugar.nombre}',
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo compartir: $e')),
                  );
                }
              },
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirUbicacionSede(_SedeDatosUbicacion datos) async {
    Uri? uri;
    if (datos.tieneCoordenadas) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${datos.latitud},${datos.longitud}',
      );
    } else if (datos.tieneDireccion) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(datos.direccion!.trim())}',
      );
    }
    if (uri == null) {
      if (!mounted) return;
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
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el mapa.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir mapa: $e')),
      );
    }
  }

  String _normalizarHora(String hora) {
    try {
      // Limpiar espacios y caracteres extra
      String horaLimpia = hora.trim();
      
      if (horaLimpia.contains(':')) {
        final parts = horaLimpia.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        }
      }
      
      // Si es solo un número, asumir que son horas
      if (RegExp(r'^\d+$').hasMatch(horaLimpia)) {
        final hour = int.parse(horaLimpia);
        return '${hour.toString().padLeft(2, '0')}:00';
      }
      
      return horaLimpia;
    } catch (e) {
      return hora;
    }
  }

  Map<String, String> _convertirHora24A12(int hora24) {
    if (hora24 == 0) {
      return {'hora': '12', 'periodo': 'AM'};
    } else if (hora24 < 12) {
      return {'hora': hora24.toString(), 'periodo': 'AM'};
    } else if (hora24 == 12) {
      return {'hora': '12', 'periodo': 'PM'};
    } else {
      return {'hora': (hora24 - 12).toString(), 'periodo': 'PM'};
    }
  }

  String _formatHora12h(int hora24) {
    final h = _convertirHora24A12(hora24);
    return '${h['hora']}:00 ${h['periodo']}';
  }

  int _convertirDiaSemana(String dia) {
    switch (dia.toLowerCase()) {
      case 'lunes':
      case 'monday':
        return 1;
      case 'martes':
      case 'tuesday':
        return 2;
      case 'miércoles':
      case 'wednesday':
        return 3;
      case 'jueves':
      case 'thursday':
        return 4;
      case 'viernes':
      case 'friday':
        return 5;
      case 'sábado':
      case 'saturday':
        return 6;
      case 'domingo':
      case 'sunday':
        return 7;
      default:
        return 0;
    }
  }

  int _convertirHora12A24(String hora12) {
    try {
      // Limpiar la hora
      String horaLimpia = hora12.trim().toUpperCase();
      
      // Si ya está en formato 24h, devolver directamente
      if (!horaLimpia.contains('AM') && !horaLimpia.contains('PM')) {
        if (horaLimpia.contains(':')) {
          return int.parse(horaLimpia.split(':')[0]);
        }
        return int.parse(horaLimpia);
      }
      
      // Extraer hora, minuto y período
      final parts = horaLimpia.split(' ');
      final timePart = parts[0];
      final period = parts.length > 1 ? parts[1] : '';
      
      final timeParts = timePart.split(':');
      int hour = int.parse(timeParts[0]);
      
      // Convertir a formato 24h
      if (period == 'AM') {
        if (hour == 12) hour = 0;
      } else if (period == 'PM') {
        if (hour != 12) hour += 12;
      }
      
      return hour;
    } catch (e) {
      print('Error convirtiendo hora 12h a 24h: $hora12 - $e');
      return 0;
    }
  }

  Future<void> _navegarAReserva(Lugar lugar) async {
    try {
      if (_selectedDate == null || _selectedTime == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor selecciona fecha y hora primero'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final canchasSnapshot = await FirebaseFirestore.instance
          .collection('canchas')
          .where('lugarId', isEqualTo: lugar.id)
          .get();
      
      if (!mounted) return;

      if (canchasSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay canchas disponibles para este lugar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final canchas = canchasSnapshot.docs.map((doc) => Cancha.fromFirestore(doc)).toList();
      
      // ✅ Si la reserva viene de una promoción, la promoción ya tiene cancha asignada: ir directo a esa cancha sin preguntar
      if (_promocionActiva != null) {
        final canchaIdPromo = (_promocionActiva!['cancha_id'] as String? ?? '').trim();
        if (canchaIdPromo.isNotEmpty) {
          final canchaPromo = canchas.where((c) => c.id == canchaIdPromo).firstOrNull;
          if (canchaPromo != null) {
            if (!mounted) return;
            _irADetalles(canchaPromo, lugar);
            return;
          }
        }
      }
      
      // Verificar disponibilidad para cada cancha
      final canchasDisponibles = <Cancha>[];
      final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final hora24 = _selectedTime!.hour;
      final hora12 = _convertirHora24A12(hora24);
      final horaStr = '${hora12['hora']}:00 ${hora12['periodo']}';
      final day = DateFormat('EEEE', 'es').format(_selectedDate!).toLowerCase();
      
      for (var cancha in canchas) {
        final preciosPorDia = cancha.preciosPorHorario[day] ?? {};
        final horaConfig = preciosPorDia[horaStr];
        
        if (horaConfig != null && horaConfig['habilitada'] == true) {
          // Verificar si no hay reservas confirmadas
          final reservasSnapshot = await FirebaseFirestore.instance
              .collection('reservas')
              .where('fecha', isEqualTo: fechaStr)
              .where('cancha_id', isEqualTo: cancha.id)
              .get();
          
          bool tieneReservaConfirmada = false;
          for (var reservaDoc in reservasSnapshot.docs) {
            final reservaData = reservaDoc.data();
            final horarioReserva = reservaData['horario'] as String? ?? '';
            final confirmada = reservaData['confirmada'] as bool? ?? false;
            
            if (_normalizarHora(horarioReserva) == _normalizarHora('${hora24.toString().padLeft(2, '0')}:00') && confirmada) {
              tieneReservaConfirmada = true;
              break;
            }
          }
          
          if (!tieneReservaConfirmada) {
            canchasDisponibles.add(cancha);
          }
        }
      }
      
      if (!mounted) return;

      if (canchasDisponibles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay canchas disponibles para la fecha y hora seleccionada'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      if (canchasDisponibles.length > 1) {
        _mostrarSelectorCanchas(lugar, canchasDisponibles);
      } else {
        _irADetalles(canchasDisponibles.first, lugar);
      }
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarSelectorCanchas(Lugar lugar, List<Cancha> canchas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona una cancha',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D60),
              ),
            ),
            const SizedBox(height: 16),
            ...canchas.map((cancha) => ListTile(
              leading: const Icon(Icons.sports_soccer, color: Color(0xFF2E7D60)),
              title: Text(cancha.nombre),
              subtitle: Text(cancha.ubicacion),
              onTap: () {
                Navigator.pop(context);
                _irADetalles(cancha, lugar);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _irADetalles(Cancha cancha, Lugar lugar, {String? nombreSedeMostrar}) {
    final hora24 = _selectedTime!.hour;
    
    final horario = Horario(
      hora: TimeOfDay(hour: hora24, minute: 0),
      estado: EstadoHorario.disponible,
    );
    
    // ✅ VERIFICAR SI HAY PROMOCIÓN ACTIVA PARA ESTA CANCHA Y HORARIO
    Map<String, dynamic>? promocionParaEstaCancha;
    if (_promocionActiva != null) {
      final canchaIdPromo = _promocionActiva!['cancha_id'] as String?;
      final horarioPromo = _promocionActiva!['horario'] as String?;
      final horarioNormalizado = Horario.normalizarHora(horario.horaFormateada);
      final horarioPromoNormalizado = horarioPromo != null ? Horario.normalizarHora(horarioPromo) : null;
      
      if (canchaIdPromo == cancha.id && horarioPromoNormalizado == horarioNormalizado) {
        promocionParaEstaCancha = _promocionActiva;
        debugPrint('✅ Promoción aplicable encontrada para cancha ${cancha.nombre}');
      }
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetallesScreen(
          cancha: cancha,
          fecha: _selectedDate!,
          horario: horario,
          sede: nombreSedeMostrar ?? lugar.nombre,
          precioPromocional: promocionParaEstaCancha?['precio_promocional'] as double?,
          promocionId: promocionParaEstaCancha?['promoId'] as String?,
        ),
      ),
    ).then((reservaCreada) {
      if (!mounted) return;
      if (reservaCreada == true) {
        setState(() {
          _promocionActiva = null;
        });
      }
    });
  }

  void _showAvailabilityResults() {
    final lugares =
        Provider.of<LugarProvider>(context, listen: false).lugares;
    final future = _cargarDisponibilidadTodosLugares(lugares);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAvailabilityModal(
        lugares: lugares,
        futureDisponibilidad: future,
      ),
    );
  }

  Widget _buildAvailabilityModal({
    required List<Lugar> lugares,
    required Future<Map<String, Map<String, dynamic>>> futureDisponibilidad,
  }) {
    const headerInk = Color(0xFF111827);
    const headerMuted = Color(0xFF6B7280);
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFFF3F4F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disponibilidad',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: headerInk,
                          letterSpacing: -0.4,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 16,
                            color: headerMuted.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${DateFormat('EEE d MMM yyyy', 'es').format(_selectedDate!)} · ${_formatHora12h(_selectedTime!.hour)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: headerMuted,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F4F6),
                    foregroundColor: headerInk,
                    padding: const EdgeInsets.all(10),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, Map<String, dynamic>>>(
              future: futureDisponibilidad,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF2E7D60),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Consultando disponibilidad…',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  );
                }
                final porLugar = snapshot.data ?? {};
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: lugares.length,
                  itemBuilder: (context, index) {
                    final lugar = lugares[index];
                    return _buildAvailabilityCard(
                      lugar,
                      porLugar[lugar.id],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard(
    Lugar lugar,
    Map<String, dynamic>? availabilityPrecomputada,
  ) {
    const borderColor = Color(0xFFE8EAED);
    const ink = Color(0xFF111827);
    const muted = Color(0xFF6B7280);

    if (availabilityPrecomputada == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.grey.shade500, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sin datos de disponibilidad para ${lugar.nombre}.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      );
    }

    final availability = availabilityPrecomputada;
    if (availability['error'] != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lugar.nombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Error',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${availability['error']}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final canchasDisponibles = availability['disponibles'] ?? 0;
    final canchasProcesando = availability['procesando'] ?? 0;
    final totalCanchas = availability['total'] ?? 0;
    final detalleRaw = availability['detalleCanchas'];
    final List<_CanchaSlotDisponibilidad> detalleCanchas = detalleRaw is List
        ? List<_CanchaSlotDisponibilidad>.from(detalleRaw)
        : const [];
    final Map<String, _SedeDatosUbicacion> sedeDatosPorId = {};
    final rawSedes = availability['sedeDatosPorId'];
    if (rawSedes is Map) {
      for (final e in rawSedes.entries) {
        if (e.key is String && e.value is _SedeDatosUbicacion) {
          sedeDatosPorId[e.key as String] = e.value as _SedeDatosUbicacion;
        }
      }
    }

    Color statusColor;
    String statusText;

    if (totalCanchas == 0) {
      statusColor = Colors.grey;
      statusText = 'Sin canchas en este horario';
    } else if (canchasDisponibles > 0) {
      statusColor = Colors.green.shade700;
      statusText =
          '$canchasDisponibles disponible${canchasDisponibles > 1 ? 's' : ''}';
    } else if (canchasProcesando > 0) {
      statusColor = Colors.orange.shade800;
      statusText = '$canchasProcesando en proceso de pago';
    } else {
      statusColor = Colors.red.shade700;
      statusText = 'Todas apartadas';
    }

    return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lugar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: muted.withValues(alpha: 0.95),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lugar.nombre,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            letterSpacing: -0.3,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (lugar.direccion.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: muted.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lugar.direccion,
                          style: const TextStyle(
                            fontSize: 13,
                            color: muted,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (lugar.telefono.trim().isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _mostrarOpcionesTelefonoLugar(lugar),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: const Color(0xFF2E7D60).withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lugar.telefono,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF2563EB),
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0x662563EB),
                                  ),
                                ),
                                Text(
                                  'WhatsApp o guardar en contactos',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: muted.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: muted.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (totalCanchas > 0) ...[
                const SizedBox(height: 18),
                Divider(height: 1, thickness: 1, color: borderColor.withValues(alpha: 0.85)),
                const SizedBox(height: 14),
                _buildDisponibilidadPorSede(
                  lugar,
                  detalleCanchas,
                  ink,
                  muted,
                  sedeDatosPorId,
                ),
              ],
            ],
          ),
        );
  }

  Widget _buildDisponibilidadPorSede(
    Lugar lugar,
    List<_CanchaSlotDisponibilidad> detalleCanchas,
    Color ink,
    Color muted,
    Map<String, _SedeDatosUbicacion> sedeDatosPorId,
  ) {
    const accent = Color(0xFF2E7D60);
    final porSede = <String, List<_CanchaSlotDisponibilidad>>{};
    for (final c in detalleCanchas) {
      porSede.putIfAbsent(c.sedeId, () => []).add(c);
    }
    final orden = porSede.keys.toList()
      ..sort(
        (a, b) => porSede[a]!
            .first
            .sedeNombre
            .toLowerCase()
            .compareTo(porSede[b]!.first.sedeNombre.toLowerCase()),
      );
    final horaLabel = _formatHora12h(_selectedTime!.hour);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < orden.length; i++) ...[
          if (i > 0) const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sede',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.7,
                          color: muted.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        porSede[orden[i]]!.first.sedeNombre,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                          letterSpacing: -0.2,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 15,
                                  color: muted.withValues(alpha: 0.85),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Canchas a las $horaLabel',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: muted.withValues(alpha: 0.95),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildBotonUbicacionSede(
                            sedeDatosPorId[orden[i]],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._listaCanchasPorSede(lugar, porSede[orden[i]]!),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBotonUbicacionSede(_SedeDatosUbicacion? datos) {
    final ok = datos != null && datos.puedeMostrarEnMapa;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: ok ? const Color(0xFF2E7D60) : const Color(0xFF9CA3AF),
        padding: const EdgeInsets.only(left: 6, right: 4, top: 4, bottom: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay ubicación registrada para esta sede (coordenadas o dirección).',
              ),
            ),
          );
          return;
        }
        _abrirUbicacionSede(datos);
      },
      icon: Icon(
        Icons.map_rounded,
        size: 17,
        color: ok ? const Color(0xFF2E7D60) : const Color(0xFF9CA3AF),
      ),
      label: Text(
        'Ubicación',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ok ? const Color(0xFF2E7D60) : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  List<Widget> _listaCanchasPorSede(
    Lugar lugar,
    List<_CanchaSlotDisponibilidad> slots,
  ) {
    final out = <Widget>[];
    for (var i = 0; i < slots.length; i++) {
      if (i > 0) {
        out.add(const SizedBox(height: 8));
      }
      out.add(_buildCanchaDetalleFila(lugar, slots[i]));
    }
    return out;
  }

  Widget _buildCanchaDetalleFila(Lugar lugar, _CanchaSlotDisponibilidad c) {
    const ink = Color(0xFF111827);
    const muted = Color(0xFF6B7280);
    Color estadoColor;
    String estadoLabel;
    switch (c.estado) {
      case 'disponible':
        estadoColor = const Color(0xFF15803D);
        estadoLabel = 'Disponible';
        break;
      case 'procesando':
        estadoColor = const Color(0xFFC2410C);
        estadoLabel = 'Pago pendiente';
        break;
      default:
        estadoColor = const Color(0xFFB91C1C);
        estadoLabel = 'Apartada';
    }

    final disponible = c.estado == 'disponible';

    Future<void> onTapDisponible() async {
      if (!disponible) return;
      final doc = await FirebaseFirestore.instance
          .collection('canchas')
          .doc(c.canchaId)
          .get();
      if (!doc.exists || !mounted) return;
      final cancha = Cancha.fromFirestore(doc);
      if (!mounted) return;
      Navigator.of(context).pop();
      _irADetalles(cancha, lugar, nombreSedeMostrar: c.sedeNombre);
    }

    final fila = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.nombre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: ink,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              if (c.estado == 'disponible' && c.precio != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '\$${c.precio!.toStringAsFixed(0)} / h',
                      style: const TextStyle(
                        fontSize: 13,
                        color: muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (c.tienePromo) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Promo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: estadoColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            estadoLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: estadoColor,
              height: 1.1,
            ),
          ),
        ),
        if (disponible) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: muted.withValues(alpha: 0.4),
          ),
        ],
      ],
    );

    final bgDisponible = const Color(0xFFF8FAFC);
    final bgOtro = const Color(0xFFF3F4F6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disponible ? () => onTapDisponible() : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: disponible
            ? const Color(0xFF2E7D60).withValues(alpha: 0.08)
            : null,
        highlightColor: disponible
            ? const Color(0xFF2E7D60).withValues(alpha: 0.05)
            : null,
        child: Ink(
          decoration: BoxDecoration(
            color: disponible ? bgDisponible : bgOtro,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: disponible
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Opacity(
            opacity: disponible ? 1 : 0.9,
            child: fila,
          ),
        ),
      ),
    );
  }
}

// ✅ Tarjeta de promoción minimalista: fondo oscuro, borde dorado, compacta
class _PromoVisible {
  final String fecha;
  final Map<String, dynamic> data;
  final String promoId;
  _PromoVisible({required this.fecha, required this.data, required this.promoId});
}

class _PremiumPromoCard extends StatefulWidget {
  final Lugar lugar;
  final String fechaBonita;
  final String horario;
  final String canchaNombre;
  final String nota;
  final double? precioPromo;
  final double? precioOriginal;
  final double? descuentoPct;
  final VoidCallback onReservar;

  const _PremiumPromoCard({
    required this.lugar,
    required this.fechaBonita,
    required this.horario,
    required this.canchaNombre,
    required this.nota,
    required this.precioPromo,
    required this.precioOriginal,
    required this.descuentoPct,
    required this.onReservar,
  });

  @override
  State<_PremiumPromoCard> createState() => _PremiumPromoCardState();
}

class _PremiumPromoCardState extends State<_PremiumPromoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineController;

  static const _gold = Color(0xFFD4A843);
  static const _goldLight = Color(0xFFE8C85A);
  static const _goldDark = Color(0xFFAA8520);
  static const _darkBg = Color(0xFF141414);

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDescuento = widget.descuentoPct != null && widget.descuentoPct! > 0;

    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_shineController.value * 3), -0.5),
              end: Alignment(1.0 + (_shineController.value * 3), 0.5),
              colors: const [_goldDark, _goldLight, _gold, _goldLight, _goldDark],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: _gold.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _darkBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Shine sweep overlay
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        final pos = _shineController.value;
                        return LinearGradient(
                          begin: Alignment(-2.0 + (pos * 4), -0.3),
                          end: Alignment(-1.0 + (pos * 4), 0.3),
                          colors: [
                            Colors.transparent,
                            _gold.withOpacity(0.06),
                            Colors.transparent,
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.srcATop,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Content
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onReservar,
                      splashColor: _gold.withOpacity(0.15),
                      highlightColor: _gold.withOpacity(0.08),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Badge descuento / icono oferta
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [_gold.withOpacity(0.25), _goldDark.withOpacity(0.15)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _gold.withOpacity(0.6), width: 1.2),
                              ),
                              child: hasDescuento
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '-${widget.descuentoPct!.toInt()}%',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: _goldLight,
                                            height: 1,
                                          ),
                                        ),
                                        const Text(
                                          'OFF',
                                          style: TextStyle(
                                            fontSize: 7,
                                            fontWeight: FontWeight.w700,
                                            color: _gold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.local_fire_department_rounded, color: _goldLight, size: 22),
                            ),
                            const SizedBox(width: 12),
                            // Info: label + fecha + hora/cancha
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Label "OFERTA"
                                  Row(
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) {
                                          final pos = _shineController.value;
                                          return LinearGradient(
                                            begin: Alignment(-1.0 + (pos * 3), 0),
                                            end: Alignment(1.0 + (pos * 3), 0),
                                            colors: const [_goldDark, _goldLight, _gold],
                                          ).createShader(bounds);
                                        },
                                        child: const Text(
                                          'OFERTA',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: 1.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 20,
                                        height: 1,
                                        color: _gold.withOpacity(0.4),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.fechaBonita.isNotEmpty)
                                    Text(
                                      widget.fechaBonita,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(0.95),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${widget.horario} · ${widget.canchaNombre}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.nota.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.nota,
                                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Precio + botón
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (widget.precioOriginal != null &&
                                    widget.precioOriginal! > 0 &&
                                    widget.precioPromo != null &&
                                    widget.precioPromo! < widget.precioOriginal!)
                                  Text(
                                    '\$${widget.precioOriginal!.toInt()}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withOpacity(0.4),
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: Colors.white.withOpacity(0.4),
                                    ),
                                  ),
                                if (widget.precioPromo != null)
                                  ShaderMask(
                                    shaderCallback: (bounds) {
                                      final pos = _shineController.value;
                                      return LinearGradient(
                                        begin: Alignment(-1.0 + (pos * 3), 0),
                                        end: Alignment(1.0 + (pos * 3), 0),
                                        colors: const [_goldDark, _goldLight, Colors.white, _goldLight, _goldDark],
                                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      '\$${widget.precioPromo!.toInt()}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_goldDark, _gold, _goldLight],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _gold.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onReservar,
                                      borderRadius: BorderRadius.circular(8),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Text(
                                          'Reservar',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: _darkBg,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

