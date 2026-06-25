import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';

/// Publicar historias / promos de la sucursal (admin).
class PromocionesAdminScreen extends StatefulWidget {
  const PromocionesAdminScreen({super.key, required this.sucursalId});

  final String? sucursalId;

  @override
  State<PromocionesAdminScreen> createState() => _PromocionesAdminScreenState();
}

class _PromocionesAdminScreenState extends State<PromocionesAdminScreen> {
  final _repo = PromocionesRepository();
  List<Map<String, dynamic>> _promos = [];
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
        _error = 'Sin sucursal asignada';
      });
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.listarAdmin(sid);
      if (!mounted) return;
      setState(() {
        _promos = lista;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar promociones');
      });
    }
  }

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? ColoresFoody.error : ColoresFoody.exito,
      ),
    );
  }

  Future<void> _dialogoCrear() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final tituloCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva promoción'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  labelText: 'URL imagen',
                  hintText: 'https://...',
                ),
              ),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publicar')),
        ],
      ),
    );
    if (ok != true || urlCtrl.text.trim().isEmpty) return;

    try {
      await _repo.crear(
        sucursalId: sid,
        titulo: tituloCtrl.text.trim(),
        imagenUrl: urlCtrl.text.trim(),
        descripcion: descCtrl.text.trim(),
      );
      _avisar('Promoción publicada');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e), error: true);
    }
  }

  Future<void> _toggleActiva(Map<String, dynamic> promo) async {
    final id = promo['id'] as String;
    final activa = promo['activa'] as bool? ?? true;
    try {
      await _repo.actualizar(id: id, activa: !activa);
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: _promos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Sin promociones. Publica la primera.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _promos.length,
                itemBuilder: (context, i) {
                  final p = _promos[i];
                  final activa = p['activa'] as bool? ?? true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (p['imagen_url'] as String?)?.isNotEmpty == true
                            ? NetworkImage(p['imagen_url'] as String)
                            : null,
                        child: (p['imagen_url'] as String?)?.isEmpty != false
                            ? const Icon(Icons.local_offer)
                            : null,
                      ),
                      title: Text(p['titulo'] as String? ?? 'Promo'),
                      subtitle: Text(
                        activa ? 'Activa · ${p['vistas'] ?? 0} vistas' : 'Inactiva',
                      ),
                      trailing: Switch(
                        value: activa,
                        onChanged: (_) => _toggleActiva(p),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _dialogoCrear,
        icon: const Icon(Icons.add),
        label: const Text('Nueva promo'),
      ),
    );
  }
}
