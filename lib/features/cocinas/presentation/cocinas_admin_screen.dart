import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';

/// Gestión de cocinas e impresoras de la sucursal (admin/gerente).
class CocinasAdminScreen extends StatefulWidget {
  const CocinasAdminScreen({super.key, required this.sucursalId});

  final String? sucursalId;

  @override
  State<CocinasAdminScreen> createState() => _CocinasAdminScreenState();
}

class _CocinasAdminScreenState extends State<CocinasAdminScreen> {
  final _repo = CocinasRepository();
  List<Map<String, dynamic>> _cocinas = [];
  List<Map<String, dynamic>> _impresoras = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sucursalId = widget.sucursalId;
    if (sucursalId == null) {
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
      final cocinas = await _repo.listarCocinas(sucursalId);
      final impresoras = await _repo.listarImpresoras(sucursalId);
      if (!mounted) return;
      setState(() {
        _cocinas = cocinas;
        _impresoras = impresoras;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = mensajeErrorHttp(e, contexto: 'cargar cocinas');
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

  // ----------------------------- Cocinas -----------------------------

  Future<void> _dialogoCocina({Map<String, dynamic>? cocina}) async {
    final ctrl = TextEditingController(text: cocina?['nombre'] as String? ?? '');
    final esEdicion = cocina != null;
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar cocina' : 'Nueva cocina'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Cocina asados, Barra de bebidas…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      if (esEdicion) {
        await _repo.actualizarCocina(
          cocinaId: cocina['id'] as String,
          nombre: nombre,
        );
      } else {
        await _repo.crearCocina(
          sucursalId: widget.sucursalId!,
          nombre: nombre,
        );
      }
      _avisar('Cocina guardada');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar cocina'), error: true);
    }
  }

  Future<void> _toggleCocina(Map<String, dynamic> cocina) async {
    final activa = cocina['activa'] == true;
    try {
      await _repo.actualizarCocina(
        cocinaId: cocina['id'] as String,
        activa: !activa,
      );
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'cambiar cocina'), error: true);
    }
  }

  // ---------------------------- Impresoras ----------------------------

  Future<void> _dialogoImpresora({Map<String, dynamic>? impresora}) async {
    if (_cocinas.where((c) => c['activa'] == true).isEmpty) {
      _avisar('Crea una cocina antes de añadir impresoras', error: true);
      return;
    }
    final nombreCtrl =
        TextEditingController(text: impresora?['nombre'] as String? ?? '');
    final ipCtrl =
        TextEditingController(text: impresora?['ip_local'] as String? ?? '');
    String cocinaId = impresora?['cocina_id'] as String? ??
        _cocinas.firstWhere((c) => c['activa'] == true)['id'] as String;
    String tipo = impresora?['tipo'] as String? ?? 'termica_red';
    final esEdicion = impresora != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(esEdicion ? 'Editar impresora' : 'Nueva impresora'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: cocinaId,
                  decoration: const InputDecoration(labelText: 'Cocina'),
                  items: [
                    for (final c in _cocinas.where((c) => c['activa'] == true))
                      DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['nombre'] as String? ?? '—'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => cocinaId = v ?? cocinaId),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(
                      value: 'termica_red',
                      child: Text('Térmica de red'),
                    ),
                    DropdownMenuItem(
                      value: 'termica_usb',
                      child: Text('Térmica USB'),
                    ),
                    DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                  ],
                  onChanged: (v) => setLocal(() => tipo = v ?? tipo),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                    labelText: 'IP local (opcional)',
                    hintText: '192.168.1.50',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || nombreCtrl.text.trim().isEmpty) return;
    try {
      if (esEdicion) {
        await _repo.actualizarImpresora(
          impresoraId: impresora['id'] as String,
          nombre: nombreCtrl.text.trim(),
          cocinaId: cocinaId,
          ipLocal: ipCtrl.text.trim(),
          tipo: tipo,
        );
      } else {
        await _repo.crearImpresora(
          sucursalId: widget.sucursalId!,
          cocinaId: cocinaId,
          nombre: nombreCtrl.text.trim(),
          ipLocal: ipCtrl.text.trim(),
          tipo: tipo,
        );
      }
      _avisar('Impresora guardada');
      await _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'guardar impresora'), error: true);
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
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _encabezadoSeccion(
            'Cocinas',
            Icons.soup_kitchen_rounded,
            'Nueva cocina',
            () => _dialogoCocina(),
          ),
          const SizedBox(height: 8),
          if (_cocinas.isEmpty)
            const _Vacio('Aún no hay cocinas. Crea la primera para enrutar los platos.'),
          for (final c in _cocinas) _cardCocina(c),
          const SizedBox(height: 24),
          _encabezadoSeccion(
            'Impresoras',
            Icons.print_rounded,
            'Nueva impresora',
            () => _dialogoImpresora(),
          ),
          const SizedBox(height: 8),
          if (_impresoras.isEmpty)
            const _Vacio('Sin impresoras. Asigna una a cada cocina para imprimir tickets.'),
          for (final i in _impresoras) _cardImpresora(i),
        ],
      ),
    );
  }

  Widget _encabezadoSeccion(
    String titulo,
    IconData icono,
    String accion,
    VoidCallback onAccion,
  ) {
    return Row(
      children: [
        Icon(icono, color: ColoresFoody.primario),
        const SizedBox(width: 8),
        Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        FilledButton.icon(
          onPressed: onAccion,
          icon: const Icon(Icons.add, size: 18),
          label: Text(accion),
        ),
      ],
    );
  }

  Widget _cardCocina(Map<String, dynamic> c) {
    final activa = c['activa'] == true;
    final productos = c['productos']?.toString() ?? '0';
    final impresoras = c['impresoras']?.toString() ?? '0';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activa
              ? ColoresFoody.secundario.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            Icons.soup_kitchen_rounded,
            color: activa ? ColoresFoody.secundario : Colors.grey,
          ),
        ),
        title: Text(c['nombre'] as String? ?? '—'),
        subtitle: Text('$productos productos · $impresoras impresoras'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _dialogoCocina(cocina: c),
            ),
            Switch(value: activa, onChanged: (_) => _toggleCocina(c)),
          ],
        ),
      ),
    );
  }

  Widget _cardImpresora(Map<String, dynamic> i) {
    final activa = i['activa'] == true;
    final tipo = switch (i['tipo'] as String? ?? '') {
      'termica_red' => 'Térmica de red',
      'termica_usb' => 'Térmica USB',
      'pdf' => 'PDF',
      _ => i['tipo']?.toString() ?? '—',
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activa
              ? ColoresFoody.primario.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            Icons.print_rounded,
            color: activa ? ColoresFoody.primario : Colors.grey,
          ),
        ),
        title: Text(i['nombre'] as String? ?? '—'),
        subtitle: Text(
          '${i['cocina_nombre'] ?? 'Sin cocina'} · $tipo'
          '${(i['ip_local'] as String?)?.isNotEmpty == true ? ' · ${i['ip_local']}' : ''}',
        ),
        trailing: IconButton(
          tooltip: 'Editar',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _dialogoImpresora(impresora: i),
        ),
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(texto, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}
