import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Resultado del diálogo crear/editar insumo (modo mercado o solo costo).
class InsumoFormResultado {
  const InsumoFormResultado({
    required this.nombre,
    this.proveedor,
    this.unidadBase = 'g',
    this.categoriaInsumo = 'alimento',
    this.esSoloCosto = false,
    this.precioCompra,
    this.pesoBruto,
    this.pesoNeto,
    this.costoUnitario,
    this.stockMinimo = 0,
    this.stockActual = 0,
    this.descontarStock = true,
  });

  final String nombre;
  final String? proveedor;
  final String unidadBase;
  final String categoriaInsumo;
  final bool esSoloCosto;
  final double? precioCompra;
  final double? pesoBruto;
  final double? pesoNeto;
  final double? costoUnitario;
  final double stockMinimo;
  final double stockActual;
  final bool descontarStock;
}

/// Vista previa local (solo UI); el backend confirma el costo real.
class _PreviewMercado {
  static double? costoReal(double? precio, double? neto) {
    if (precio == null || neto == null || neto <= 0) return null;
    return precio / neto;
  }

  static double? factor(double? bruto, double? neto) {
    if (bruto == null || neto == null || neto <= 0) return null;
    return bruto / neto;
  }
}

/// Diálogo reutilizable — lista de mercado KYG.
Future<InsumoFormResultado?> mostrarDialogoInsumo({
  required BuildContext context,
  Map<String, dynamic>? insumoExistente,
}) {
  return showDialog<InsumoFormResultado>(
    context: context,
    builder: (ctx) => _DialogoInsumoForm(insumoExistente: insumoExistente),
  );
}

class _DialogoInsumoForm extends StatefulWidget {
  const _DialogoInsumoForm({this.insumoExistente});

  final Map<String, dynamic>? insumoExistente;

  @override
  State<_DialogoInsumoForm> createState() => _DialogoInsumoFormState();
}

class _DialogoInsumoFormState extends State<_DialogoInsumoForm> {
  late final TextEditingController _nombre;
  late final TextEditingController _proveedor;
  late final TextEditingController _precioCompra;
  late final TextEditingController _pesoBruto;
  late final TextEditingController _pesoNeto;
  late final TextEditingController _stockMin;
  late final TextEditingController _stockAct;
  late final TextEditingController _costoSolo;

  late bool _esSoloCosto;
  late String _unidad;
  late String _categoria;

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 2,
  );

  bool get _editando => widget.insumoExistente != null;

  static const _categoriasMercado = {
    'alimento',
    'empaque',
    'mano_obra',
    'servicio',
  };
  static const _categoriasSoloCosto = {'mano_obra', 'servicio', 'empaque'};
  static const _unidadesValidas = {'g', 'kg', 'ml', 'L', 'und'};

  String _normalizarUnidad(String? u) {
    if (u == null || u == 'servicio') return 'g';
    final lower = u.toLowerCase();
    if (lower == 'l') return 'L';
    if (_unidadesValidas.contains(u)) return u;
    if (_unidadesValidas.contains(lower)) {
      return lower == 'l' ? 'L' : lower;
    }
    return 'g';
  }

  String _normalizarCategoria(String cat, bool esSoloCosto) {
    if (esSoloCosto) {
      if (_categoriasSoloCosto.contains(cat)) return cat;
      return 'empaque';
    }
    if (_categoriasMercado.contains(cat)) return cat;
    return 'alimento';
  }

  bool _inferirSoloCosto(Map<String, dynamic>? ing) {
    if (ing == null) return false;
    final cat = ing['categoria_insumo'] as String? ?? 'alimento';
    final unidad = ing['unidad_base'] as String? ?? 'g';
    return cat == 'mano_obra' ||
        cat == 'servicio' ||
        unidad == 'servicio' ||
        ing['descontar_stock'] == false;
  }

  @override
  void initState() {
    super.initState();
    final ing = widget.insumoExistente;
    final unidad = ing?['unidad_base'] as String? ?? 'g';
    final catRaw = ing?['categoria_insumo'] as String? ?? 'alimento';

    _esSoloCosto = _inferirSoloCosto(ing);
    _unidad = _normalizarUnidad(unidad);
    _categoria = _normalizarCategoria(catRaw, _esSoloCosto);

    _nombre = TextEditingController(text: ing?['nombre'] as String? ?? '');
    _proveedor = TextEditingController(text: ing?['proveedor'] as String? ?? '');
    _precioCompra = TextEditingController(
      text: ing?['precio_compra'] != null ? '${ing!['precio_compra']}' : '',
    );
    _pesoBruto = TextEditingController(
      text: ing?['peso_bruto'] != null ? '${ing!['peso_bruto']}' : '',
    );
    _pesoNeto = TextEditingController(
      text: ing?['peso_neto'] != null ? '${ing!['peso_neto']}' : '',
    );
    _stockMin = TextEditingController(
      text: ing?['stock_minimo'] != null ? '${ing!['stock_minimo']}' : '0',
    );
    _stockAct = TextEditingController(
      text: ing?['stock_actual'] != null ? '${ing!['stock_actual']}' : '0',
    );
    _costoSolo = TextEditingController(
      text: ing?['costo_unitario_actual'] != null
          ? '${ing!['costo_unitario_actual']}'
          : '0',
    );
  }

  @override
  void dispose() {
    _nombre.dispose();
    _proveedor.dispose();
    _precioCompra.dispose();
    _pesoBruto.dispose();
    _pesoNeto.dispose();
    _stockMin.dispose();
    _stockAct.dispose();
    _costoSolo.dispose();
    super.dispose();
  }

  double? _parse(String t) => double.tryParse(t.replaceAll(',', '.').trim());

  void _guardar() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;

    if (_esSoloCosto) {
      Navigator.pop(
        context,
        InsumoFormResultado(
          nombre: nombre,
          proveedor: _proveedor.text.trim().isEmpty ? null : _proveedor.text.trim(),
          unidadBase: _categoria == 'mano_obra' ? 'servicio' : 'und',
          categoriaInsumo: _categoria,
          esSoloCosto: true,
          costoUnitario: _parse(_costoSolo.text) ?? 0,
          descontarStock: _categoria != 'mano_obra' && _categoria != 'servicio',
        ),
      );
      return;
    }

    final precio = _parse(_precioCompra.text);
    final bruto = _parse(_pesoBruto.text);
    final neto = _parse(_pesoNeto.text);
    if (precio == null || bruto == null || neto == null || neto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa precio de compra y pesos')),
      );
      return;
    }

    Navigator.pop(
      context,
      InsumoFormResultado(
        nombre: nombre,
        proveedor: _proveedor.text.trim().isEmpty ? null : _proveedor.text.trim(),
        unidadBase: _unidad,
        categoriaInsumo: _categoria,
        precioCompra: precio,
        pesoBruto: bruto,
        pesoNeto: neto,
        stockMinimo: _parse(_stockMin.text) ?? 0,
        stockActual: _parse(_stockAct.text) ?? 0,
        descontarStock: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final precio = _parse(_precioCompra.text);
    final bruto = _parse(_pesoBruto.text);
    final neto = _parse(_pesoNeto.text);
    final costoReal = _PreviewMercado.costoReal(precio, neto);
    final factor = _PreviewMercado.factor(bruto, neto);

    return AlertDialog(
      title: Text(_editando ? 'Editar insumo' : 'Nuevo insumo — mercado'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre del insumo',
                  hintText: 'Cebolla blanca, carne, bolsa…',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _proveedor,
                decoration: const InputDecoration(
                  labelText: 'Proveedor (opcional)',
                  hintText: 'Mercado, Makro, Éxito…',
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Compra mercado'),
                    icon: Icon(Icons.storefront_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Solo costo'),
                    icon: Icon(Icons.payments_outlined, size: 16),
                  ),
                ],
                selected: {_esSoloCosto},
                onSelectionChanged: (s) {
                  final solo = s.first;
                  setState(() {
                    _esSoloCosto = solo;
                    _categoria = _normalizarCategoria(_categoria, solo);
                  });
                },
              ),
              const SizedBox(height: 8),
              if (!_esSoloCosto) ...[
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(value: 'alimento', child: Text('Alimento')),
                    DropdownMenuItem(value: 'empaque', child: Text('Empaque')),
                    DropdownMenuItem(value: 'mano_obra', child: Text('Mano de obra')),
                    DropdownMenuItem(value: 'servicio', child: Text('Servicio / gas fijo')),
                  ],
                  onChanged: (v) => setState(() => _categoria = v ?? _categoria),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _precioCompra,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio de compra (COP)',
                    hintText: 'Lo que pagaste por el bulto/bolsa',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pesoBruto,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Peso bruto',
                          hintText: 'Total comprado',
                          suffixText: _unidad,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pesoNeto,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Peso neto (aprovechable)',
                          suffixText: _unidad,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  initialValue: _unidad,
                  decoration: const InputDecoration(labelText: 'Unidad de medida'),
                  items: const [
                    DropdownMenuItem(value: 'g', child: Text('Gramo (g)')),
                    DropdownMenuItem(value: 'kg', child: Text('Kilogramo (kg)')),
                    DropdownMenuItem(value: 'ml', child: Text('Mililitro (ml)')),
                    DropdownMenuItem(value: 'L', child: Text('Litro (L)')),
                    DropdownMenuItem(value: 'und', child: Text('Unidad (und)')),
                  ],
                  onChanged: (v) => setState(() => _unidad = v ?? _unidad),
                ),
                if (costoReal != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: ColoresFoody.secundario.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vista previa (el backend confirma al guardar)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Costo real: ${_moneda.format(costoReal)}/$_unidad',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (factor != null && (factor - 1).abs() > 0.01)
                            Text(
                              'Factor corrección (merma): ×${factor.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stockAct,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Stock actual',
                          suffixText: _unidad,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _stockMin,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Stock mínimo',
                          suffixText: _unidad,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _categoria,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(value: 'mano_obra', child: Text('Mano de obra')),
                    DropdownMenuItem(value: 'servicio', child: Text('Servicio / gas fijo')),
                    DropdownMenuItem(value: 'empaque', child: Text('Empaque (solo costo)')),
                  ],
                  onChanged: (v) => setState(() => _categoria = v ?? _categoria),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _costoSolo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Costo por plato / unidad (COP)',
                    helperText: 'No descuenta inventario al vender',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
