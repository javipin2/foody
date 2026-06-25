import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/ciudades/data/ciudades_repository.dart';
import 'package:reserva_canchas/features/ciudades/domain/ciudad_model.dart';
import 'package:reserva_canchas/models/ciudad.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';

/// Pantalla Foody P01 — ciudades (solo muestra datos del backend).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foody'),
        actions: [
          IconButton(
            tooltip: 'Mis pedidos',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => context.push('/cliente/mis-pedidos'),
          ),
          IconButton(
            tooltip: 'Acceso staff',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.push('/admin/login'),
          ),
        ],
      ),
      body: FutureBuilder<List<CiudadModel>>(
        future: _futureCiudades,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No pudimos cargar las ciudades',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mensajeErrorHttp(snapshot.error!, contexto: 'ciudades'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '¿Encendiste Docker (Supabase) y dejaste abierta la ventana '
                      '«Foody — API NestJS»? Usa scripts\\iniciar-foody-dev.bat',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reintentar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final ciudades = snapshot.data ?? [];
          if (ciudades.isEmpty) {
            return const Center(child: Text('Próximamente en tu ciudad'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ciudades.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ciudad = ciudades[index];
              return Card(
                color: ColoresFoody.tarjeta,
                child: ListTile(
                  title: Text(ciudad.nombre),
                  subtitle: Text(ciudad.slug),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
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
                    if (!context.mounted) return;
                    context.push(
                      '/ciudades/${ciudad.slug}/restaurantes'
                      '?nombre=${Uri.encodeComponent(ciudad.nombre)}',
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
