import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/features/almacenamiento/data/almacenamiento_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/sucursales/data/sucursales_repository.dart';

class SucursalesAdminScreen extends StatefulWidget {
  const SucursalesAdminScreen({
    super.key,
    this.onIrHorarios,
    this.onIrZonas,
    this.repository,
  });

  final VoidCallback? onIrHorarios;
  final VoidCallback? onIrZonas;
  final SucursalesRepository? repository;

  @override
  State<SucursalesAdminScreen> createState() => _SucursalesAdminScreenState();
}

class _SucursalesAdminScreenState extends State<SucursalesAdminScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final SucursalesRepository _repo;
  final _almacenamiento = AlmacenamientoRepository();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _sucursales = [];
  Map<String, dynamic>? _marca;
  bool _cargando = true;
  bool _subiendoMarca = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? SucursalesRepository();
    _cargar();
  }

  Widget _contenidoDialogo(BuildContext context, Widget child) {
    final size = MediaQuery.sizeOf(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: size.width * 0.9,
        maxHeight: size.height * 0.58,
      ),
      child: SingleChildScrollView(child: child),
    );
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _repo.listarMiRestaurante();
      Map<String, dynamic>? marca;
      try {
        marca = await _repo.obtenerMarca();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _sucursales = lista;
        _marca = marca;
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

  void _avisar(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AnaliticaTokens.alertas : _scheme.onSurface,
      ),
    );
  }

  Future<void> _subirMarca({required bool esBanner}) async {
    final sid =
        _sucursales.isNotEmpty ? _sucursales.first['id'] as String? : null;
    if (sid == null) {
      _avisar('Crea al menos una sucursal antes de subir fotos', error: true);
      return;
    }
    final pick = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: esBanner ? 1600 : 800,
      imageQuality: 85,
    );
    if (pick == null) return;
    setState(() => _subiendoMarca = true);
    try {
      final url = await _almacenamiento.subirImagen(
        sucursalId: sid,
        bytes: await pick.readAsBytes(),
        tipo: 'general',
        nombreArchivo: pick.name,
      );
      final marca = await _repo.actualizarMarca(
        logoUrl: esBanner ? null : url,
        bannerUrl: esBanner ? url : null,
      );
      if (!mounted) return;
      setState(() {
        _marca = marca;
        _subiendoMarca = false;
      });
      _avisar(esBanner ? 'Portada actualizada' : 'Logo actualizado');
    } catch (e) {
      if (mounted) setState(() => _subiendoMarca = false);
      _avisar(mensajeErrorHttp(e, contexto: 'subir imagen'), error: true);
    }
  }

  Future<void> _editarDatosMarca() async {
    final nombreCtrl = TextEditingController(
      text: _marca?['nombre'] as String? ?? '',
    );
    final telCtrl = TextEditingController(
      text: _marca?['telefono'] as String? ?? '',
    );
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datos de marca'),
        content: _contenidoDialogo(
          ctx,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del restaurante',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                ),
                keyboardType: TextInputType.phone,
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
            onPressed: () =>
                Navigator.pop(ctx, nombreCtrl.text.trim().isNotEmpty),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      return;
    }
    try {
      final marca = await _repo.actualizarMarca(
        nombre: nombreCtrl.text.trim(),
        telefono: telCtrl.text.trim(),
      );
      nombreCtrl.dispose();
      telCtrl.dispose();
      if (!mounted) return;
      setState(() => _marca = marca);
      _avisar('Marca actualizada');
    } catch (e) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      _avisar(mensajeErrorHttp(e, contexto: 'actualizar marca'), error: true);
    }
  }

  void _verImagenCompleta(String url, String titulo, {required bool esBanner}) {
    FoodyDialogo.mostrar<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(titulo)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AnaliticaTokens.inventario.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AnaliticaTokens.inventario,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Cargada',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AnaliticaTokens.inventario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: _contenidoDialogo(
          ctx,
          SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                    ),
                    child: AspectRatio(
                      aspectRatio: esBanner ? 16 / 7 : 1,
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => _placeholderBanner(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  esBanner
                      ? 'Banner · recomendado 1600×600'
                      : 'Logo circular · recomendado 800×800',
                  style: TextStyle(
                    fontSize: 12,
                    color: _scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _subirMarca(esBanner: esBanner);
            },
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _nuevaSucursal() async {
    final nombreCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva sucursal'),
        content: _contenidoDialogo(
          ctx,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dirCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección (opcional)',
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
            onPressed: () =>
                Navigator.pop(ctx, nombreCtrl.text.trim().isNotEmpty),
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
      _avisar('Sucursal creada');
      _cargar();
    } catch (e) {
      nombreCtrl.dispose();
      dirCtrl.dispose();
      _avisar(mensajeErrorHttp(e, contexto: 'crear sucursal'), error: true);
    }
  }

  Future<void> _editarSucursal(Map<String, dynamic> s) async {
    final id = s['id'] as String?;
    if (id == null) return;
    final nombreCtrl =
        TextEditingController(text: s['nombre'] as String? ?? '');
    final dirCtrl =
        TextEditingController(text: s['direccion'] as String? ?? '');
    final telCtrl = TextEditingController(text: s['telefono'] as String? ?? '');
    var activa = s['activa'] != false;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Editar sucursal'),
          content: _contenidoDialogo(
            ctx,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: dirCtrl,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: telCtrl,
                  decoration: const InputDecoration(labelText: 'Teléfono'),
                  keyboardType: TextInputType.phone,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sucursal activa'),
                  value: activa,
                  onChanged: (v) => setLocal(() => activa = v),
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
              onPressed: () =>
                  Navigator.pop(ctx, nombreCtrl.text.trim().isNotEmpty),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      dirCtrl.dispose();
      telCtrl.dispose();
      return;
    }
    try {
      await _repo.actualizar(
        id: id,
        nombre: nombreCtrl.text.trim(),
        direccion: dirCtrl.text.trim(),
        telefono: telCtrl.text.trim(),
        activa: activa,
      );
      nombreCtrl.dispose();
      dirCtrl.dispose();
      telCtrl.dispose();
      _avisar('Sucursal actualizada');
      _cargar();
    } catch (e) {
      nombreCtrl.dispose();
      dirCtrl.dispose();
      telCtrl.dispose();
      _avisar(mensajeErrorHttp(e, contexto: 'editar sucursal'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

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
                  'Admin / Sucursal',
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
                            'Mis sucursales',
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
                                : '${_sucursales.length} sede${_sucursales.length == 1 ? '' : 's'} · menú, mesas y pedidos por ubicación',
                            style: TextStyle(
                              color: _scheme.onSurfaceVariant,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _nuevaSucursal,
                      style: FilledButton.styleFrom(
                        backgroundColor: _scheme.primary,
                        foregroundColor: _scheme.onPrimary,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(compacto ? 'Nueva' : 'Nueva sucursal'),
                    ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.refresh,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        body: _cargando
            ? AnaliticaSkeleton.tab()
            : _error != null
                ? _estadoError()
                : RefreshIndicator(
                    onRefresh: _cargar,
                    color: _scheme.onSurface,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        compacto ? 12 : 20,
                        4,
                        compacto ? 12 : 20,
                        32,
                      ),
                      children: [
                        _seccionMarca(compacto),
                        const SizedBox(height: 16),
                        _encabezadoLista(),
                        const SizedBox(height: 10),
                        if (_sucursales.isEmpty)
                          _vacio()
                        else
                          ..._sucursales.map(_tarjetaSucursal),
                      ],
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

  Widget _seccionMarca(bool compacto) {
    final logo = _marca?['logo_url'] as String?;
    final banner = _marca?['banner_url'] as String?;
    final nombre = _marca?['nombre'] as String? ?? 'Tu restaurante';
    final telefono = (_marca?['telefono'] as String?)?.trim();

    return Container(
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(color: _scheme.outlineVariant),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marca en la app cliente',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _scheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Así se ve tu restaurante en la lista de lugares. '
                        'Toca la portada o el logo para verlos o cambiarlos.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: _scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _subiendoMarca ? null : _editarDatosMarca,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Nombre / tel'),
                ),
                if (_subiendoMarca)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _scheme.onSurface,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _vistaPreviaCliente(
              nombre: nombre,
              telefono: telefono,
              logo: logo,
              banner: banner,
              compacto: compacto,
            ),
          ],
        ),
      ),
    );
  }

  /// Mock de la tarjeta que ve el cliente (+ acciones de marca).
  Widget _vistaPreviaCliente({
    required String nombre,
    String? telefono,
    required String? logo,
    required String? banner,
    required bool compacto,
  }) {
    final tieneLogo = logo != null && logo.isNotEmpty;
    final tieneBanner = banner != null && banner.isNotEmpty;
    final listo = tieneBanner && tieneLogo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (tieneBanner) {
                        _verImagenCompleta(
                          banner,
                          'Portada',
                          esBanner: true,
                        );
                      } else if (!_subiendoMarca) {
                        _subirMarca(esBanner: true);
                      }
                    },
                    child: SizedBox(
                      height: compacto ? 128 : 156,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          tieneBanner
                              ? Image.network(
                                  banner,
                                  fit: BoxFit.cover,
                                  cacheWidth: 900,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderBanner(),
                                )
                              : _placeholderBanner(),
                          if (_subiendoMarca)
                            const ColoredBox(
                              color: Color(0x66111827),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: _badgeEstado(
                              listo: listo,
                              tieneBanner: tieneBanner,
                              tieneLogo: tieneLogo,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: _chipAccion(
                              icon: tieneBanner
                                  ? Icons.zoom_in
                                  : Icons.upload_outlined,
                              onTap: () {
                                if (tieneBanner) {
                                  _verImagenCompleta(
                                    banner,
                                    'Portada',
                                    esBanner: true,
                                  );
                                } else if (!_subiendoMarca) {
                                  _subirMarca(esBanner: true);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: -22,
                    child: GestureDetector(
                      onTap: () {
                        if (tieneLogo) {
                          _verImagenCompleta(logo, 'Logo', esBanner: false);
                        } else if (!_subiendoMarca) {
                          _subirMarca(esBanner: false);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: AnaliticaTokens.shadowSoft,
                            ),
                            child: ClipOval(
                              child: tieneLogo
                                  ? Image.network(
                                      logo,
                                      fit: BoxFit.cover,
                                      width: 56,
                                      height: 56,
                                      cacheWidth: 168,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholderLogo(),
                                    )
                                  : _placeholderLogo(),
                            ),
                          ),
                          if (tieneLogo)
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: AnaliticaTokens.inventario,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _scheme.surfaceContainerLow,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 28, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _scheme.onSurface,
                            ),
                          ),
                          if (telefono != null && telefono.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              telefono,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            listo
                                ? 'Listo para clientes'
                                : [
                                    if (!tieneBanner) 'Falta portada',
                                    if (!tieneLogo) 'Falta logo',
                                  ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: listo
                                  ? AnaliticaTokens.inventario
                                  : _scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _scheme.onSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Ver menú',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _subiendoMarca ? null : () => _subirMarca(esBanner: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  tieneBanner ? Icons.sync : Icons.image_outlined,
                  size: 16,
                ),
                label: Text(tieneBanner ? 'Cambiar portada' : 'Subir portada'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _subiendoMarca ? null : () => _subirMarca(esBanner: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _scheme.onSurface,
                  side: BorderSide(color: _scheme.outlineVariant),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(
                  tieneLogo ? Icons.sync : Icons.account_circle_outlined,
                  size: 16,
                ),
                label: Text(tieneLogo ? 'Cambiar logo' : 'Subir logo'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _badgeEstado({
    required bool listo,
    required bool tieneBanner,
    required bool tieneLogo,
  }) {
    final color = listo ? AnaliticaTokens.inventario : _scheme.onSurface;
    final texto = listo
        ? 'Listo'
        : !tieneBanner && !tieneLogo
            ? 'Sin imágenes'
            : 'Incompleto';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            listo ? Icons.check_circle : Icons.info_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipAccion({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: _scheme.onSurface.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _placeholderBanner() {
    return Container(
      color: _scheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 32,
              color: _scheme.onSurfaceVariant,
            ),
            SizedBox(height: 6),
            Text(
              'Toca para subir portada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderLogo() {
    return Container(
      color: _scheme.surfaceContainerHighest,
      child: Icon(
        Icons.storefront_outlined,
        size: 24,
        color: _scheme.onSurfaceVariant,
      ),
    );
  }

  Widget _encabezadoLista() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sedes',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _scheme.onSurface,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Cada sucursal tiene su propio menú, mesas y pedidos.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.35,
            color: _scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
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
              Icons.store_outlined,
              size: 24,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Aún no tienes sucursales',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Crea la primera sede para operar menú, mesas y pedidos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _nuevaSucursal,
            style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear sucursal'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSucursal(Map<String, dynamic> s) {
    final nombre = s['nombre'] as String? ?? '';
    final dir = (s['direccion'] as String?)?.trim();
    final ciudad = (s['ciudad_nombre'] as String?)?.trim() ?? '';
    final activa = s['activa'] != false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: Opacity(
          opacity: activa ? 1 : 0.55,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              border: Border.all(color: _scheme.outlineVariant),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _scheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _scheme.onSurface.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.store_outlined,
                      size: 20,
                      color: _scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _badge(
                              (dir == null || dir.isEmpty)
                                  ? 'Sin dirección'
                                  : dir,
                              _scheme.onSurfaceVariant,
                            ),
                            if (ciudad.isNotEmpty)
                              _badge(ciudad, AnaliticaTokens.pedidos),
                            if (!activa)
                              _badge('Inactiva', _scheme.onSurfaceVariant),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    icon: Icon(
                      Icons.more_vert,
                      color: _scheme.onSurfaceVariant,
                    ),
                    onSelected: (v) {
                      if (v == 'editar') unawaited(_editarSucursal(s));
                      if (v == 'horarios') widget.onIrHorarios?.call();
                      if (v == 'zonas') widget.onIrZonas?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar sede'),
                      ),
                      if (widget.onIrHorarios != null)
                        const PopupMenuItem(
                          value: 'horarios',
                          child: Text('Horarios'),
                        ),
                      if (widget.onIrZonas != null)
                        const PopupMenuItem(
                          value: 'zonas',
                          child: Text('Zonas domicilio'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
