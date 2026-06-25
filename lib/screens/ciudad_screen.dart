import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/ciudad_provider.dart';
import '../models/ciudad.dart';
import '../services/ciudad_preference_service.dart';
import '../services/push_notification_service.dart';
import '../services/shared_lugar_link_service.dart';
import 'lugar_screen.dart';
import '../services/app_backend.dart';

class CiudadScreen extends StatefulWidget {
  const CiudadScreen({super.key});

  @override
  State<CiudadScreen> createState() => _CiudadScreenState();
}

class _CiudadScreenState extends State<CiudadScreen> with TickerProviderStateMixin {
  static const _bg = Color(0xFFF7F7F7);
  static const _surface = Colors.white;
  static const _ink = Color(0xFF111111);
  static const _muted = Color(0xFF666666);
  static const _border = Color(0xFFE8E8E8);

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isSelectingCiudad = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    
    // Cargar ciudades después del build para evitar "setState during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CiudadProvider>(context, listen: false).fetchCiudades();
      if (PushNotificationService.consumeRepickCiudadHintAfterPushFailure() &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para recibir promociones de tu ciudad, elige de nuevo la ciudad. '
              'Así volvemos a registrar las notificaciones en este dispositivo.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Obtener la ciudad guardada en preferencias o la primera disponible
        try {
          final ciudadGuardada = await CiudadPreferenceService.getSelectedCiudad();
          if (ciudadGuardada != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LugarScreen(ciudad: ciudadGuardada, restartAmbientMusic: true),
              ),
            );
          } else {
            // Si no hay ciudad guardada, usar la primera disponible
            final ciudadProvider = Provider.of<CiudadProvider>(context, listen: false);
            if (ciudadProvider.ciudades.isNotEmpty) {
              final primeraCiudad = ciudadProvider.ciudades.first;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => LugarScreen(
                    ciudad: primeraCiudad,
                    restartAmbientMusic: true,
                  ),
                ),
              );
            }
          }
        } catch (e) {
          // En caso de error, usar la primera ciudad disponible
          final ciudadProvider = Provider.of<CiudadProvider>(context, listen: false);
          if (ciudadProvider.ciudades.isNotEmpty) {
            final primeraCiudad = ciudadProvider.ciudades.first;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LugarScreen(
                  ciudad: primeraCiudad,
                  restartAmbientMusic: true,
                ),
              ),
            );
          }
        }
        return false;
      },
      child: Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Seleccionar Ciudad',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _ink,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Stack(
        children: [
          FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<CiudadProvider>(
            builder: (context, ciudadProvider, child) {
              if (ciudadProvider.isLoading) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(_ink),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Cargando ciudades...',
                        style: TextStyle(
                          fontSize: 16,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              if (ciudadProvider.errorMessage != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.black45,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ciudadProvider.errorMessage!,
                        style: const TextStyle(fontSize: 16, color: _ink),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ciudadProvider.fetchCiudades(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }

              if (ciudadProvider.ciudades.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_city,
                        size: 64,
                        color: Colors.black38,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No hay ciudades disponibles',
                        style: TextStyle(
                          fontSize: 18,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ciudadProvider.fetchCiudades(),
                color: _ink,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ciudadProvider.ciudades.length,
                  itemBuilder: (context, index) {
                    final ciudad = ciudadProvider.ciudades[index];
                    return _buildCiudadCard(ciudad, index);
                  },
                ),
              );
            },
          ),
        ),
        ),
          if (_isSelectingCiudad)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Card(
                    margin: EdgeInsets.symmetric(horizontal: 48),
                    color: _surface,
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_ink),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Cargando ciudad...',
                            style: TextStyle(fontSize: 16, color: _ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildCiudadCard(Ciudad ciudad, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: _surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _border),
            ),
            child: InkWell(
              onTap: _isSelectingCiudad
                  ? null
                  : () async {
                      setState(() => _isSelectingCiudad = true);
                      var c = ciudad;
                      try {
                        // Guardar ciudad primero (rápido, local); navegamos de inmediato.
                        await CiudadPreferenceService.saveSelectedCiudad(c);
                      } catch (e) {
                        if (mounted) setState(() => _isSelectingCiudad = false);
                        return;
                      }
                      if (!mounted) return;
                      setState(() => _isSelectingCiudad = false);
                      final pending = await SharedLugarLinkService.peekPending();
                      if (pending?.ciudadId != null &&
                          pending!.ciudadId!.isNotEmpty &&
                          pending.ciudadId != c.id) {
                        final ciudadDelEnlace =
                            await _getCiudadById(pending.ciudadId!);
                        if (ciudadDelEnlace != null) {
                          c = ciudadDelEnlace;
                          await CiudadPreferenceService.saveSelectedCiudad(c);
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              LugarScreen(ciudad: c, restartAmbientMusic: true),
                        ),
                      );
                      // FCM y registro de token en segundo plano (sin bloquear la UI).
                      PushNotificationService()
                          .updateCiudadForNotifications(c.id)
                          .timeout(
                            const Duration(seconds: 10),
                            onTimeout: () {
                              if (kDebugMode) {
                                debugPrint(
                                    'PushNotificationService: updateCiudad timeout');
                              }
                            },
                          )
                          .catchError((e) {
                            if (kDebugMode) {
                              debugPrint(
                                  'PushNotificationService: error en segundo plano $e');
                            }
                          });
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _surface,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF111111),
                      ),
                      child: Center(
                        child: Text(
                          ciudad.codigo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ciudad.nombre,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_city, size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 6),
                              Text(
                                'Código: ${ciudad.codigo}',
                                style: const TextStyle(fontSize: 13, color: _muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: _ink,
                        size: 16,
                      ),
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

  Future<Ciudad?> _getCiudadById(String ciudadId) async {
    try {
      if (!AppBackend.supabaseReady) return null;
      final row = await Supabase.instance.client
          .from('ciudades')
          .select()
          .eq('id', ciudadId)
          .maybeSingle();
      if (row == null) return null;
      return Ciudad.fromSupabase(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }
}
