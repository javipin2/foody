import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';

/// Gestión de staff del restaurante (Sprint 9).
class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({
    super.key,
    this.sucursalId,
    this.puedeGestionarMultiSucursal = false,
  });

  final String? sucursalId;
  final bool puedeGestionarMultiSucursal;

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  final _repo = UsuariosRepository();
  final _sucursalesRepo = SucursalesRepository();
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _sucursales = [];
  String? _sucursalVistaId;
  bool _cargando = true;
  String? _error;

  static const _roles = [
    ('gerente', 'Gerente'),
    ('cajero', 'Cajero'),
    ('mesero', 'Mesero'),
    ('domiciliario_planta', 'Domiciliario planta'),
  ];

  @override
  void initState() {
    super.initState();
    _sucursalVistaId = widget.sucursalId;
    _inicializar();
  }

  @override
  void didUpdateWidget(covariant UsuariosAdminScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId &&
        !widget.puedeGestionarMultiSucursal) {
      _sucursalVistaId = widget.sucursalId;
      _cargar();
    }
  }

  Future<void> _inicializar() async {
    if (widget.puedeGestionarMultiSucursal) {
      try {
        final lista = await _sucursalesRepo.listarMiRestaurante();
        if (!mounted) return;
        setState(() {
          _sucursales = lista;
          if (_sucursalVistaId == null && lista.isNotEmpty) {
            _sucursalVistaId = lista.first['id'] as String?;
          }
        });
      } catch (_) {}
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    final sid = _sucursalVistaId;
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
      final lista = await _repo.listar(sid);
      if (mounted) {
        setState(() {
          _usuarios = lista;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'usuarios');
          _cargando = false;
        });
      }
    }
  }

  String _nombreSucursal(String? id) {
    if (id == null) return '—';
    for (final s in _sucursales) {
      if (s['id'] == id) return s['nombre'] as String? ?? 'Sucursal';
    }
    return 'Sucursal';
  }

  Future<void> _nuevoUsuario() async {
    final nombre = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    String rol = 'cajero';
    String? sucursalAsignada = _sucursalVistaId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo usuario'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.puedeGestionarMultiSucursal && _sucursales.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: sucursalAsignada,
                    decoration: const InputDecoration(
                      labelText: 'Sucursal',
                      helperText: 'Sede donde operará este usuario',
                    ),
                    items: _sucursales
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['nombre'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDlg(() => sucursalAsignada = v),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo'),
                ),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: rol,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map(
                        (r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setDlg(() => rol = v ?? rol),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crear')),
          ],
        ),
      ),
    );

    final n = nombre.text.trim();
    final e = email.text.trim();
    final p = pass.text;
    final sid = sucursalAsignada;
    nombre.dispose();
    email.dispose();
    pass.dispose();

    if (ok != true || n.isEmpty || e.isEmpty || p.length < 6 || sid == null) return;

    try {
      await _repo.crear(
        sucursalId: sid,
        nombre: n,
        email: e,
        contrasena: p,
        rol: rol,
      );
      if (_sucursalVistaId != sid) {
        setState(() => _sucursalVistaId = sid);
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario $e creado en ${_nombreSucursal(sid)}',
            ),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(err, contexto: 'creación'))),
        );
      }
    }
  }

  Future<void> _toggleActivo(Map<String, dynamic> u) async {
    final sid = _sucursalVistaId;
    if (sid == null) return;
    final activo = u['activo'] as bool? ?? true;
    try {
      await _repo.cambiarEstado(
        usuarioId: u['id'] as String,
        sucursalId: sid,
        activo: !activo,
      );
      await _cargar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'estado'))),
        );
      }
    }
  }

  String _etiquetaRol(String? rol) {
    return _roles.where((r) => r.$1 == rol).map((r) => r.$2).firstOrNull ??
        rol ??
        '—';
  }

  @override
  Widget build(BuildContext context) {
    final muestraSelectorSucursal =
        widget.puedeGestionarMultiSucursal && _sucursales.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text('Usuarios', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: _nuevoUsuario,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Nuevo'),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _inicializar,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (muestraSelectorSucursal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.store_outlined, size: 20, color: ColoresFoody.primario),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sucursalVistaId,
                    decoration: const InputDecoration(
                      labelText: 'Ver usuarios de la sede',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: _sucursales
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['nombre'] as String? ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _sucursalVistaId = v);
                      _cargar();
                    },
                  ),
                ),
              ],
            ),
          ),
        if (widget.puedeGestionarMultiSucursal && _sucursales.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: ColoresFoody.acento.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo hay una sede. Crea más en «Mis sucursales» para asignar usuarios a otras ubicaciones.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _cargar, child: const Text('Reintentar')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _inicializar,
                      child: _usuarios.isEmpty
                          ? ListView(
                              children: [
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    'Sin usuarios en ${_nombreSucursal(_sucursalVistaId)}',
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _usuarios.length,
                              itemBuilder: (_, i) {
                                final u = _usuarios[i];
                                final activo = u['activo'] as bool? ?? true;
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: activo
                                          ? ColoresFoody.primario.withValues(alpha: 0.15)
                                          : Colors.grey.shade300,
                                      child: Icon(
                                        Icons.person,
                                        color: activo
                                            ? ColoresFoody.primario
                                            : Colors.grey,
                                      ),
                                    ),
                                    title: Text(u['nombre'] as String? ?? ''),
                                    subtitle: Text(
                                      '${u['email']} · ${_etiquetaRol(u['rol'] as String?)}',
                                    ),
                                    trailing: Switch(
                                      value: activo,
                                      onChanged: u['rol'] == 'admin'
                                          ? null
                                          : (_) => _toggleActivo(u),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
