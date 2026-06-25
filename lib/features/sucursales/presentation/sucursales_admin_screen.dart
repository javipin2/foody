import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';

class SucursalesAdminScreen extends StatefulWidget {
  const SucursalesAdminScreen({super.key});

  @override
  State<SucursalesAdminScreen> createState() => _SucursalesAdminScreenState();
}

class _SucursalesAdminScreenState extends State<SucursalesAdminScreen> {
  final _repo = SucursalesRepository();
  List<Map<String, dynamic>> _sucursales = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.listarMiRestaurante();
      if (!mounted) return;
      setState(() {
        _sucursales = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar sucursales');
      });
    }
  }

  Future<void> _nuevaSucursal() async {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva sucursal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
              autofocus: true,
            ),
            TextField(
              controller: dirCtrl,
              decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nombreCtrl.text.trim().isNotEmpty),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      dirCtrl.dispose();
      return;
    }
    try {
      await _repo.crear(
        nombre: nombreCtrl.text.trim(),
        direccion: dirCtrl.text.trim(),
      );
      nombreCtrl.dispose();
      dirCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sucursal creada')),
        );
      }
      _cargar();
    } catch (e) {
      nombreCtrl.dispose();
      dirCtrl.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'crear sucursal')),
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: ColoresFoody.error)),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Mis sucursales', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Cada sucursal tiene su propio menú, mesas y pedidos.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ..._sucursales.map(
                (s) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(s['nombre'] as String? ?? ''),
                    subtitle: Text(
                      '${s['direccion'] ?? 'Sin dirección'} · ${s['ciudad_nombre'] ?? ''}',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: _nuevaSucursal,
            icon: const Icon(Icons.add),
            label: const Text('Sucursal'),
          ),
        ),
      ],
    );
  }
}
