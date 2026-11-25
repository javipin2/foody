import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/auth/roles_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';

/// Gestión de staff del restaurante (Sprint 9).
class UsuariosAdminScreen extends StatefulWidget {
  const UsuariosAdminScreen({
    super.key,
    this.sucursalId,
    this.puedeGestionarMultiSucursal = false,
    this.onIrCocinas,
    this.repository,
    this.sucursalesRepository,
    this.cocinasRepository,
  });

  final String? sucursalId;
  final bool puedeGestionarMultiSucursal;

  /// NAV-ADM2-20: crear estación si no hay cocinas.
  final VoidCallback? onIrCocinas;
  final UsuariosRepository? repository;
  final SucursalesRepository? sucursalesRepository;
  final CocinasRepository? cocinasRepository;

  @override
  State<UsuariosAdminScreen> createState() => _UsuariosAdminScreenState();
}

class _UsuariosAdminScreenState extends State<UsuariosAdminScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final UsuariosRepository _repo;
  late final SucursalesRepository _sucursalesRepo;
  late final CocinasRepository _cocinasRepo;
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _sucursales = [];
  List<Map<String, dynamic>> _cocinas = [];
  String? _sucursalVistaId;
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _catalogoRoles = [];
  bool _catalogoCargado = false;

  static const _rolesBase = [
    ('gerente', 'Gerente'),
    ('cajero', 'Cajero'),
    ('mesero', 'Mesero'),
    ('cocina', 'Cocina (KDS)'),
    ('domiciliario_planta', 'Domiciliario planta'),
  ];

  List<(String, String)> get _rolesDisponibles {
    if (widget.puedeGestionarMultiSucursal) {
      return const [
        ('gerente_cadena', 'Gerente de cadena'),
        ..._rolesBase,
      ];
    }
    return _rolesBase;
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? UsuariosRepository();
    _sucursalesRepo = widget.sucursalesRepository ?? SucursalesRepository();
    _cocinasRepo = widget.cocinasRepository ?? CocinasRepository();
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
    unawaited(_cargarCatalogoRoles());
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
      final results = await Future.wait([
        _repo.listar(sid),
        _cocinasRepo.listarCocinas(sid),
      ]);
      if (mounted) {
        setState(() {
          _usuarios = results[0];
          _cocinas = results[1];
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

  Future<List<Map<String, dynamic>>> _cocinasDeSucursal(String? sid) async {
    if (sid == null) return [];
    if (sid == _sucursalVistaId && _cocinas.isNotEmpty) return _cocinas;
    try {
      return await _cocinasRepo.listarCocinas(sid);
    } catch (_) {
      return [];
    }
  }

  bool _esRolCocina(String rol) => rol == 'cocina' || rol.startsWith('cocina_');

  String _rolUi(String rol) => _esRolCocina(rol) ? 'cocina' : rol;

  Future<void> _cargarCatalogoRoles() async {
    if (_catalogoCargado) return;
    try {
      final cat = await _repo.catalogoRoles();
      if (mounted) {
        setState(() {
          _catalogoRoles = cat.roles;
          _catalogoCargado = true;
        });
      }
    } catch (_) {}
  }

  List<String> _permisosDeRol(String rol) {
    for (final r in _catalogoRoles) {
      if (r['rol'] == rol) {
        return (r['permisos'] as List<dynamic>? ?? [])
            .map((p) => p.toString())
            .toList();
      }
    }
    if (_esRolCocina(rol)) return ['ver_cocina'];
    return [];
  }

  String _etiquetaPermiso(String codigo) {
    const labels = <String, String>{
      'abrir_caja': 'Abrir caja',
      'aplicar_descuento': 'Aplicar descuento',
      'aprobar_pedido_mesa': 'Aprobar pedidos mesa (QR)',
      'cancelar_pedido': 'Cancelar pedidos',
      'cerrar_caja': 'Cerrar caja',
      'cobrar_pedido': 'Cobrar pedidos',
      'crear_pedido': 'Crear y operar pedidos',
      'editar_inventario': 'Editar inventario',
      'editar_productos': 'Crear/editar productos',
      'editar_stock': 'Editar stock',
      'gestionar_domiciliarios': 'Asignar domiciliarios',
      'gestionar_caja': 'Registrar operaciones de caja',
      'gestionar_facturacion': 'Gestionar facturación',
      'gestionar_mesas': 'Gestionar mesas',
      'gestionar_sucursales': 'Gestionar sucursales',
      'gestionar_usuarios': 'Gestionar usuarios',
      'hacer_retiro_parcial': 'Retiros de caja',
      'ver_alertas': 'Ver alertas',
      'ver_analitica': 'Ver analítica',
      'ver_caja': 'Ver caja',
      'ver_cocina': 'Ver cocina (KDS)',
      'ver_dashboard': 'Ver dashboard',
      'ver_facturacion': 'Ver facturación',
      'ver_finanzas': 'Ver finanzas',
      'gestionar_finanzas': 'Gestionar finanzas',
      'ver_inventario': 'Ver inventario',
      'ver_inventario_otras_sucursales': 'Ver inventario otras sedes',
      'ver_mesas': 'Ver mesas',
      'ver_pedidos': 'Ver pedidos',
      'ver_reportes': 'Ver reportes',
    };
    return labels[codigo] ?? codigo;
  }

  /// Checklist: solo permisos de la plantilla del rol (no caja en mesero, etc.).
  Widget _checklistPermisos({
    required String rol,
    required Set<String> seleccionados,
    required void Function(Set<String>) onChanged,
  }) {
    final lista = List<String>.from(_permisosDeRol(rol))..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Permisos de este usuario',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Solo opciones del rol ${_etiquetaRol(rol)}. '
          'Al crear vienen activadas las del rol; puedes desmarcar.',
          style: TextStyle(fontSize: 11.5, color: _scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (lista.isEmpty)
          Text(
            'Este rol no tiene permisos configurables.',
            style: TextStyle(fontSize: 12.5, color: _scheme.onSurfaceVariant),
          )
        else
          ...lista.map((p) {
            final on = seleccionados.contains(p);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: on,
              title: Text(
                _etiquetaPermiso(p),
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: p == 'crear_pedido'
                  ? const Text(
                      'Incluye agregar o editar pedidos y solicitar cambios '
                      'de estado válidos para el rol.',
                    )
                  : null,
              onChanged: (v) {
                final next = Set<String>.from(seleccionados);
                if (v == true) {
                  next.add(p);
                } else {
                  next.remove(p);
                }
                onChanged(next);
              },
            );
          }),
      ],
    );
  }

  String _nombreSucursal(String? id) {
    if (id == null) return '—';
    for (final s in _sucursales) {
      if (s['id'] == id) return s['nombre'] as String? ?? 'Sucursal';
    }
    return 'Sucursal';
  }

  Color _colorRol(String? rol) {
    switch (_rolUi(rol ?? '')) {
      case 'admin':
      case 'gerente':
      case 'gerente_cadena':
        return _scheme.onSurface;
      case 'cajero':
        return AnaliticaTokens.pedidos;
      case 'mesero':
        return AnaliticaTokens.clientes;
      case 'cocina':
        return const Color(0xFFD97706);
      case 'domiciliario_planta':
        return AnaliticaTokens.inventario;
      default:
        return _scheme.onSurfaceVariant;
    }
  }

  String _iniciales(String? nombre) {
    final partes = (nombre ?? '').trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return '${partes.first[0]}${partes.last[0]}'.toUpperCase();
  }

  int get _activos =>
      _usuarios.where((u) => u['activo'] as bool? ?? true).length;

  Future<void> _nuevoUsuario() async {
    await _cargarCatalogoRoles();
    if (!mounted) return;
    final nombre = TextEditingController();
    final email = TextEditingController();
    final pass = TextEditingController();
    String rol = 'cajero';
    String? sucursalAsignada = _sucursalVistaId;
    String? cocinaId;
    var cocinasDlg = List<Map<String, dynamic>>.from(_cocinas);
    var permisosSel = Set<String>.from(_permisosDeRol(rol));

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Nuevo usuario'),
          scrollable: true,
          content: SizedBox(
            width: MediaQuery.sizeOf(ctx).width.clamp(280.0, 560.0),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.puedeGestionarMultiSucursal &&
                      _sucursales.isNotEmpty) ...[
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
                      onChanged: (v) async {
                        sucursalAsignada = v;
                        cocinaId = null;
                        cocinasDlg = await _cocinasDeSucursal(v);
                        setDlg(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: pass,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: rol,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Rol'),
                    items: _rolesDisponibles
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r.$1, child: Text(r.$2)),
                        )
                        .toList(),
                    onChanged: (v) async {
                      rol = v ?? rol;
                      permisosSel = Set<String>.from(_permisosDeRol(rol));
                      if (_esRolCocina(rol) && cocinasDlg.isEmpty) {
                        cocinasDlg = await _cocinasDeSucursal(sucursalAsignada);
                        if (cocinasDlg.isEmpty && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'No hay cocinas. Créalas antes de asignar el rol.',
                              ),
                              action: widget.onIrCocinas == null
                                  ? null
                                  : SnackBarAction(
                                      label: 'Crear cocina',
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        widget.onIrCocinas!();
                                      },
                                    ),
                            ),
                          );
                        }
                      }
                      if (!_esRolCocina(rol)) cocinaId = null;
                      setDlg(() {});
                    },
                  ),
                  if (_esRolCocina(rol)) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: cocinaId,
                      decoration: const InputDecoration(
                        labelText: 'Estación de cocina',
                        helperText:
                            'Solo verá tickets de esta cocina en el KDS',
                      ),
                      items: cocinasDlg
                          .where((c) => c['activa'] != false)
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['nombre'] as String? ?? ''),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDlg(() => cocinaId = v),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _checklistPermisos(
                    rol: rol,
                    seleccionados: permisosSel,
                    onChanged: (s) => setDlg(() => permisosSel = s),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    final n = nombre.text.trim();
    final e = email.text.trim();
    final p = pass.text;
    final sid = sucursalAsignada;
    final permisosFinal = permisosSel.toList()..sort();
    nombre.dispose();
    email.dispose();
    pass.dispose();

    if (ok != true || n.isEmpty || e.isEmpty || p.length < 6 || sid == null) {
      return;
    }
    if (_esRolCocina(rol) && (cocinaId == null || cocinaId!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elige la estación de cocina para este usuario'),
          ),
        );
      }
      return;
    }
    if (permisosFinal.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marca al menos un permiso')),
        );
      }
      return;
    }

    try {
      await _repo.crear(
        sucursalId: sid,
        nombre: n,
        email: e,
        contrasena: p,
        rol: _rolUi(rol),
        cocinaId: _esRolCocina(rol) ? cocinaId : null,
        permisos: permisosFinal,
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
          SnackBar(
            content: Text(mensajeErrorHttp(err, contexto: 'creación')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  Future<void> _editarUsuario(Map<String, dynamic> u) async {
    await _cargarCatalogoRoles();
    final rolActual = u['rol'] as String? ?? 'cajero';
    if (rolActual == 'admin') return;

    final nombre = TextEditingController(text: u['nombre'] as String? ?? '');
    String rol = _rolUi(rolActual);
    String? sucursalAsignada = u['sucursal_id'] as String? ?? _sucursalVistaId;
    String? cocinaId = u['cocina_id'] as String?;
    var cocinasDlg = await _cocinasDeSucursal(sucursalAsignada);
    if (!mounted) return;

    var permisosSel = Set<String>.from(_permisosDeRol(rol));
    final sidCtxPre = _sucursalVistaId;
    if (sidCtxPre != null) {
      try {
        final pe = await _repo.permisosUsuario(
          usuarioId: u['id'] as String,
          sucursalId: sidCtxPre,
        );
        final lista = pe['permisos'] as List<dynamic>? ?? [];
        if (lista.isNotEmpty) {
          final plantilla = _permisosDeRol(rol).toSet();
          permisosSel =
              lista.map((e) => e.toString()).where(plantilla.contains).toSet();
          if (permisosSel.isEmpty) {
            permisosSel = Set<String>.from(plantilla);
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final permisosIniciales = Set<String>.from(permisosSel);

    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            title: const Text('Editar usuario'),
            scrollable: true,
            content: SizedBox(
              width: MediaQuery.sizeOf(ctx).width.clamp(280.0, 560.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(u['email'] as String? ?? ''),
                    const SizedBox(height: 12),
                    if (widget.puedeGestionarMultiSucursal &&
                        _sucursales.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: sucursalAsignada,
                        decoration: const InputDecoration(
                          labelText: 'Sucursal',
                          helperText: 'Sede donde opera este usuario',
                        ),
                        items: _sucursales
                            .map(
                              (s) => DropdownMenuItem(
                                value: s['id'] as String,
                                child: Text(s['nombre'] as String? ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) async {
                          sucursalAsignada = v;
                          cocinaId = null;
                          cocinasDlg = await _cocinasDeSucursal(v);
                          setDlg(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: rol,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Rol'),
                      items: _rolesDisponibles
                          .map(
                            (r) => DropdownMenuItem(
                                value: r.$1, child: Text(r.$2)),
                          )
                          .toList(),
                      onChanged: (v) async {
                        rol = v ?? rol;
                        permisosSel = Set<String>.from(_permisosDeRol(rol));
                        if (_esRolCocina(rol) && cocinasDlg.isEmpty) {
                          cocinasDlg =
                              await _cocinasDeSucursal(sucursalAsignada);
                          if (cocinasDlg.isEmpty && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'No hay cocinas. Créalas antes de asignar el rol.',
                                ),
                                action: widget.onIrCocinas == null
                                    ? null
                                    : SnackBarAction(
                                        label: 'Crear cocina',
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          widget.onIrCocinas!();
                                        },
                                      ),
                              ),
                            );
                          }
                        }
                        if (!_esRolCocina(rol)) cocinaId = null;
                        setDlg(() {});
                      },
                    ),
                    if (_esRolCocina(rol)) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: cocinaId,
                        decoration: const InputDecoration(
                          labelText: 'Estación de cocina',
                          helperText:
                              'Solo verá tickets de esta cocina en el KDS',
                        ),
                        items: cocinasDlg
                            .where((c) => c['activa'] != false)
                            .map(
                              (c) => DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['nombre'] as String? ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDlg(() => cocinaId = v),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _checklistPermisos(
                      rol: rol,
                      seleccionados: permisosSel,
                      onChanged: (s) => setDlg(() => permisosSel = s),
                    ),
                  ],
                ),
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
          );
        },
      ),
    );

    final n = nombre.text.trim();
    final sidCtx = _sucursalVistaId;
    final sidDest = sucursalAsignada;
    final sidUsuario = u['sucursal_id'] as String? ?? sidCtx;
    final permisosFinal = permisosSel.toList()..sort();
    nombre.dispose();

    if (ok != true || n.length < 2 || sidCtx == null || sidDest == null) return;

    if (_esRolCocina(rol) && (cocinaId == null || cocinaId!.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Elige la estación de cocina para este usuario'),
          ),
        );
      }
      return;
    }
    if (permisosFinal.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marca al menos un permiso')),
        );
      }
      return;
    }

    final cambiaNombre = n != (u['nombre'] as String? ?? '');
    final cambiaRol = rol != _rolUi(rolActual);
    final cambiaSucursal = sidDest != sidUsuario;
    final cocinaActual = u['cocina_id'] as String?;
    final cambiaCocina = _esRolCocina(rol) && cocinaId != cocinaActual;
    final cambiaPermisos = permisosSel.length != permisosIniciales.length ||
        !permisosSel.containsAll(permisosIniciales);
    if (!cambiaNombre &&
        !cambiaRol &&
        !cambiaSucursal &&
        !cambiaCocina &&
        !cambiaPermisos) {
      return;
    }

    try {
      await _repo.actualizar(
        usuarioId: u['id'] as String,
        sucursalId: sidCtx,
        nombre: cambiaNombre ? n : null,
        rol: (cambiaRol || _esRolCocina(rolActual)) ? rol : null,
        sucursalDestinoId: cambiaSucursal ? sidDest : null,
        cocinaId: _esRolCocina(rol) ? cocinaId : null,
        permisos: cambiaPermisos || cambiaRol ? permisosFinal : null,
      );
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuario actualizado · ${_etiquetaRol(rol)}'),
          ),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(err, contexto: 'edición')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  Future<void> _toggleActivo(Map<String, dynamic> u) async {
    final sid = _sucursalVistaId;
    if (sid == null) return;
    final activo = u['activo'] as bool? ?? true;
    if (activo) {
      final nombre = u['nombre'] as String? ?? 'este usuario';
      final confirmado = await FoodyDialogo.mostrar<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.person_off_outlined,
            color: Theme.of(ctx).colorScheme.error,
          ),
          title: const Text('¿Desactivar el acceso?'),
          content: Text(
            '$nombre no podrá iniciar sesión en Foody hasta que vuelvas a '
            'activar su cuenta.',
          ),
          actions: [
            TextButton(
              key: const ValueKey<String>('usuario-mantener-activo'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Mantener activo'),
            ),
            FilledButton(
              key: const ValueKey<String>('usuario-confirmar-desactivacion'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Desactivar acceso'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
    }
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
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'estado')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    }
  }

  String _etiquetaRol(String? rol) => etiquetaRolStaff(rol);

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);
    final muestraSelectorSucursal =
        widget.puedeGestionarMultiSucursal && _sucursales.isNotEmpty;

    return ColoredBox(
      color: _scheme.surface,
      child: SaasScrollableShell(
        header: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 20,
              8,
              compacto ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin / Equipo',
                  style: TextStyle(
                    fontSize: 11,
                    color: _scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuarios',
                            style: TextStyle(
                              fontSize: compacto ? 18 : 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                              color: _scheme.onSurface,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _cargando
                                ? 'Cargando…'
                                : '${_usuarios.length} en sede · $_activos activos · toca para editar',
                            style: TextStyle(
                              color: _scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _nuevoUsuario,
                      style: FilledButton.styleFrom(
                        backgroundColor: _scheme.primary,
                        foregroundColor: _scheme.onPrimary,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.person_add_outlined, size: 18),
                      label: Text(compacto ? 'Nuevo' : 'Nuevo usuario'),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _inicializar,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.refresh,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (muestraSelectorSucursal) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _sucursalVistaId,
                    decoration: InputDecoration(
                      labelText: 'Ver usuarios de la sede',
                      isDense: true,
                      filled: true,
                      fillColor: _scheme.surfaceContainerLow,
                      prefixIcon: Icon(
                        Icons.store_outlined,
                        size: 18,
                        color: _scheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _scheme.outlineVariant),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: _scheme.outlineVariant),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: _scheme.onSurface,
                          width: 1.2,
                        ),
                      ),
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
                ],
                if (widget.puedeGestionarMultiSucursal &&
                    _sucursales.length <= 1) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _scheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: _scheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Solo hay una sede. Crea más en «Mis sucursales» '
                            'para asignar usuarios a otras ubicaciones.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: _scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _inicializar,
                    color: _scheme.onSurface,
                    child: _usuarios.isEmpty
                        ? _vacio()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final anchoTabla = constraints.maxWidth >= 1100;
                              final padding = EdgeInsets.fromLTRB(
                                compacto ? 12 : 20,
                                4,
                                compacto ? 12 : 20,
                                32,
                              );
                              if (anchoTabla) {
                                return ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: padding,
                                  children: [_tablaUsuarios()],
                                );
                              }
                              return ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: padding,
                                itemCount: _usuarios.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) =>
                                    _tarjetaUsuario(_usuarios[i]),
                              );
                            },
                          ),
                  ),
      ),
    );
  }

  Widget _estadoError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                size: 36,
                color: AnaliticaTokens.alertas,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: _scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _cargar,
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vacio() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.group_outlined,
                  size: 24,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sin usuarios en ${_nombreSucursal(_sucursalVistaId)}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Crea cajeros, meseros o cocina para que el equipo '
                'pueda operar esta sede.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _nuevoUsuario,
                style: FilledButton.styleFrom(
                  backgroundColor: _scheme.primary,
                  foregroundColor: _scheme.onPrimary,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Nuevo usuario'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaUsuario(Map<String, dynamic> u) {
    final activo = u['activo'] as bool? ?? true;
    final esAdmin = u['rol'] == 'admin';
    final rol = u['rol'] as String?;
    final colorRol = _colorRol(rol);
    final cocina = u['cocina_nombre'] as String?;
    final nombre = u['nombre'] as String? ?? '';
    final email = u['email'] as String? ?? '';

    return Material(
      color: _scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
      child: InkWell(
        onTap: esAdmin ? null : () => _editarUsuario(u),
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: _scheme.outlineVariant),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: activo
                        ? colorRol.withValues(alpha: 0.1)
                        : _scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: activo
                          ? colorRol.withValues(alpha: 0.25)
                          : _scheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    _iniciales(nombre),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: activo ? colorRol : _scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: activo
                                    ? _scheme.onSurface
                                    : _scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: activo
                                  ? AnaliticaTokens.inventario
                                  : _scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(_etiquetaRol(rol), colorRol),
                          if (cocina != null && cocina.isNotEmpty)
                            _badge(cocina, _scheme.onSurfaceVariant),
                          _badge(
                            activo ? 'Activo' : 'Inactivo',
                            activo
                                ? AnaliticaTokens.inventario
                                : _scheme.onSurfaceVariant,
                          ),
                          if (esAdmin) _badge('Propietario', _scheme.onSurface),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!esAdmin)
                  Switch.adaptive(
                    value: activo,
                    activeTrackColor: _scheme.primary,
                    onChanged: (_) => _toggleActivo(u),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tablaUsuarios() {
    return Container(
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            horizontalMargin: 18,
            columnSpacing: 28,
            headingRowHeight: 48,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 72,
            headingRowColor: WidgetStatePropertyAll(
              _scheme.surfaceContainerHighest,
            ),
            border: TableBorder(
              horizontalInside: BorderSide(color: _scheme.outlineVariant),
            ),
            columns: const [
              DataColumn(label: Text('Usuario')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Estación')),
              DataColumn(label: Text('Estado')),
            ],
            rows: _usuarios.map((u) {
              final nombre = u['nombre'] as String? ?? '';
              final email = u['email'] as String? ?? '';
              final rol = u['rol'] as String?;
              final cocina = u['cocina_nombre'] as String?;
              final activo = u['activo'] as bool? ?? true;
              final esAdmin = rol == 'admin';
              final colorRol = _colorRol(rol);

              return DataRow(
                onSelectChanged: esAdmin ? null : (_) => _editarUsuario(u),
                cells: [
                  DataCell(
                    SizedBox(
                      width: 300,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: activo
                                ? colorRol.withValues(alpha: 0.1)
                                : _scheme.surfaceContainerHighest,
                            foregroundColor:
                                activo ? colorRol : _scheme.onSurfaceVariant,
                            child: Text(
                              _iniciales(nombre),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: activo
                                        ? _scheme.onSurface
                                        : _scheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _badge(_etiquetaRol(rol), colorRol),
                        if (esAdmin) _badge('Propietario', _scheme.onSurface),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      cocina?.isNotEmpty == true ? cocina! : '—',
                      style: TextStyle(color: _scheme.onSurfaceVariant),
                    ),
                  ),
                  DataCell(
                    esAdmin
                        ? _badge('Protegido', _scheme.onSurfaceVariant)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _badge(
                                activo ? 'Activo' : 'Inactivo',
                                activo
                                    ? AnaliticaTokens.inventario
                                    : _scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Switch.adaptive(
                                value: activo,
                                activeTrackColor: _scheme.primary,
                                onChanged: (_) => _toggleActivo(u),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _badge(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
