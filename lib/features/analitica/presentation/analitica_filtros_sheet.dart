import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/catalogo/data/catalogo_admin_repository.dart';
import 'package:reserva_canchas/features/cocinas/data/cocinas_repository.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';

/// Estado de filtros avanzados del Centro de Análisis (solo UI → query API).
class AnaliticaFiltros {
  AnaliticaFiltros({
    this.horaDesde,
    this.horaHasta,
    this.estados = const [],
    this.soloPendientePago = false,
    this.meseraIds = const [],
    this.cocinaIds = const [],
    this.categoriaIds = const [],
    this.clienteSegmento,
  });

  int? horaDesde;
  int? horaHasta;
  List<String> estados;
  bool soloPendientePago;
  List<String> meseraIds;
  List<String> cocinaIds;
  List<String> categoriaIds;
  /// `frecuente`, `nuevo` o null = todos.
  String? clienteSegmento;

  AnaliticaFiltros copiar() => AnaliticaFiltros(
        horaDesde: horaDesde,
        horaHasta: horaHasta,
        estados: List<String>.from(estados),
        soloPendientePago: soloPendientePago,
        meseraIds: List<String>.from(meseraIds),
        cocinaIds: List<String>.from(cocinaIds),
        categoriaIds: List<String>.from(categoriaIds),
        clienteSegmento: clienteSegmento,
      );

  int get activos {
    var n = 0;
    if (horaDesde != null) n++;
    if (horaHasta != null) n++;
    if (estados.isNotEmpty) n++;
    if (soloPendientePago) n++;
    if (meseraIds.isNotEmpty) n++;
    if (cocinaIds.isNotEmpty) n++;
    if (categoriaIds.isNotEmpty) n++;
    if (clienteSegmento != null && clienteSegmento!.isNotEmpty) n++;
    return n;
  }

  Map<String, dynamic> toQuery() {
    final q = <String, dynamic>{};
    if (horaDesde != null) q['hora_desde'] = horaDesde;
    if (horaHasta != null) q['hora_hasta'] = horaHasta;
    if (estados.isNotEmpty) q['estados'] = estados.join(',');
    if (soloPendientePago) q['solo_pendiente_pago'] = 'true';
    if (meseraIds.isNotEmpty) q['mesera_ids'] = meseraIds.join(',');
    if (cocinaIds.isNotEmpty) q['cocina_ids'] = cocinaIds.join(',');
    if (categoriaIds.isNotEmpty) q['categoria_ids'] = categoriaIds.join(',');
    if (clienteSegmento != null && clienteSegmento!.isNotEmpty) {
      q['cliente_segmento'] = clienteSegmento;
    }
    return q;
  }

  String etiquetaResumen() {
    final partes = <String>[];
    if (horaDesde != null || horaHasta != null) {
      partes.add('Hora ${horaDesde ?? 0}–${horaHasta ?? 23}');
    }
    if (estados.isNotEmpty) partes.add('Estados: ${estados.length}');
    if (soloPendientePago) partes.add('Solo pendiente pago');
    if (meseraIds.isNotEmpty) partes.add('Meseros: ${meseraIds.length}');
    if (cocinaIds.isNotEmpty) partes.add('Cocinas: ${cocinaIds.length}');
    if (categoriaIds.isNotEmpty) partes.add('Categorías: ${categoriaIds.length}');
    if (clienteSegmento != null) {
      partes.add(
        clienteSegmento == 'frecuente' ? 'Clientes frecuentes' : 'Clientes nuevos',
      );
    }
    return partes.isEmpty ? 'Sin filtros' : partes.join(' · ');
  }

  void limpiar() {
    horaDesde = null;
    horaHasta = null;
    estados = [];
    soloPendientePago = false;
    meseraIds = [];
    cocinaIds = [];
    categoriaIds = [];
    clienteSegmento = null;
  }
}

const estadosAnalitica = [
  ('pagado', 'Pagado'),
  ('pendiente_aprobacion', 'Pendiente QR'),
  ('pendiente', 'Pendiente'),
  ('confirmado', 'Confirmado'),
  ('en_cocina', 'En cocina'),
  ('listo', 'Listo'),
  ('pagando', 'Pagando'),
  ('asignado', 'Asignado'),
  ('en_camino', 'En camino'),
  ('entregado', 'Entregado'),
  ('cancelado', 'Cancelado'),
  ('rechazado', 'Rechazado'),
];

/// Bottom sheet de filtros avanzados.
Future<AnaliticaFiltros?> mostrarAnaliticaFiltrosSheet({
  required BuildContext context,
  required String sucursalId,
  required AnaliticaFiltros filtrosIniciales,
}) {
  return showModalBottomSheet<AnaliticaFiltros>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AnaliticaTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _AnaliticaFiltrosSheetBody(
      sucursalId: sucursalId,
      filtros: filtrosIniciales.copiar(),
    ),
  );
}

class _AnaliticaFiltrosSheetBody extends StatefulWidget {
  const _AnaliticaFiltrosSheetBody({
    required this.sucursalId,
    required this.filtros,
  });

  final String sucursalId;
  final AnaliticaFiltros filtros;

  @override
  State<_AnaliticaFiltrosSheetBody> createState() =>
      _AnaliticaFiltrosSheetBodyState();
}

class _AnaliticaFiltrosSheetBodyState extends State<_AnaliticaFiltrosSheetBody> {
  final _usuariosRepo = UsuariosRepository();
  final _cocinasRepo = CocinasRepository();
  final _catalogoRepo = CatalogoAdminRepository();

  late AnaliticaFiltros _f;
  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _meseros = [];
  List<Map<String, dynamic>> _cocinas = [];
  List<Map<String, dynamic>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _f = widget.filtros;
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final usuarios = await _usuariosRepo.listar(widget.sucursalId);
      final cocinas = await _cocinasRepo.listarCocinas(widget.sucursalId);
      final categorias = await _catalogoRepo.categorias(widget.sucursalId);
      if (mounted) {
        setState(() {
          _meseros = usuarios.where((u) => u['rol'] == 'mesero').toList();
          _cocinas = cocinas;
          _categorias = categorias;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = mensajeErrorHttp(e, contexto: 'filtros');
          _cargando = false;
        });
      }
    }
  }

  void _toggleLista(List<String> lista, String id) {
    setState(() {
      if (lista.contains(id)) {
        lista.remove(id);
      } else {
        lista.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AnaliticaTokens.inkMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros inteligentes',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                    ),
                    Text(
                      _f.activos == 0
                          ? 'Sin filtros activos'
                          : '${_f.activos} filtros activos · ${_f.etiquetaResumen()}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _seccion('Rango horario', Icons.schedule_rounded),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            decoration: _inputDeco('Desde (h)'),
                            value: _f.horaDesde,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('—'),
                              ),
                              for (var h = 0; h < 24; h++)
                                DropdownMenuItem(
                                  value: h,
                                  child: Text('$h:00'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _f.horaDesde = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            decoration: _inputDeco('Hasta (h)'),
                            value: _f.horaHasta,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('—'),
                              ),
                              for (var h = 0; h < 24; h++)
                                DropdownMenuItem(
                                  value: h,
                                  child: Text('$h:00'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _f.horaHasta = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _seccion('Estados de pedido', Icons.flag_rounded),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in estadosAnalitica)
                          FilterChip(
                            label: Text(e.$2),
                            selected: _f.estados.contains(e.$1),
                            selectedColor: AnaliticaTokens.surfaceMuted,
                            checkmarkColor: AnaliticaTokens.ink,
                            onSelected: (_) => _toggleLista(_f.estados, e.$1),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo pendiente de pago'),
                      value: _f.soloPendientePago,
                      activeColor: AnaliticaTokens.ventas,
                      onChanged: (v) =>
                          setState(() => _f.soloPendientePago = v),
                    ),
                    const SizedBox(height: 8),
                    _seccion('Meseros', Icons.person_outline_rounded),
                    if (_meseros.isEmpty)
                      const Text(
                        'Sin meseros en esta sede',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final m in _meseros)
                            FilterChip(
                              label: Text(m['nombre'] as String? ?? ''),
                              selected: _f.meseraIds.contains('${m['id']}'),
                              selectedColor: AnaliticaTokens.surfaceMuted,
                              onSelected: (_) =>
                                  _toggleLista(_f.meseraIds, '${m['id']}'),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    _seccion('Cocinas', Icons.soup_kitchen_outlined),
                    if (_cocinas.isEmpty)
                      const Text('Sin cocinas', style: TextStyle(fontSize: 13))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in _cocinas)
                            FilterChip(
                              label: Text(c['nombre'] as String? ?? ''),
                              selected: _f.cocinaIds.contains('${c['id']}'),
                              selectedColor: AnaliticaTokens.surfaceMuted,
                              onSelected: (_) =>
                                  _toggleLista(_f.cocinaIds, '${c['id']}'),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    _seccion('Categorías', Icons.category_outlined),
                    if (_categorias.isEmpty)
                      const Text(
                        'Sin categorías',
                        style: TextStyle(fontSize: 13),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final cat in _categorias)
                            FilterChip(
                              label: Text(cat['nombre'] as String? ?? ''),
                              selected:
                                  _f.categoriaIds.contains('${cat['id']}'),
                              selectedColor: AnaliticaTokens.surfaceMuted,
                              onSelected: (_) => _toggleLista(
                                _f.categoriaIds,
                                '${cat['id']}',
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    _seccion('Segmento de cliente', Icons.groups_rounded),
                    SegmentedButton<String?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('Todos')),
                        ButtonSegment(
                          value: 'frecuente',
                          label: Text('Frecuente'),
                        ),
                        ButtonSegment(value: 'nuevo', label: Text('Nuevo')),
                      ],
                      selected: {_f.clienteSegmento},
                      onSelectionChanged: (s) =>
                          setState(() => _f.clienteSegmento = s.first),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => setState(_f.limpiar),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AnaliticaTokens.inkMuted,
                  side: const BorderSide(color: AnaliticaTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Limpiar'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _cargando ? null : () => Navigator.pop(context, _f),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Aplicar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AnaliticaTokens.ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: AnaliticaTokens.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnaliticaTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AnaliticaTokens.border),
        ),
      );

  Widget _seccion(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icono, size: 16, color: AnaliticaTokens.ventas),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AnaliticaTokens.ink,
                ),
          ),
        ],
      ),
    );
  }
}
