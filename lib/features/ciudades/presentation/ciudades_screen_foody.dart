import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/notificaciones/servicio_fcm_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/ciudades/data/ciudades_repository.dart';
import 'package:reserva_canchas/features/ciudades/domain/ciudad_model.dart';
import 'package:reserva_canchas/models/ciudad.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';

/// Selector de ciudad (primera vez o «Cambiar ciudad»). Sin bottom nav.
class CiudadesScreenFoody extends StatefulWidget {
  const CiudadesScreenFoody({super.key});

  @override
  State<CiudadesScreenFoody> createState() => _CiudadesScreenFoodyState();
}

class _CiudadesScreenFoodyState extends State<CiudadesScreenFoody> {
  final _repositorio = CiudadesRepository();
  late Future<List<CiudadModel>> _futureCiudades;

  @override
  void initState() {
    super.initState();
    _futureCiudades = _repositorio.listarActivas();
  }

  void _reintentar() {
    setState(() {
      _futureCiudades = _repositorio.listarActivas();
    });
  }

  Future<void> _elegir(CiudadModel ciudad) async {
    await CiudadPreferenceService.saveSelectedCiudad(
      Ciudad(
        id: ciudad.id,
        nombre: ciudad.nombre,
        codigo: ciudad.slug,
        activa: ciudad.activa,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    // Guarda ciudad_id (+ FCM si hay) en el dispositivo del backend.
    await ServicioFcmFoody.instancia.sincronizarTrasCambioCiudad();
    if (!mounted) return;
    context.go(
      '/ciudades/${ciudad.slug}/restaurantes'
      '?nombre=${Uri.encodeComponent(ciudad.nombre)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: SafeArea(
        child: FutureBuilder<List<CiudadModel>>(
          future: _futureCiudades,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return FoodyEstadoUi.cargando(mensaje: 'Cargando ciudades…');
            }
            if (snapshot.hasError) {
              return FoodyEstadoUi.error(
                mensaje:
                    mensajeErrorHttp(snapshot.error!, contexto: 'ciudades'),
                onReintentar: _reintentar,
              );
            }

            final ciudades = snapshot.data ?? [];
            if (ciudades.isEmpty) {
              return FoodyEstadoUi.vacio(
                titulo: 'Próximamente en tu ciudad',
                subtitulo: 'Estamos llegando a más lugares',
                icono: Icons.location_city_outlined,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const Text(
                  'Foody',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AnaliticaTokens.inkSoft,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige tu ciudad',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: AnaliticaTokens.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'La guardamos en este dispositivo para no pedírtela cada vez.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AnaliticaTokens.inkMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < ciudades.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _CiudadTile(
                    ciudad: ciudades[i],
                    onTap: () => _elegir(ciudades[i]),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CiudadTile extends StatelessWidget {
  const _CiudadTile({required this.ciudad, required this.onTap});

  final CiudadModel ciudad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AnaliticaTokens.surface,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_city_outlined,
                    color: AnaliticaTokens.ink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ciudad.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AnaliticaTokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ver lugares',
                        style: TextStyle(
                          fontSize: 13,
                          color: AnaliticaTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AnaliticaTokens.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
