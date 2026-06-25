import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_repository.dart';

/// Listado de domiciliarios de planta disponibles (Sprint 5 / Paso 1).
class DomiciliariosAdminScreen extends StatefulWidget {
  const DomiciliariosAdminScreen({super.key, this.sucursalId});

  final String? sucursalId;

  @override
  State<DomiciliariosAdminScreen> createState() =>
      _DomiciliariosAdminScreenState();
}

class _DomiciliariosAdminScreenState extends State<DomiciliariosAdminScreen> {
  final _repo = DomiciliariosRepository();
  List<Map<String, dynamic>> _domiciliarios = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
    if (sid == null) {
      setState(() {
        _cargando = false;
        _error = 'Sin sucursal en sesión';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.listarDisponibles(sid);
      if (!mounted) return;
      setState(() {
        _domiciliarios = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    if (_domiciliarios.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No hay domiciliarios registrados en esta sucursal')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _domiciliarios.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final d = _domiciliarios[index];
          final nombre = d['nombre']?.toString() ?? 'Sin nombre';
          final telefono = d['telefono']?.toString();
          final ocupado = d['ocupado'] == true;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: ocupado
                    ? Colors.orange.shade100
                    : ColoresFoody.secundario.withValues(alpha: 0.2),
                child: Icon(
                  Icons.two_wheeler,
                  color: ocupado ? Colors.orange.shade800 : ColoresFoody.secundario,
                ),
              ),
              title: Text(nombre),
              subtitle: telefono != null && telefono.isNotEmpty
                  ? Text(telefono)
                  : null,
              trailing: Chip(
                label: Text(
                  ocupado ? 'En ruta' : 'Disponible',
                  style: TextStyle(
                    fontSize: 12,
                    color: ocupado ? Colors.orange.shade900 : ColoresFoody.secundario,
                  ),
                ),
                backgroundColor: ocupado
                    ? Colors.orange.shade50
                    : ColoresFoody.secundario.withValues(alpha: 0.12),
              ),
            ),
          );
        },
      ),
    );
  }
}
