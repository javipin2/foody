import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/almacenamiento/data/almacenamiento_repository.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/menu/data/menu_repository.dart';
import 'package:reserva_canchas/features/promociones/data/promociones_repository.dart';

/// Publicar historias / promos de la sucursal (admin).
class PromocionesAdminScreen extends StatefulWidget {
  const PromocionesAdminScreen({
    super.key,
    required this.sucursalId,
    this.onIrMenu,
    this.repository,
    this.menuRepository,
  });

  final String? sucursalId;
  final VoidCallback? onIrMenu;
  final PromocionesRepository? repository;
  final MenuRepository? menuRepository;

  @override
  State<PromocionesAdminScreen> createState() => _PromocionesAdminScreenState();
}

class _PromocionesAdminScreenState extends State<PromocionesAdminScreen> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  late final PromocionesRepository _repo;
  late final MenuRepository _menuRepo;
  final _almacenamiento = AlmacenamientoRepository();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _promos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? PromocionesRepository();
    _menuRepo = widget.menuRepository ?? MenuRepository();
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
        backgroundColor:
            error ? AnaliticaTokens.alertas : AnaliticaTokens.inventario,
      ),
    );
  }

  Future<void> _dialogoCrear() async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final resultado = await FoodyDialogo.mostrar<_DatosNuevaPromo>(
      context: context,
      builder: (ctx) => _DialogoNuevaPromocion(
        picker: _picker,
        sucursalId: sid,
        menuRepository: _menuRepo,
      ),
    );
    if (resultado == null) return;

    try {
      final esVideo = resultado.tipoMedia == 'video';
      final mediaUrl = esVideo
          ? await _almacenamiento.subirVideo(
              sucursalId: sid,
              bytes: resultado.bytes,
              nombreArchivo: resultado.nombreArchivo,
            )
          : await _almacenamiento.subirImagen(
              sucursalId: sid,
              bytes: resultado.bytes,
              tipo: 'promocion',
              nombreArchivo: resultado.nombreArchivo,
            );
      await _repo.crear(
        sucursalId: sid,
        titulo: resultado.titulo,
        imagenUrl: mediaUrl,
        descripcion: resultado.descripcion,
        productoId: resultado.productoId,
        tipoMedia: resultado.tipoMedia,
      );
      _avisar('Estado publicado · visible 24 horas');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e), error: true);
    }
  }

  Future<void> _cambiarFoto(Map<String, dynamic> promo) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final pick = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pick == null) return;

    try {
      await _almacenamiento.subirImagenPromocion(
        promocionId: promo['id'] as String,
        sucursalId: sid,
        bytes: await pick.readAsBytes(),
        nombreArchivo: pick.name,
      );
      _avisar('Imagen actualizada');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'imagen'), error: true);
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

  Future<void> _eliminar(Map<String, dynamic> promo) async {
    final id = promo['id'] as String?;
    if (id == null) return;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _scheme.surfaceContainerLow,
        title: Text(
          '¿Eliminar estado?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _scheme.onSurface,
          ),
        ),
        content: Text(
          'Se borra de forma permanente. Los clientes ya no lo verán.',
          style: TextStyle(fontSize: 13.5, color: _scheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: _scheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AnaliticaTokens.alertas,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.eliminar(id);
      _avisar('Estado eliminado');
      _cargar();
    } catch (e) {
      _avisar(mensajeErrorHttp(e, contexto: 'eliminar'), error: true);
    }
  }

  int get _activas => _promos.where((p) => p['activa'] as bool? ?? true).length;

  @override
  Widget build(BuildContext context) {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: _scheme.surface,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _dialogoCrear,
          backgroundColor: _scheme.primary,
          foregroundColor: _scheme.onPrimary,
          elevation: 2,
          icon: const Icon(Icons.add, size: 20),
          label: Text(
            compacto ? 'Nuevo' : 'Nuevo estado',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _cargar,
          color: _scheme.onSurface,
          child: _cargando
              ? AnaliticaSkeleton.tab()
              : _error != null
                  ? _estadoError()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        compacto ? 12 : 20,
                        8,
                        compacto ? 12 : 20,
                        96,
                      ),
                      children: [
                        _header(compacto),
                        const SizedBox(height: 14),
                        if (_promos.isEmpty)
                          _vacio()
                        else ...[
                          for (final p in _promos) ...[
                            _tarjetaPromo(p),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _header(bool compacto) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin / Menú e Inventario',
          style: TextStyle(
            fontSize: 11,
            color: _scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                'Promociones',
                style: TextStyle(
                  fontSize: compacto ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: _scheme.onSurface,
                  height: 1.15,
                ),
              ),
            ),
            if (widget.onIrMenu != null)
              TextButton.icon(
                onPressed: widget.onIrMenu,
                style: TextButton.styleFrom(
                  foregroundColor: _scheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.restaurant_menu, size: 16),
                label: const Text('Ver menú', style: TextStyle(fontSize: 12.5)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _promos.isEmpty
              ? 'Estados tipo story · visibles 24 h en el menú del cliente'
              : '$_activas activas · ${_promos.length} en total · expiran en 24 h',
          style: TextStyle(
            color: _scheme.onSurfaceVariant,
            fontSize: 12.5,
          ),
        ),
      ],
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
    return Container(
      margin: const EdgeInsets.only(top: 24),
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
              Icons.auto_awesome_outlined,
              size: 24,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin promociones',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Publica la primera: foto o video ≤30 s, visible 24 horas en el menú.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: _scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _dialogoCrear,
            style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Nuevo estado'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPromo(Map<String, dynamic> p) {
    final activa = p['activa'] as bool? ?? true;
    final esVideo = (p['tipo_media'] as String?) == 'video';
    final url = p['imagen_url'] as String?;
    final titulo = p['titulo'] as String? ?? 'Promo';
    final producto = p['producto_nombre'] as String?;
    final vistas = p['vistas'] ?? 0;
    final colorEstado =
        activa ? AnaliticaTokens.inventario : _scheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: _scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        border: Border.all(
          color: activa ? _scheme.outlineVariant : _scheme.outlineVariant,
        ),
        boxShadow: AnaliticaTokens.shadowSoft,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(url: url, esVideo: esVideo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _scheme.onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _badge(
                        activa ? 'Activa' : 'Inactiva',
                        colorEstado,
                      ),
                      if (esVideo) _badge('Video', AnaliticaTokens.pedidos),
                      if (p['expira_at'] != null)
                        _badge('24 h', _scheme.onSurfaceVariant),
                      _badge('$vistas vistas', _scheme.onSurfaceVariant),
                    ],
                  ),
                  if (producto != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '→ $producto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: _scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Más acciones',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: _scheme.onSurfaceVariant,
                  ),
                  onSelected: (a) {
                    if (a == 'foto') _cambiarFoto(p);
                    if (a == 'eliminar') _eliminar(p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'foto',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.photo_camera_outlined, size: 20),
                        title: Text('Cambiar foto',
                            style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'eliminar',
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AnaliticaTokens.alertas,
                        ),
                        title: const Text(
                          'Eliminar',
                          style: TextStyle(
                            fontSize: 13,
                            color: AnaliticaTokens.alertas,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: activa,
                  activeTrackColor: AnaliticaTokens.inventario,
                  onChanged: (_) => _toggleActiva(p),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb({required String? url, required bool esVideo}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 56,
        height: 56,
        color: _scheme.surfaceContainerHighest,
        child: esVideo
            ? Icon(Icons.videocam, color: _scheme.onSurfaceVariant)
            : (url != null && url.isNotEmpty)
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    cacheWidth: 168,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_offer_outlined,
                      color: _scheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.local_offer_outlined,
                    color: _scheme.onSurfaceVariant,
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
        border: Border.all(color: color.withValues(alpha: 0.25)),
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

class _DatosNuevaPromo {
  const _DatosNuevaPromo({
    required this.titulo,
    required this.descripcion,
    required this.bytes,
    required this.nombreArchivo,
    this.productoId,
    this.tipoMedia = 'imagen',
  });

  final String titulo;
  final String descripcion;
  final Uint8List bytes;
  final String nombreArchivo;
  final String? productoId;
  final String tipoMedia;
}

class _DialogoNuevaPromocion extends StatefulWidget {
  const _DialogoNuevaPromocion({
    required this.picker,
    required this.sucursalId,
    required this.menuRepository,
  });

  final ImagePicker picker;
  final String sucursalId;
  final MenuRepository menuRepository;

  @override
  State<_DialogoNuevaPromocion> createState() => _DialogoNuevaPromocionState();
}

class _DialogoNuevaPromocionState extends State<_DialogoNuevaPromocion> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Uint8List? _bytes;
  String _nombreArchivo = 'promo.jpg';
  String _tipoMedia = 'imagen';
  List<({String id, String nombre})> _productos = [];
  String? _productoId;
  bool _cargandoProductos = true;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    try {
      final menu = await widget.menuRepository.obtenerPorSucursal(
        widget.sucursalId,
      );
      if (!mounted) return;
      setState(() {
        _productos = [
          for (final p in menu.todosLosProductos)
            if (p.disponible) (id: p.id, nombre: p.nombre),
        ];
        _cargandoProductos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoProductos = false);
    }
  }

  Future<void> _elegirFoto() async {
    final pick = await widget.picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (pick == null) return;
    final bytes = await pick.readAsBytes();
    setState(() {
      _bytes = bytes;
      _nombreArchivo = pick.name;
      _tipoMedia = 'imagen';
    });
  }

  Future<void> _elegirVideo() async {
    final pick = await widget.picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (pick == null) return;
    final bytes = await pick.readAsBytes();
    // ponytail: techo 20 MB alineado con API; duración la limita ImagePicker.
    if (bytes.lengthInBytes > 20 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El video no puede superar 20 MB')),
      );
      return;
    }
    setState(() {
      _bytes = bytes;
      _nombreArchivo = pick.name.isNotEmpty ? pick.name : 'estado.mp4';
      _tipoMedia = 'video';
    });
  }

  void _publicar() {
    final titulo = _tituloCtrl.text.trim();
    if (titulo.isEmpty || _bytes == null) return;
    Navigator.pop(
      context,
      _DatosNuevaPromo(
        titulo: titulo,
        descripcion: _descCtrl.text.trim(),
        bytes: _bytes!,
        nombreArchivo: _nombreArchivo,
        productoId: _productoId,
        tipoMedia: _tipoMedia,
      ),
    );
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  InputDecoration _campo(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _scheme.onSurfaceVariant, fontSize: 13),
      filled: true,
      fillColor: _scheme.surfaceContainerHighest,
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
        borderSide: BorderSide(color: _scheme.onSurface, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listo = _tituloCtrl.text.trim().isNotEmpty && _bytes != null;

    return AlertDialog(
      backgroundColor: _scheme.surfaceContainerLow,
      title: Text(
        'Nuevo estado (24 h)',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _scheme.onSurface,
        ),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.9,
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Se publica como estado de WhatsApp y expira en 24 horas.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: _scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tituloCtrl,
                decoration: _campo('Título'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirFoto,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _scheme.onSurface,
                        side: BorderSide(color: _scheme.outlineVariant),
                      ),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Foto', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _elegirVideo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _scheme.onSurface,
                        side: BorderSide(color: _scheme.outlineVariant),
                      ),
                      icon: const Icon(Icons.videocam_outlined, size: 18),
                      label: const Text('Video ≤30s',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
              if (_bytes != null) ...[
                const SizedBox(height: 8),
                if (_tipoMedia == 'video')
                  Container(
                    height: 88,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _scheme.onSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Video listo · $_nombreArchivo',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        Image.memory(_bytes!, height: 120, fit: BoxFit.cover),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: _campo('Descripción'),
              ),
              const SizedBox(height: 12),
              if (_cargandoProductos)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: _scheme.onSurface,
                )
              else
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  // ignore: deprecated_member_use
                  value: _productoId,
                  decoration: _campo('Producto vinculado (opcional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin producto'),
                    ),
                    for (final p in _productos)
                      DropdownMenuItem<String?>(
                        value: p.id,
                        child: Text(p.nombre, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _productoId = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: _scheme.onSurfaceVariant),
          ),
        ),
        FilledButton(
          onPressed: listo ? _publicar : null,
          style: FilledButton.styleFrom(
              backgroundColor: _scheme.primary,
              foregroundColor: _scheme.onPrimary),
          child: const Text('Publicar'),
        ),
      ],
    );
  }
}
