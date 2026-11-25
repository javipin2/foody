import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:reserva_canchas/features/costeo/domain/unidad_costeo_util.dart';

/// Resultado del diálogo crear/editar subreceta.
class SubrecetaFormResultado {
  const SubrecetaFormResultado({
    required this.nombre,
    required this.cantidadResultado,
    required this.unidadResultado,
    required this.margenError,
    required this.items,
    this.recetaId,
    this.usaProduccionLote = false,
  });

  final String? recetaId;
  final String nombre;
  final double cantidadResultado;
  final String unidadResultado;
  final double margenError;
  final List<Map<String, dynamic>> items;
  final bool usaProduccionLote;
}

Future<SubrecetaFormResultado?> mostrarDialogoSubreceta({
  required BuildContext context,
  required List<Map<String, dynamic>> ingredientes,
  required List<Map<String, dynamic>> subrecetas,
  Map<String, dynamic>? subrecetaExistente,
  List<Map<String, dynamic>>? itemsExistentes,
}) {
  return FoodyDialogo.mostrar<SubrecetaFormResultado>(
    context: context,
    builder: (ctx) => _DialogoSubrecetaForm(
      ingredientes: ingredientes,
      subrecetas: subrecetas,
      subrecetaExistente: subrecetaExistente,
      itemsExistentes: itemsExistentes,
    ),
  );
}

class _DialogoSubrecetaForm extends StatefulWidget {
  const _DialogoSubrecetaForm({
    required this.ingredientes,
    required this.subrecetas,
    this.subrecetaExistente,
    this.itemsExistentes,
  });

  final List<Map<String, dynamic>> ingredientes;
  final List<Map<String, dynamic>> subrecetas;
  final Map<String, dynamic>? subrecetaExistente;
  final List<Map<String, dynamic>>? itemsExistentes;

  @override
  State<_DialogoSubrecetaForm> createState() => _DialogoSubrecetaFormState();
}

class _DialogoSubrecetaFormState extends State<_DialogoSubrecetaForm> {
  late final TextEditingController _nombre;
  late final TextEditingController _cantidadRes;
  late final TextEditingController _margenPct;
  late String _unidadRes;
  late List<Map<String, dynamic>> _filas;
  bool _usaProduccionLote = false;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 2,
  );

  bool get _esEdicion => widget.subrecetaExistente != null;

  /// PostgreSQL / JSON suele enviar numeric como String ("1.000").
  static double _leerNumero(dynamic v, [double fallback = 1]) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v}'.replaceAll(',', '.')) ?? fallback;
  }

  @override
  void initState() {
    super.initState();
    final sr = widget.subrecetaExistente;
    _nombre = TextEditingController(text: sr?['nombre'] as String? ?? '');
    _cantidadRes = TextEditingController(
      text: sr != null ? '${sr['cantidad_resultado']}' : '2700',
    );
    _unidadRes = normalizarUnidadCosteo(
      sr?['unidad_resultado'] as String? ?? 'g',
    );
    final margen = sr != null
        ? (num.tryParse('${sr['margen_error']}') ?? 0.05) * 100
        : 5.0;
    _margenPct = TextEditingController(text: margen.toStringAsFixed(1));
    _usaProduccionLote = sr?['usa_produccion_lote'] == true;

    if (widget.itemsExistentes != null && widget.itemsExistentes!.isNotEmpty) {
      _filas = widget.itemsExistentes!.map((e) {
        final tipo = e['tipo_item'] as String? ?? 'ingrediente';
        if (tipo == 'subreceta') {
          return <String, dynamic>{
            'tipo_item': 'subreceta',
            'subreceta_id': e['subreceta_id'] as String?,
            'cantidad': _leerNumero(e['cantidad']),
            'unidad': e['unidad'] as String? ??
                e['subreceta_unidad'] as String? ??
                'g',
          };
        }
        return <String, dynamic>{
          'tipo_item': 'ingrediente',
          'ingrediente_id': e['ingrediente_id'] as String?,
          'nombre_insumo': e['ingrediente_nombre'] as String? ??
              _nombreInsumo(e['ingrediente_id'] as String?),
          'cantidad': _leerNumero(e['cantidad']),
          'unidad': e['unidad'] as String? ?? 'g',
        };
      }).toList();
    } else {
      _filas = [_filaVacia()];
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cantidadRes.dispose();
    _margenPct.dispose();
    super.dispose();
  }

  String? get _idActual => widget.subrecetaExistente?['id'] as String?;

  List<Map<String, dynamic>> get _subrecetasDisponibles =>
      widget.subrecetas.where((s) => s['id'] != _idActual).toList();

  Map<String, dynamic> _filaVacia({String tipo = 'ingrediente'}) {
    if (tipo == 'subreceta' && _subrecetasDisponibles.isNotEmpty) {
      final sr = _subrecetasDisponibles.first;
      return <String, dynamic>{
        'tipo_item': 'subreceta',
        'subreceta_id': sr['id'] as String,
        'cantidad': 1.0,
        'unidad': sr['unidad_resultado'] as String? ?? 'g',
      };
    }
    if (widget.ingredientes.isEmpty) {
      return <String, dynamic>{
        'tipo_item': 'ingrediente',
        'ingrediente_id': null,
        'nombre_insumo': '',
        'cantidad': 1.0,
        'unidad': 'g',
      };
    }
    final ing = widget.ingredientes.first;
    return <String, dynamic>{
      'tipo_item': 'ingrediente',
      'ingrediente_id': ing['id'] as String,
      'nombre_insumo': ing['nombre'] as String? ?? '',
      'cantidad': 1.0,
      'unidad': ing['unidad_base'] as String? ?? 'g',
    };
  }

  Map<String, dynamic>? _subrecetaPorId(String? id) {
    if (id == null) return null;
    for (final sr in widget.subrecetas) {
      if (sr['id'] == id) return sr;
    }
    return null;
  }

  String _nombreInsumo(String? id) {
    if (id == null) return '';
    for (final ing in widget.ingredientes) {
      if (ing['id'] == id) return ing['nombre'] as String? ?? '';
    }
    return '';
  }

  Map<String, dynamic>? _ingredientePorId(String? id) {
    if (id == null) return null;
    for (final ing in widget.ingredientes) {
      if (ing['id'] == id) return ing;
    }
    return null;
  }

  Map<String, dynamic>? _resolverInsumoPorNombre(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final ing in widget.ingredientes) {
      if ((ing['nombre'] as String? ?? '').toLowerCase() == q) return ing;
    }
    for (final ing in widget.ingredientes) {
      if ((ing['nombre'] as String? ?? '').toLowerCase().contains(q)) {
        return ing;
      }
    }
    return null;
  }

  void _vincularInsumo(Map<String, dynamic> fila, Map<String, dynamic> ing) {
    fila['ingrediente_id'] = ing['id'] as String;
    fila['nombre_insumo'] = ing['nombre'] as String? ?? '';
    final base = ing['unidad_base'] as String? ?? 'g';
    final actual = fila['unidad'] as String?;
    if (actual == null || !unidadesCosteoCompatibles(actual, base)) {
      fila['unidad'] = base;
    }
  }

  double _costoLinea(Map<String, dynamic> fila) {
    final cant = (fila['cantidad'] as num?)?.toDouble() ?? 0;
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      if (sr == null) return 0;
      final unit = num.tryParse('${sr['costo_por_unidad']}')?.toDouble() ?? 0;
      final uLinea = fila['unidad'] as String? ?? 'und';
      final uRes = sr['unidad_resultado'] as String? ?? uLinea;
      final cantEfectiva = convertirCantidadCosteo(cant, uLinea, uRes);
      return cantEfectiva * unit;
    }
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    if (ing == null) return 0;
    final costo =
        num.tryParse('${ing['costo_unitario_actual']}')?.toDouble() ?? 0;
    final unidadLinea = fila['unidad'] as String? ?? 'g';
    final unidadBase = ing['unidad_base'] as String? ?? unidadLinea;
    return costoLineaIngredienteUi(
      cantidad: cant,
      unidadLinea: unidadLinea,
      unidadBaseInsumo: unidadBase,
      costoUnitarioBase: costo,
    );
  }

  double get _costoInsumos =>
      _filas.fold(0.0, (sum, f) => sum + _costoLinea(f));

  double get _margenDecimal {
    final pct = double.tryParse(_margenPct.text.replaceAll(',', '.')) ?? 5;
    return pct / 100;
  }

  double get _cantidadResultado =>
      double.tryParse(_cantidadRes.text.replaceAll(',', '.')) ?? 0;

  double get _costoConMargen => _costoInsumos * (1 + _margenDecimal);

  double? get _costoPorUnidad {
    final cant = _cantidadResultado;
    if (cant <= 0) return null;
    return _costoConMargen / cant;
  }

  bool _validar() {
    if (_nombre.text.trim().isEmpty) {
      _snack('Escribe el nombre de la subreceta');
      return false;
    }
    if (_cantidadResultado <= 0) {
      _snack('La cantidad obtenida debe ser mayor a 0');
      return false;
    }
    if (widget.ingredientes.isEmpty && _subrecetasDisponibles.isEmpty) {
      _snack('Crea insumos o subrecetas base primero');
      return false;
    }
    for (final fila in _filas) {
      final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
      if (tipo == 'subreceta') {
        if (fila['subreceta_id'] == null) {
          _snack('Elige una preparación previa en cada línea');
          return false;
        }
        final sr = _subrecetaPorId(fila['subreceta_id'] as String)!;
        final uRes = sr['unidad_resultado'] as String? ?? 'g';
        final uLinea = fila['unidad'] as String? ?? uRes;
        if (!unidadesCosteoCompatibles(uLinea, uRes)) {
          _snack(
            'Unidad «$uLinea» incompatible con la subreceta («$uRes»). '
            'Usa g/kg o ml/L según corresponda.',
          );
          return false;
        }
        fila['unidad'] = normalizarUnidadCosteo(uLinea);
        continue;
      }
      final nombre = (fila['nombre_insumo'] as String? ?? '').trim();
      if (fila['ingrediente_id'] == null && nombre.isNotEmpty) {
        final match = _resolverInsumoPorNombre(nombre);
        if (match != null) _vincularInsumo(fila, match);
      }
      if (fila['ingrediente_id'] == null) {
        _snack(
          nombre.isEmpty
              ? 'Completa todos los insumos de la subreceta'
              : '«$nombre» no existe en la lista de mercado',
        );
        return false;
      }
      final ing = _ingredientePorId(fila['ingrediente_id'] as String)!;
      final uBase = ing['unidad_base'] as String? ?? 'g';
      final uLinea = fila['unidad'] as String? ?? uBase;
      if (!unidadesCosteoCompatibles(uLinea, uBase)) {
        _snack(
          '«${ing['nombre']}» está en $uBase; no puedes usar «$uLinea». '
          'Elige g/kg o ml/L de la misma familia.',
        );
        return false;
      }
      fila['unidad'] = normalizarUnidadCosteo(uLinea);
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _guardar() {
    if (!_validar()) return;
    final items = _filas.map((f) {
      final tipo = f['tipo_item'] as String? ?? 'ingrediente';
      if (tipo == 'subreceta') {
        return <String, dynamic>{
          'tipo_item': 'subreceta',
          'subreceta_id': f['subreceta_id'] as String,
          'cantidad': f['cantidad'] as double,
          'unidad': f['unidad'] as String,
        };
      }
      return <String, dynamic>{
        'tipo_item': 'ingrediente',
        'ingrediente_id': f['ingrediente_id'] as String,
        'cantidad': f['cantidad'] as double,
        'unidad': f['unidad'] as String,
      };
    }).toList();

    Navigator.pop(
      context,
      SubrecetaFormResultado(
        recetaId: widget.subrecetaExistente?['id'] as String?,
        nombre: _nombre.text.trim(),
        cantidadResultado: _cantidadResultado,
        unidadResultado: _unidadRes,
        margenError: _margenDecimal,
        items: items,
        usaProduccionLote: _usaProduccionLote,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costoPorUnidad = _costoPorUnidad;
    final margenTxt = _margenPct.text;

    return FoodyDialogoShell(
      titulo: _esEdicion ? 'Editar subreceta' : 'Nueva subreceta',
      subtitulo: 'Preparación intermedia (salsa, base, arroz…). '
          'El costo sale de tu lista de mercado.',
      contenido: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FoodyFormSeccion(
            titulo: 'Datos del preparado',
            icono: Icons.soup_kitchen_outlined,
            acento: ColoresFoody.primario,
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nombre,
                  decoration: FoodyFormEstilo.campo(
                    label: 'Nombre',
                    hint: 'Ej. Arroz cocido, salsa Maquia',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FoodyFormCamposAdaptativos(
                  breakpoint: 420,
                  campos: [
                    TextField(
                      controller: _cantidadRes,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: FoodyFormEstilo.campo(
                        label: 'Cantidad obtenida',
                        hint: '2700',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _unidadRes,
                      decoration: FoodyFormEstilo.campo(label: 'Unidad'),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'L', child: Text('L')),
                        DropdownMenuItem(value: 'und', child: Text('und')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _unidadRes = v);
                      },
                    ),
                    TextField(
                      controller: _margenPct,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: FoodyFormEstilo.campo(
                        label: 'Margen error',
                        suffix: '%',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Cuándo se mueve el inventario?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _modoStockOpcion(
                  seleccionado: !_usaProduccionLote,
                  titulo: 'Al vender el plato',
                  detalle: 'Recomendado. Al enviar a cocina se descuentan '
                      'los insumos de la lista de mercado (limón, azúcar…). '
                      'No hace falta «preparar» stock aparte.',
                  onTap: () => setState(() => _usaProduccionLote = false),
                ),
                const SizedBox(height: 8),
                _modoStockOpcion(
                  seleccionado: _usaProduccionLote,
                  titulo: 'Preparo un lote y lo guardo',
                  detalle: 'Cocinas de antemano. Registras producción: baja '
                      'insumos y entra stock de «Prep: ${_nombre.text.trim().isEmpty ? '…' : _nombre.text.trim()}». '
                      'Al vender solo baja el preparado.',
                  onTap: () => setState(() => _usaProduccionLote = true),
                ),
                if (_usaProduccionLote) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    child: Text(
                      'Al guardar, el preparado empieza en 0. '
                      'Luego usa «Preparar lote» en la lista de subrecetas '
                      'para cocinar y tener stock. Hasta entonces no es '
                      '«stock bajo» de mercado: es «sin preparar».',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          FoodyFormSeccion(
            titulo: 'Vista previa de costo',
            icono: Icons.insights_outlined,
            acento: ColoresFoody.secundario,
            trailing: FoodyFormBadge(
              texto: 'Estimado',
              color: ColoresFoody.secundario,
            ),
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FoodyFormMetricas(
                  items: [
                    FoodyMetricaItem(
                      etiqueta: 'Insumos',
                      valor: _moneda.format(_costoInsumos),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    FoodyMetricaItem(
                      etiqueta: 'Con margen $margenTxt%',
                      valor: _moneda.format(_costoConMargen),
                      color: ColoresFoody.primario,
                    ),
                    FoodyMetricaItem(
                      etiqueta: 'Por $_unidadRes',
                      valor: costoPorUnidad != null
                          ? _moneda.format(costoPorUnidad)
                          : '—',
                      color: ColoresFoody.secundario,
                    ),
                  ],
                ),
                if (costoPorUnidad == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Indica la cantidad obtenida para ver costo por unidad',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
                if (_cantidadResultado <= 1 &&
                    _costoInsumos > 100 &&
                    _filas.length >= 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    '¿Es un lote grande? Pon cuántas $_unidadRes salen '
                    '(ej. 2700), no 1.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          FoodyFormSeccion(
            titulo: 'Insumos de la subreceta',
            subtitulo: '${_filas.length} línea${_filas.length == 1 ? '' : 's'}',
            icono: Icons.playlist_add_check_outlined,
            acento: ColoresFoody.primario,
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _filas.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _filaEditor(i),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _filas.add(_filaVacia())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir línea'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresFoody.primario,
                    side: BorderSide(
                      color: ColoresFoody.primario.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      acciones: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          style: FilledButton.styleFrom(
            backgroundColor: ColoresFoody.primario,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(_esEdicion ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  Widget _modoStockOpcion({
    required bool seleccionado,
    required String titulo,
    required String detalle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: seleccionado
          ? ColoresFoody.secundario.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado
                  ? ColoresFoody.secundario
                  : Theme.of(context).colorScheme.outlineVariant,
              width: seleccionado ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                seleccionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 22,
                color: seleccionado
                    ? ColoresFoody.secundario
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detalle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaEditor(int i) {
    final fila = _filas[i];
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    final valor = _costoLinea(fila);
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    final costoCero = tipo == 'ingrediente' &&
        ing != null &&
        (num.tryParse('${ing['costo_unitario_actual']}') ?? 0) == 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: costoCero
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ColoresFoody.primario.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ColoresFoody.primario,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: tipo,
                  decoration: FoodyFormEstilo.campo(label: 'Tipo'),
                  items: [
                    const DropdownMenuItem(
                      value: 'ingrediente',
                      child: Text('Insumo'),
                    ),
                    if (_subrecetasDisponibles.isNotEmpty)
                      const DropdownMenuItem(
                        value: 'subreceta',
                        child: Text('Otra subreceta'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _filas[i] = _filaVacia(tipo: v));
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                tooltip: 'Quitar',
                onPressed: _filas.length > 1
                    ? () => setState(() => _filas.removeAt(i))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tipo == 'subreceta')
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: fila['subreceta_id'] as String?,
              decoration: FoodyFormEstilo.campo(label: 'Preparación previa'),
              items: _subrecetasDisponibles
                  .map(
                    (sr) => DropdownMenuItem(
                      value: sr['id'] as String,
                      child: Text(
                        sr['nombre'] as String? ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                final sr = _subrecetaPorId(v)!;
                setState(() {
                  fila['subreceta_id'] = v;
                  final uRes = sr['unidad_resultado'] as String? ?? 'g';
                  final actual = fila['unidad'] as String?;
                  if (actual == null ||
                      !unidadesCosteoCompatibles(actual, uRes)) {
                    fila['unidad'] = uRes;
                  }
                });
              },
            )
          else
            Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: fila['nombre_insumo'] as String? ?? '',
              ),
              displayStringForOption: (o) => o['nombre'] as String? ?? '',
              optionsBuilder: (text) {
                final q = text.text.trim().toLowerCase();
                if (q.isEmpty) return widget.ingredientes;
                return widget.ingredientes.where(
                  (ing) => (ing['nombre'] as String? ?? '')
                      .toLowerCase()
                      .contains(q),
                );
              },
              onSelected: (ing) {
                setState(() => _vincularInsumo(fila, ing));
              },
              fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  decoration: FoodyFormEstilo.campo(
                    label: 'Insumo',
                    suffixIcon: costoCero
                        ? const Icon(
                            Icons.warning_amber,
                            color: Colors.orange,
                            size: 18,
                          )
                        : null,
                  ),
                  onChanged: (v) {
                    fila['nombre_insumo'] = v;
                    fila['ingrediente_id'] = null;
                    setState(() {});
                  },
                );
              },
            ),
          const SizedBox(height: 10),
          FoodyFormCamposAdaptativos(
            breakpoint: 280,
            campos: [
              TextFormField(
                initialValue: '${fila['cantidad']}',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: FoodyFormEstilo.campo(
                  label: 'Cantidad',
                ),
                onChanged: (v) {
                  fila['cantidad'] =
                      double.tryParse(v.replaceAll(',', '.')) ?? 1;
                  setState(() {});
                },
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey(
                  'u-$i-${fila['ingrediente_id']}-${fila['subreceta_id']}',
                ),
                initialValue: _unidadLineaValida(fila),
                decoration: FoodyFormEstilo.campo(label: 'Unidad'),
                items: _opcionesUnidadLinea(fila)
                    .map(
                      (u) => DropdownMenuItem(value: u, child: Text(u)),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => fila['unidad'] = v);
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _moneda.format(valor),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: costoCero
                              ? Theme.of(context).colorScheme.tertiary
                              : ColoresFoody.primario,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (costoCero)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Sin costo en mercado — revisa Lista de mercado',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _opcionesUnidadLinea(Map<String, dynamic> fila) {
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      final base = sr?['unidad_resultado'] as String? ?? 'g';
      return unidadesDeFamiliaCosteo(base);
    }
    final ing = _ingredientePorId(fila['ingrediente_id'] as String?);
    final base =
        ing?['unidad_base'] as String? ?? (fila['unidad'] as String? ?? 'g');
    return unidadesDeFamiliaCosteo(base);
  }

  String _unidadLineaValida(Map<String, dynamic> fila) {
    final opciones = _opcionesUnidadLinea(fila);
    final actual = normalizarUnidadCosteo(fila['unidad'] as String? ?? '');
    if (opciones.contains(actual)) return actual;
    return opciones.first;
  }
}
