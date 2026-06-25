import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/restaurantes/data/restaurantes_repository.dart';
import 'package:reserva_canchas/features/restaurantes/domain/sucursal_model.dart';

class SucursalesScreenFoody extends StatefulWidget {
  const SucursalesScreenFoody({
    super.key,
    required this.restauranteId,
    required this.restauranteNombre,
  });

  final String restauranteId;
  final String restauranteNombre;

  @override
  State<SucursalesScreenFoody> createState() => _SucursalesScreenFoodyState();
}

class _SucursalesScreenFoodyState extends State<SucursalesScreenFoody> {
  final _repositorio = RestaurantesRepository();
  late Future<List<SucursalModel>> _futureSucursales;

  @override
  void initState() {
    super.initState();
    _futureSucursales = _repositorio.listarSucursales(widget.restauranteId);
  }

  void _reintentar() {
    setState(() {
      _futureSucursales = _repositorio.listarSucursales(widget.restauranteId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.restauranteNombre)),
      body: FutureBuilder<List<SucursalModel>>(
        future: _futureSucursales,
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
                    const Text('No pudimos cargar las sucursales'),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}'),
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

          final sucursales = snapshot.data ?? [];
          if (sucursales.isEmpty) {
            return const Center(child: Text('Sin sucursales activas'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sucursales.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sucursal = sucursales[index];
              return Card(
                color: ColoresFoody.tarjeta,
                child: ListTile(
                  title: Text(sucursal.nombre),
                  subtitle: Text(sucursal.direccion ?? ''),
                  trailing: const Icon(Icons.restaurant_menu),
                  onTap: () {
                    context.push(
                      '/menu/${sucursal.id}'
                      '?nombre=${Uri.encodeComponent(sucursal.nombre)}',
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
