import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
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
  });

  final String? recetaId;
  final String nombre;
  final double cantidadResultado;
  final String unidadResultado;
  final double margenError;
  final List<Map<String, dynamic>> items;
}

Future<SubrecetaFormResultado?> mostrarDialogoSubreceta({
  required BuildContext context,
  required List<Map<String, dynamic>> ingredientes,
  required List<Map<String, dynamic>> subrecetas,
  Map<String, dynamic>? subrecetaExistente,
  List<Map<String, dynamic>>? itemsExistentes,
}) {
  return showDialog<SubrecetaFormResultado>(
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
    _unidadRes = sr?['unidad_resultado'] as String? ?? 'g';
    final margen = sr != null
        ? (num.tryParse('${sr['margen_error']}') ?? 0.05) * 100
        : 5.0;
    _margenPct = TextEditingController(text: margen.toStringAsFixed(1));

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
    fila['unidad'] = ing['unidad_base'] as String? ?? 'g';
  }

  double _costoLinea(Map<String, dynamic> fila) {
    final cant = (fila['cantidad'] as num?)?.toDouble() ?? 0;
    final tipo = fila['tipo_item'] as String? ?? 'ingrediente';
    if (tipo == 'subreceta') {
      final sr = _subrecetaPorId(fila['subreceta_id'] as String?);
      if (sr == null) return 0;
      final unit =
          num.tryParse('${sr['costo_por_unidad']}')?.toDouble() ?? 0;
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
    final pct =
        double.tryParse(_margenPct.text.replaceAll(',', '.')) ?? 5;
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
        fila['unidad'] = sr['unidad_resultado'] as String? ?? 'g';
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
      fila['unidad'] = ing['unidad_base'] as String? ?? 'g';
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final costoPorUnidad = _costoPorUnidad;

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar subreceta' : 'Nueva subreceta'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Preparación intermedia (salsa, base, marinado). '
                'El costo de cada insumo viene de «Lista de mercado».',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Salsa Maquia',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _cantidadRes,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad obtenida',
                        hintText: '2700',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unidadRes,
                      decoration: const InputDecoration(labelText: 'Unidad'),
                      items: const [
                        DropdownMenuItem(value: 'g', child: Text('g')),
                        DropdownMenuItem(value: 'ml', child: Text('ml')),
                        DropdownMenuItem(value: 'kg', child: Text('kg')),
                        DropdownMenuItem(value: 'l', child: Text('l')),
                        DropdownMenuItem(value: 'und', child: Text('und')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _unidadRes = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _margenPct,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Margen error %',
                        suffixText: '%',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColoresFoody.primario.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ColoresFoody.primario.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vista previa (estimada)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ColoresFoody.primario,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Costo insumos: ${_moneda.format(_costoInsumos)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'Con margen ${_margenPct.text}%: ${_moneda.format(_costoConMargen)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (costoPorUnidad != null)
                      Text(
                        'Costo por $_unidadRes: ${_moneda.format(costoPorUnidad)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else
                      const Text(
                        'Indica cantidad obtenida para ver costo/unidad',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    if (_cantidadResultado <= 1 &&
                        _costoInsumos > 100 &&
                        _filas.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '¿Estas cantidades son de un lote grande? '
                          'Pon en «Cantidad obtenida» cuántas $_unidadRes '
                          'salen de ese lote (ej. 20), no 1.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Insumos de la subreceta',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (var i = 0; i < _filas.length; i++) ...[
                const SizedBox(height: 8),
                _filaEditor(i),
              ],
              TextButton.icon(
                onPressed: () => setState(() => _filas.add(_filaVacia())),
                icon: const Icon(Icons.add),
                label: const Text('Añadir línea'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardar,
          child: Text(_esEdicion ? 'Guardar' : 'Crear'),
        ),
      ],
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Qué es',
                      isDense: true,
                    ),
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
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _filas.length > 1
                      ? () => setState(() => _filas.removeAt(i))
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (tipo == 'subreceta')
              DropdownButtonFormField<String>(
                initialValue: fila['subreceta_id'] as String?,
                decoration: const InputDecoration(
                  labelText: 'Preparación previa',
                  isDense: true,
                ),
                items: _subrecetasDisponibles
                    .map(
                      (sr) => DropdownMenuItem(
                        value: sr['id'] as String,
                        child: Text(sr['nombre'] as String? ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final sr = _subrecetaPorId(v)!;
                  setState(() {
                    fila['subreceta_id'] = v;
                    fila['unidad'] = sr['unidad_resultado'] as String? ?? 'g';
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
                    decoration: InputDecoration(
                      labelText: 'Insumo',
                      isDense: true,
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
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '${fila['cantidad']}',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      suffixText: fila['unidad'] as String? ?? 'g',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      fila['cantidad'] =
                          double.tryParse(v.replaceAll(',', '.')) ?? 1;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _moneda.format(valor),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: costoCero ? Colors.orange : null,
                  ),
                ),
              ],
            ),
            if (costoCero)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Insumo sin costo en mercado — revisa «Lista de mercado»',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
