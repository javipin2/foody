import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/auth/roles_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/saas_ui/saas_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/tema/foody_formulario.dart';
import 'package:reserva_canchas/core/widgets/foody_scroll_horizontal_fade.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/inventario/data/costeo_repository.dart';
import 'package:reserva_canchas/features/inventario/data/inventario_repository.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_insumo_form.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/dialogo_subreceta_form.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/inventario_hermanas_panel.dart';
import 'package:reserva_canchas/features/inventario/presentation/inventario_traslados_panel.dart';
import 'package:reserva_canchas/features/inventario/presentation/widgets/stock_visual_widgets.dart';

/// Insumos admin — ingredientes, compras, movimientos y subrecetas.
class InventarioAdminScreen extends StatefulWidget {
  const InventarioAdminScreen({
    super.key,
    this.sucursalId,
    this.onIrCostos,
    this.filtroInicial,
    this.destacarIngredienteId,
  });

  final String? sucursalId;

  /// NAV-MC-10: atajo cadena inversa → Costos y márgenes.
  final VoidCallback? onIrCostos;

  /// NAV-MC-15: deep-link desde alertas (ej. `bajo_stock`).
  final String? filtroInicial;

  /// NAV-ADM2-04: resaltar insumo concreto.
  final String? destacarIngredienteId;

  @override
  State<InventarioAdminScreen> createState() => _InventarioAdminScreenState();
}

class _InventarioAdminScreenState extends State<InventarioAdminScreen>
    with SingleTickerProviderStateMixin {
  final _repo = InventarioRepository();
  final _costeoRepo = CosteoRepository();
  late final TabController _tabs;

  List<Map<String, dynamic>> _ingredientes = [];
  List<Map<String, dynamic>> _movimientos = [];
  bool _hayMasMovimientos = false;
  int _pageMovimientos = 1;
  bool _cargandoMasMovimientos = false;
  List<Map<String, dynamic>> _subrecetas = [];
  bool _cargando = true;
  String? _error;
  final _busquedaCtrl = TextEditingController();
  String _filtroInsumos = 'todos';
  bool _puedeVerHermanas = false;
  List<Map<String, dynamic>> _sucursalesHermanas = [];

  final _moneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    if (widget.filtroInicial != null && widget.filtroInicial!.isNotEmpty) {
      _filtroInsumos = widget.filtroInicial!;
    }
    _cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final sid = widget.sucursalId;
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
      final sesion = await SesionStaffService.cargar();
      final permisos = sesion?.permisos ?? [];
      final puedeHermanas =
          permisos.contains('ver_inventario_otras_sucursales') ||
              esCorporativoStaff(rol: sesion?.rol, permisos: permisos);
      final results = await Future.wait([
        _repo.ingredientes(sid),
        _repo.movimientosPaginados(sid, page: 1, limit: 50),
        _costeoRepo.subrecetas(sid),
        if (puedeHermanas)
          _repo.resumenHermanas()
        else
          Future.value(<String, dynamic>{}),
      ]);
      if (!mounted) return;
      List<Map<String, dynamic>> hermanas = [];
      if (puedeHermanas && results.length > 3) {
        final resumen = results[3] as Map<String, dynamic>;
        hermanas = (resumen['sucursales'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      final movPage = results[1] as ({
        List<Map<String, dynamic>> items,
        int total,
        bool hayMas,
      });
      setState(() {
        _ingredientes = List<Map<String, dynamic>>.from(results[0] as List);
        _movimientos = movPage.items;
        _hayMasMovimientos = movPage.hayMas;
        _pageMovimientos = 1;
        _subrecetas = List<Map<String, dynamic>>.from(results[2] as List);
        _puedeVerHermanas = puedeHermanas;
        _sucursalesHermanas = hermanas;
        _cargando = false;
      });
      final dest = widget.destacarIngredienteId;
      if (dest != null && dest.isNotEmpty) {
        for (final ing in _ingredientes) {
          if ('${ing['id']}' == dest) {
            final nombre = ing['nombre'] as String? ?? '';
            if (nombre.isNotEmpty) {
              _busquedaCtrl.text = nombre;
              _tabs.index = 0;
            }
            break;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e, contexto: 'cargar insumos');
        _cargando = false;
      });
    }
  }

  void _mostrarInventarioHermanas() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.88,
        child: InventarioHermanasPanel(
          // NAV-MG-06: desde hermanas → tab Traslados.
          onIrTraslados: () {
            Navigator.pop(ctx);
            setState(() => _tabs.index = 4);
          },
        ),
      ),
    );
  }

  Future<void> _dialogoCrearIngrediente() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final res = await mostrarDialogoInsumo(context: context);
    if (res == null || !mounted) return;
    await _guardarInsumo(sid, res);
  }

  Future<void> _dialogoEditarIngrediente(Map<String, dynamic> ing) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final res = await mostrarDialogoInsumo(
      context: context,
      insumoExistente: ing,
    );
    if (res == null || !mounted) return;
    try {
      if (res.esSoloCosto) {
        await _repo.actualizarIngrediente(
          ingredienteId: ing['id'] as String,
          nombre: res.nombre,
          proveedor: res.proveedor,
          categoriaInsumo: res.categoriaInsumo,
          unidadBase: res.unidadBase,
          costoUnitario: res.costoUnitario,
          descontarStock: res.descontarStock,
        );
      } else {
        await _repo.actualizarIngrediente(
          ingredienteId: ing['id'] as String,
          nombre: res.nombre,
          proveedor: res.proveedor,
          categoriaInsumo: res.categoriaInsumo,
          unidadBase: res.unidadBase,
          precioCompra: res.precioCompra,
          pesoBruto: res.pesoBruto,
          pesoNeto: res.pesoNeto,
          stockMinimo: res.stockMinimo,
        );
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insumo actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    }
  }

  Future<void> _guardarInsumo(String sid, InsumoFormResultado res) async {
    try {
      if (res.esSoloCosto) {
        await _repo.crearIngrediente(
          sucursalId: sid,
          nombre: res.nombre,
          proveedor: res.proveedor,
          unidadBase: res.unidadBase,
          categoriaInsumo: res.categoriaInsumo,
          costoUnitario: res.costoUnitario,
          descontarStock: res.descontarStock,
        );
      } else {
        await _repo.crearIngrediente(
          sucursalId: sid,
          nombre: res.nombre,
          proveedor: res.proveedor,
          unidadBase: res.unidadBase,
          categoriaInsumo: res.categoriaInsumo,
          precioCompra: res.precioCompra,
          pesoBruto: res.pesoBruto,
          pesoNeto: res.pesoNeto,
          stockMinimo: res.stockMinimo,
          stockActual: res.stockActual,
        );
      }
      await _cargar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Insumo creado'),
            action: widget.onIrCostos == null
                ? null
                : SnackBarAction(
                    label: 'Armar receta',
                    onPressed: widget.onIrCostos!,
                  ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    }
  }

  Future<void> _dialogoCompra(Map<String, dynamic> ing) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final cantidad = TextEditingController();
    final precio = TextEditingController();
    final proveedor = TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FoodyDialogoShell(
          titulo: 'Registrar compra',
          subtitulo: ing['nombre'] as String? ?? '',
          maxWidth: 420,
          contenido: FoodyFormSeccion(
            titulo: 'Detalle de la compra',
            icono: Icons.shopping_cart_outlined,
            hijo: Column(
              children: [
                TextField(
                  controller: cantidad,
                  keyboardType: TextInputType.number,
                  decoration: FoodyFormEstilo.campo(
                    label: 'Cantidad (unidades base)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: precio,
                  keyboardType: TextInputType.number,
                  decoration:
                      FoodyFormEstilo.campo(label: 'Precio total compra'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proveedor,
                  decoration: FoodyFormEstilo.campo(
                    label: 'Proveedor (opcional)',
                  ),
                ),
              ],
            ),
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Registrar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      try {
        await _repo.registrarCompra(
          sucursalId: sid,
          ingredienteId: ing['id'] as String,
          cantidad: double.parse(cantidad.text),
          precioTotal: double.parse(precio.text),
          proveedor:
              proveedor.text.trim().isEmpty ? null : proveedor.text.trim(),
        );
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Compra registrada')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e))),
          );
        }
      }
    } finally {
      cantidad.dispose();
      precio.dispose();
      proveedor.dispose();
    }
  }

  Future<void> _dialogoSubreceta({Map<String, dynamic>? existente}) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    if (_ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Carga insumos en «Lista de mercado» antes de crear subrecetas',
          ),
        ),
      );
      return;
    }

    List<Map<String, dynamic>>? itemsExistentes;
    if (existente != null) {
      try {
        final detalle = await _costeoRepo.obtenerSubrecetaDetalle(
          recetaId: existente['id'] as String,
          sucursalId: sid,
        );
        itemsExistentes = List<Map<String, dynamic>>.from(
          (detalle['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        existente = Map<String, dynamic>.from(detalle);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo cargar la subreceta: $e')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final res = await mostrarDialogoSubreceta(
      context: context,
      ingredientes: _ingredientes,
      subrecetas: _subrecetas,
      subrecetaExistente: existente,
      itemsExistentes: itemsExistentes,
    );
    if (res == null || !mounted) return;

    try {
      String? idGuardada = res.recetaId;
      if (res.recetaId != null) {
        await _costeoRepo.actualizarSubreceta(
          recetaId: res.recetaId!,
          sucursalId: sid,
          nombre: res.nombre,
          cantidadResultado: res.cantidadResultado,
          unidadResultado: res.unidadResultado,
          margenError: res.margenError,
          items: res.items,
          usaProduccionLote: res.usaProduccionLote,
        );
      } else {
        final creado = await _costeoRepo.crearSubreceta(
          sucursalId: sid,
          nombre: res.nombre,
          cantidadResultado: res.cantidadResultado,
          unidadResultado: res.unidadResultado,
          margenError: res.margenError,
          items: res.items,
          usaProduccionLote: res.usaProduccionLote,
        );
        idGuardada = creado['receta_id'] as String? ?? creado['id'] as String?;
      }
      await _cargar();
      if (!mounted) return;

      if (res.usaProduccionLote && idGuardada != null) {
        Map<String, dynamic>? sr;
        for (final s in _subrecetas) {
          if (s['id'] == idGuardada) {
            sr = s;
            break;
          }
        }
        sr ??= {
          'id': idGuardada,
          'nombre': res.nombre,
          'cantidad_resultado': res.cantidadResultado,
          'unidad_resultado': res.unidadResultado,
          'usa_produccion_lote': true,
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Modo lote activo. El preparado está en 0 hasta que lo cocines.',
            ),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Preparar lote',
              onPressed: () => _dialogoProduccionLote(sr!),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.recetaId != null
                  ? 'Subreceta actualizada · stock se mueve al vender'
                  : 'Subreceta creada · stock se mueve al vender',
            ),
            action: res.recetaId == null && widget.onIrCostos != null
                ? SnackBarAction(
                    label: 'Armar receta',
                    onPressed: widget.onIrCostos!,
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e))),
        );
      }
    }
  }

  Future<void> _dialogoAjuste(Map<String, dynamic> ing) async {
    final stockCtrl = TextEditingController(
      text: '${ing['stock_actual']}',
    );
    final motivo = TextEditingController(text: 'Conteo físico');

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FoodyDialogoShell(
          titulo: 'Ajustar stock',
          subtitulo: ing['nombre'] as String? ?? '',
          maxWidth: 400,
          contenido: FoodyFormSeccion(
            titulo: 'Conteo / ajuste',
            icono: Icons.tune,
            hijo: Column(
              children: [
                TextField(
                  controller: stockCtrl,
                  keyboardType: TextInputType.number,
                  decoration: FoodyFormEstilo.campo(label: 'Stock nuevo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: motivo,
                  decoration: FoodyFormEstilo.campo(label: 'Motivo'),
                ),
              ],
            ),
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      try {
        await _repo.ajustarStock(
          ingredienteId: ing['id'] as String,
          stockNuevo: double.parse(stockCtrl.text),
          motivo: motivo.text.trim(),
        );
        await _cargar();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e))),
          );
        }
      }
    } finally {
      stockCtrl.dispose();
      motivo.dispose();
    }
  }

  Future<void> _dialogoProduccionLote(Map<String, dynamic> subreceta) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    if (subreceta['usa_produccion_lote'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Activa «Preparo un lote y lo guardo» al editar la subreceta',
          ),
        ),
      );
      return;
    }

    final unidad = subreceta['unidad_resultado'] as String? ?? 'g';
    final cantidadRes = num.tryParse('${subreceta['cantidad_resultado']}') ?? 1;
    final ctrl = TextEditingController(text: '$cantidadRes');
    final obs = TextEditingController();

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FoodyDialogoShell(
          titulo: 'Preparar lote',
          subtitulo: subreceta['nombre'] as String? ?? '',
          maxWidth: 420,
          contenido: FoodyFormSeccion(
            titulo: 'Qué pasa al registrar',
            icono: Icons.inventory_2_outlined,
            acento: AnaliticaTokens.inventario,
            hijo: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '1) Baja de la lista de mercado los insumos de la receta.\n'
                  '2) Suma stock a «Prep: ${subreceta['nombre']}».\n'
                  '3) Al vender platos que usan esta subreceta, solo baja el preparado.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Receta base: $cantidadRes $unidad '
                  '(puedes producir más o menos; se escala el consumo).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: FoodyFormEstilo.campo(
                    label: 'Cantidad producida ahora',
                    suffix: unidad,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obs,
                  decoration: FoodyFormEstilo.campo(
                    label: 'Observaciones (opcional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Preparar'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      final cantidad = double.tryParse(ctrl.text.replaceAll(',', '.'));
      if (cantidad == null || cantidad <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cantidad inválida')),
        );
        return;
      }

      try {
        final res = await _costeoRepo.registrarProduccionLote(
          sucursalId: sid,
          recetaId: subreceta['id'] as String,
          cantidadProducida: cantidad,
          observaciones: obs.text.trim(),
        );
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Lote listo · stock Prep +$cantidad $unidad · '
                'costo ${_moneda.format(num.tryParse('${res['costo_unitario']}') ?? 0)}/$unidad',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(mensajeErrorHttp(e))),
          );
        }
      }
    } finally {
      ctrl.dispose();
      obs.dispose();
    }
  }

  Future<void> _recalcularSubreceta(Map<String, dynamic> subreceta) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final res = await _costeoRepo.recalcularSubreceta(
        recetaId: subreceta['id'] as String,
        sucursalId: sid,
      );
      await _cargar();
      if (!mounted) return;
      final costo = num.tryParse('${res['costo_por_unidad']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            costo != null
                ? 'Costo actualizado: ${_moneda.format(costo)}/unidad'
                : 'Subreceta recalculada',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(mensajeErrorHttp(e, contexto: 'recalcular subreceta'))),
      );
    }
  }

  Future<void> _mostrarHistorialProducciones({String? recetaId}) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final lista =
          await _costeoRepo.listarProducciones(sid, recetaId: recetaId);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, scroll) {
            if (lista.isEmpty) {
              return const Center(child: Text('Sin producciones registradas'));
            }
            return ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: lista.length,
              itemBuilder: (_, i) {
                final p = lista[i];
                final cant = num.tryParse('${p['cantidad_producida']}');
                final fecha = p['creado_en'] as String? ?? '';
                return ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(p['receta_nombre'] as String? ?? 'Subreceta'),
                  subtitle: Text(
                    '${cant ?? '—'} ${p['unidad_resultado'] ?? ''}'
                    '${fecha.isNotEmpty ? ' · $fecha' : ''}',
                  ),
                  trailing: Text(
                    _moneda.format(
                      num.tryParse('${p['costo_total']}') ?? 0,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              },
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(mensajeErrorHttp(e, contexto: 'historial producción'))),
      );
    }
  }

  Widget _resumenInventario(bool compacto) {
    final controlStock =
        _ingredientes.where((i) => i['descontar_stock'] != false).length;
    final soloCosto =
        _ingredientes.where((i) => i['descontar_stock'] == false).length;
    final items = <(String, String, IconData, Color)>[
      (
        'Insumos',
        '${_ingredientes.length}',
        Icons.inventory_2_outlined,
        AnaliticaTokens.pedidos
      ),
      (
        'Control de stock',
        '$controlStock',
        Icons.inventory_outlined,
        AnaliticaTokens.inventario
      ),
      (
        'Solo costo',
        '$soloCosto',
        Icons.payments_outlined,
        AnaliticaTokens.inkMuted
      ),
    ];
    return Padding(
      padding:
          EdgeInsets.fromLTRB(compacto ? 12 : 28, 0, compacto ? 12 : 28, 12),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: compacto ? 10 : 16,
                    vertical: compacto ? 10 : 12),
                decoration: BoxDecoration(
                  color: AnaliticaTokens.surfaceOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AnaliticaTokens.borderOf(context)),
                ),
                child: Row(
                  children: [
                    Icon(items[index].$3,
                        color: items[index].$4, size: compacto ? 17 : 19),
                    SizedBox(width: compacto ? 7 : 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(items[index].$2,
                              style: TextStyle(
                                  color: AnaliticaTokens.inkOf(context),
                                  fontSize: compacto ? 14 : 17,
                                  fontWeight: FontWeight.w700)),
                          Text(items[index].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AnaliticaTokens.inkMutedOf(context),
                                  fontSize: compacto ? 10 : 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return ColoredBox(
        color: AnaliticaTokens.canvas,
        child: AnaliticaSkeleton.tab(),
      );
    }
    if (_error != null) {
      return FoodyEstadoUi.desdeMensaje(
        mensaje: _error!,
        onReintentar: _cargar,
      );
    }

    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: AnaliticaTokens.canvas,
      child: Stack(
        children: [
          SaasScrollableShell(
            header: [
              Container(
                margin: EdgeInsets.fromLTRB(
                    compacto ? 12 : 24, 16, compacto ? 12 : 24, 14),
                padding: EdgeInsets.all(compacto ? 14 : 20),
                decoration: BoxDecoration(
                  color: AnaliticaTokens.ink,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x160D1B2A),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: compacto ? 42 : 50,
                      height: compacto ? 42 : 50,
                      decoration: BoxDecoration(
                        color: AnaliticaTokens.ventas,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(Icons.inventory_2_rounded,
                          color: Colors.white, size: 25),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admin / Menú e Inventario',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Insumos',
                            style: TextStyle(
                              fontSize: compacto ? 21 : 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.6,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Mercado → subrecetas → costos',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compacto && _tabs.index == 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilledButton.icon(
                          onPressed: _dialogoCrearIngrediente,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nuevo insumo'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AnaliticaTokens.ventas,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                        ),
                      ),
                    if (_puedeVerHermanas)
                      IconButton(
                        tooltip: 'Inventario otras sucursales',
                        onPressed: _mostrarInventarioHermanas,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 20,
                        ),
                        color: Colors.white70,
                      ),
                    if (_tabs.index == 2)
                      IconButton(
                        tooltip: 'Historial de producciones',
                        onPressed: _mostrarHistorialProducciones,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.history, size: 20),
                        color: Colors.white70,
                      ),
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: _cargar,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),
              if (_puedeVerHermanas || widget.onIrCostos != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(compacto ? 12 : 16, 0, 16, 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 0,
                    children: [
                      if (_puedeVerHermanas)
                        TextButton.icon(
                          onPressed: _mostrarInventarioHermanas,
                          style: TextButton.styleFrom(
                            foregroundColor: AnaliticaTokens.inkMuted,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(
                            Icons.store_mall_directory_outlined,
                            size: 16,
                          ),
                          label: Text(
                            compacto ? 'Otras sedes' : 'Inventario otras sedes',
                          ),
                        ),
                      if (widget.onIrCostos != null)
                        TextButton.icon(
                          onPressed: widget.onIrCostos,
                          style: TextButton.styleFrom(
                            foregroundColor: AnaliticaTokens.inkMuted,
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.pie_chart_outline, size: 16),
                          label: Text(
                            compacto ? 'Costos' : 'Costos y márgenes',
                          ),
                        ),
                    ],
                  ),
                ),
              if (_tabs.index == 0) _resumenInventario(compacto),
              StockAlertaBanner(
                agotados: _ingredientes
                    .where((i) =>
                        i['descontar_stock'] != false &&
                        (num.tryParse('${i['stock_actual']}') ?? 0) <= 0)
                    .length,
                bajos:
                    _ingredientes.where((i) => i['bajo_minimo'] == true).length,
                onVerBajos: () {
                  setState(() {
                    _filtroInsumos = 'bajo_stock';
                    _tabs.index = 0;
                  });
                },
              ),
            ],
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compacto ? 12 : 24),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AnaliticaTokens.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FoodyScrollHorizontalFade(
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: compacto,
                        tabAlignment:
                            compacto ? TabAlignment.start : TabAlignment.fill,
                        labelColor: Colors.white,
                        unselectedLabelColor: AnaliticaTokens.inkSoft,
                        indicator: BoxDecoration(
                          color: AnaliticaTokens.ink,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicatorPadding: const EdgeInsets.all(2),
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        onTap: (_) => setState(() {}),
                        tabs: const [
                          Tab(
                              icon: Icon(Icons.shopping_basket_outlined,
                                  size: 17),
                              text: 'Mercado'),
                          Tab(
                              icon: Icon(Icons.swap_vert_rounded, size: 17),
                              text: 'Movimientos'),
                          Tab(
                              icon: Icon(Icons.soup_kitchen_outlined, size: 17),
                              text: 'Subrecetas'),
                          Tab(
                              icon: Icon(Icons.fact_check_outlined, size: 17),
                              text: 'Conteo'),
                          Tab(
                              icon:
                                  Icon(Icons.compare_arrows_rounded, size: 17),
                              text: 'Traslados'),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _listaIngredientes(),
                      _listaMovimientos(),
                      _listaSubrecetas(),
                      _tabConteo(),
                      InventarioTrasladosPanel(
                        sucursalId: widget.sucursalId!,
                        sucursalesHermanas: _sucursalesHermanas,
                        tienePermisoHermanas: _puedeVerHermanas,
                        habilitado: _puedeVerHermanas &&
                            _sucursalesHermanas.any(
                              (s) => s['sucursal_id'] != widget.sucursalId,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((_tabs.index == 0 || _tabs.index == 2) && compacto)
            Positioned(
              right: compacto ? 12 : 16,
              bottom: compacto ? 12 : 16,
              child: compacto
                  ? FloatingActionButton(
                      onPressed: _tabs.index == 0
                          ? _dialogoCrearIngrediente
                          : () => _dialogoSubreceta(),
                      backgroundColor: AnaliticaTokens.ink,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      tooltip:
                          _tabs.index == 0 ? 'Nuevo insumo' : 'Nueva subreceta',
                      child: const Icon(Icons.add, size: 22),
                    )
                  : FloatingActionButton.extended(
                      onPressed: _tabs.index == 0
                          ? _dialogoCrearIngrediente
                          : () => _dialogoSubreceta(),
                      backgroundColor: AnaliticaTokens.ink,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(
                        _tabs.index == 0 ? 'Nuevo insumo' : 'Nueva subreceta',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _ingredientesFiltrados {
    final q = _busquedaCtrl.text.trim().toLowerCase();
    return _ingredientes.where((ing) {
      final nombre = (ing['nombre'] as String? ?? '').toLowerCase();
      if (q.isNotEmpty && !nombre.contains(q)) return false;
      final soloCosto = ing['descontar_stock'] == false;
      final bajo = ing['bajo_minimo'] == true;
      switch (_filtroInsumos) {
        case 'mercado':
          return !soloCosto;
        case 'solo_costo':
          return soloCosto;
        case 'bajo_stock':
          return bajo;
        default:
          return true;
      }
    }).toList();
  }

  Widget _listaIngredientes() {
    final lista = _ingredientesFiltrados;
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    if (_ingredientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AnaliticaTokens.inkSoft,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin insumos aún',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _dialogoCrearIngrediente,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear primer insumo'),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
              compacto ? 12 : 16, 10, compacto ? 12 : 16, 4),
          child: TextField(
            controller: _busquedaCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar insumo…',
              hintStyle: const TextStyle(color: AnaliticaTokens.inkSoft),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AnaliticaTokens.inkSoft,
              ),
              isDense: true,
              filled: true,
              fillColor: AnaliticaTokens.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AnaliticaTokens.ink),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.fromLTRB(compacto ? 12 : 24, 4, compacto ? 12 : 24, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chipInsumo('todos', 'Todos'),
              _chipInsumo('mercado', 'Mercado'),
              _chipInsumo('solo_costo', 'Solo costo'),
              _chipInsumo('bajo_stock', 'Bajo stock'),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(
                  child: Text(
                    'Ningún insumo coincide',
                    style: TextStyle(color: AnaliticaTokens.inkSoft),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ancho >= FoodyBreakpoints.large
                      ? _tablaIngredientes(lista)
                      : ancho >= FoodyBreakpoints.expanded
                          ? GridView.builder(
                              padding: EdgeInsets.fromLTRB(compacto ? 12 : 24,
                                  4, compacto ? 12 : 24, 88),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                mainAxisExtent: 190,
                              ),
                              itemCount: lista.length,
                              itemBuilder: (_, i) => _tarjetaInsumo(lista[i]),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                              itemCount: lista.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) => _tarjetaInsumo(lista[i]),
                            ),
                ),
        ),
      ],
    );
  }

  Widget _tablaIngredientes(List<Map<String, dynamic>> lista) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AnaliticaTokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AnaliticaTokens.border),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 64,
            horizontalMargin: 18,
            columnSpacing: 32,
            headingTextStyle: const TextStyle(
              color: AnaliticaTokens.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            columns: const [
              DataColumn(label: Text('INSUMO')),
              DataColumn(label: Text('CATEGORÍA')),
              DataColumn(label: Text('STOCK'), numeric: true),
              DataColumn(label: Text('COSTO UNITARIO'), numeric: true),
              DataColumn(label: Text('COMPRA'), numeric: true),
              DataColumn(label: Text('ACCIONES')),
            ],
            rows: lista.map((ing) {
              final stock = num.tryParse('${ing['stock_actual']}') ?? 0;
              final minimo = num.tryParse('${ing['stock_minimo']}') ?? 0;
              final costo = num.tryParse(
                    '${ing['costo_real'] ?? ing['costo_unitario_actual']}',
                  ) ??
                  0;
              final unidad = ing['unidad_base'] as String? ?? 'und';
              final soloCosto = ing['descontar_stock'] == false;
              final estado = stockEstadoDesde(
                stock: stock,
                minimo: minimo,
                descontarStock: !soloCosto,
              );
              final color = colorStockEstado(estado);
              final categoria = (ing['categoria_insumo'] as String? ?? '')
                  .replaceAll('_', ' ');
              final compra = num.tryParse('${ing['precio_compra']}');
              return DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Row(children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AnaliticaTokens.ventas.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            soloCosto
                                ? Icons.payments_outlined
                                : Icons.inventory_2_outlined,
                            size: 16,
                            color: AnaliticaTokens.ventas,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ing['nombre'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AnaliticaTokens.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  DataCell(Text(categoria.isEmpty ? '—' : categoria)),
                  DataCell(
                    soloCosto
                        ? const Text('No controla stock')
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('$stock $unidad'),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                etiquetaStockEstado(estado),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ]),
                  ),
                  DataCell(Text('${_moneda.format(costo)} / $unidad')),
                  DataCell(Text(compra == null ? '—' : _moneda.format(compra))),
                  DataCell(PopupMenuButton<String>(
                    tooltip: 'Acciones del insumo',
                    onSelected: (accion) {
                      if (accion == 'editar') _dialogoEditarIngrediente(ing);
                      if (accion == 'compra') _dialogoCompra(ing);
                      if (accion == 'ajuste') _dialogoAjuste(ing);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'editar', child: Text('Editar')),
                      if (!soloCosto)
                        const PopupMenuItem(
                            value: 'compra', child: Text('Registrar compra')),
                      if (!soloCosto)
                        const PopupMenuItem(
                            value: 'ajuste', child: Text('Ajustar stock')),
                    ],
                  )),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _chipInsumo(String id, String label) {
    final sel = _filtroInsumos == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: sel ? AnaliticaTokens.ink : AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () => setState(() => _filtroInsumos = id),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: sel ? AnaliticaTokens.ink : AnaliticaTokens.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AnaliticaTokens.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaInsumo(Map<String, dynamic> ing) {
    final stock = num.tryParse('${ing['stock_actual']}') ?? 0;
    final minimo = num.tryParse('${ing['stock_minimo']}') ?? 0;
    final costo =
        num.tryParse('${ing['costo_real'] ?? ing['costo_unitario_actual']}') ??
            0;
    final unidad = ing['unidad_base'] as String? ?? 'und';
    final categoria = ing['categoria_insumo'] as String?;
    final soloCosto = ing['descontar_stock'] == false;
    final precioCompra = ing['precio_compra'];
    final estado = stockEstadoDesde(
      stock: stock,
      minimo: minimo,
      descontarStock: !soloCosto,
    );
    final colorRiesgo = colorStockEstado(estado);
    final esRiesgo = !soloCosto &&
        (estado == StockEstado.agotado || estado == StockEstado.bajo);
    final destacar = widget.destacarIngredienteId != null &&
        '${ing['id']}' == widget.destacarIngredienteId;

    final menu = PopupMenuButton<String>(
      tooltip: 'Acciones del insumo',
      icon: const Icon(Icons.more_horiz,
          size: 21, color: AnaliticaTokens.inkSoft),
      onSelected: (v) {
        if (v == 'editar') _dialogoEditarIngrediente(ing);
        if (v == 'compra') _dialogoCompra(ing);
        if (v == 'ajuste') _dialogoAjuste(ing);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'editar', child: Text('Editar')),
        if (!soloCosto)
          const PopupMenuItem(value: 'compra', child: Text('Registrar compra')),
        if (!soloCosto)
          const PopupMenuItem(value: 'ajuste', child: Text('Ajustar stock')),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AnaliticaTokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: destacar
              ? AnaliticaTokens.ventas.withValues(alpha: 0.55)
              : esRiesgo
                  ? colorRiesgo.withValues(alpha: 0.38)
                  : AnaliticaTokens.border,
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x080D1B2A), blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (esRiesgo ? colorRiesgo : AnaliticaTokens.ventas)
                        .withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    soloCosto
                        ? Icons.payments_outlined
                        : Icons.inventory_2_outlined,
                    color: esRiesgo ? colorRiesgo : AnaliticaTokens.ventas,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ing['nombre'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                          color: AnaliticaTokens.ink,
                        ),
                      ),
                      if (categoria != null && categoria.trim().isNotEmpty)
                        Text(
                          categoria.replaceAll('_', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AnaliticaTokens.inkMuted),
                        ),
                    ],
                  ),
                ),
                menu,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('COSTO UNITARIO',
                          style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w700,
                              color: AnaliticaTokens.inkSoft)),
                      const SizedBox(height: 3),
                      Text(
                        '${_moneda.format(costo)} / $unidad',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AnaliticaTokens.ink),
                      ),
                    ],
                  ),
                ),
                StockBadge(estado: estado),
              ],
            ),
            if (!soloCosto) ...[
              const SizedBox(height: 10),
              StockBarra(stock: stock, minimo: minimo, unidad: unidad),
            ],
            if (precioCompra != null) ...[
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 14, color: AnaliticaTokens.inkSoft),
                  const SizedBox(width: 5),
                  Text(
                    'Compra: ${_moneda.format(num.tryParse('$precioCompra') ?? 0)}',
                    style: const TextStyle(
                        fontSize: 11, color: AnaliticaTokens.inkMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _listaMovimientos() {
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    if (_movimientos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_circle_outlined,
              size: 40,
              color: AnaliticaTokens.inkSoft,
            ),
            SizedBox(height: 12),
            Text(
              'Sin movimientos aún',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              ),
            ),
          ],
        ),
      );
    }
    final extra = _hayMasMovimientos ? 1 : 0;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 16,
        8,
        compacto ? 12 : 16,
        24,
      ),
      itemCount: _movimientos.length + extra,
      itemBuilder: (_, i) {
        if (i >= _movimientos.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: TextButton(
                onPressed:
                    _cargandoMasMovimientos ? null : _cargarMasMovimientos,
                style: TextButton.styleFrom(
                  foregroundColor: AnaliticaTokens.inkMuted,
                ),
                child: _cargandoMasMovimientos
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cargar más'),
              ),
            ),
          );
        }
        final m = _movimientos[i];
        final nombre = m['ingrediente_nombre'] as String? ?? '';
        final ingId = m['ingrediente_id'] as String?;
        final tipo = '${m['tipo'] ?? ''}'.toLowerCase();
        final colorTipo = tipo.contains('compra')
            ? AnaliticaTokens.inventario
            : tipo.contains('ajuste') || tipo.contains('conteo')
                ? const Color(0xFFD97706)
                : tipo.contains('venta') || tipo.contains('consumo')
                    ? AnaliticaTokens.ventas
                    : AnaliticaTokens.inkMuted;

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AnaliticaTokens.border),
          ),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: compacto ? 10 : 12,
              vertical: 2,
            ),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorTipo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_vert, size: 16, color: colorTipo),
            ),
            title: Text(
              '${m['tipo']} · $nombre',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AnaliticaTokens.ink,
              ),
            ),
            subtitle: Text(
              [
                '${m['stock_anterior']} → ${m['stock_posterior']}',
                if ((m['motivo'] as String?)?.isNotEmpty == true)
                  '${m['motivo']}',
                if (m['created_at'] != null)
                  m['created_at'].toString().substring(0, 16),
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AnaliticaTokens.inkSoft,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 18,
              color: AnaliticaTokens.inkSoft,
            ),
            // NAV-MC-17: ir a Mercado filtrando / abriendo el insumo.
            onTap: () {
              setState(() {
                _tabs.index = 0;
                _filtroInsumos = 'todos';
                _busquedaCtrl.text = nombre;
              });
              if (ingId != null) {
                Map<String, dynamic>? ing;
                for (final e in _ingredientes) {
                  if (e['id'] == ingId) {
                    ing = e;
                    break;
                  }
                }
                if (ing != null) {
                  unawaited(_dialogoEditarIngrediente(ing));
                }
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _cargarMasMovimientos() async {
    final sid = widget.sucursalId;
    if (sid == null || _cargandoMasMovimientos || !_hayMasMovimientos) return;
    setState(() => _cargandoMasMovimientos = true);
    try {
      final next = _pageMovimientos + 1;
      final res = await _repo.movimientosPaginados(sid, page: next, limit: 50);
      if (!mounted) return;
      setState(() {
        _movimientos = [..._movimientos, ...res.items];
        _pageMovimientos = next;
        _hayMasMovimientos = res.hayMas;
        _cargandoMasMovimientos = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoMasMovimientos = false);
    }
  }

  Future<void> _ejecutarConteo() async {
    final sid = widget.sucursalId;
    if (sid == null || _ingredientes.isEmpty) return;

    final cantidades = <String, TextEditingController>{};
    for (final ing in _ingredientes) {
      cantidades[ing['id'] as String] = TextEditingController(
        text: '${ing['stock_actual']}',
      );
    }

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => FoodyDialogoShell(
          titulo: 'Conteo físico',
          subtitulo:
              'Registra las cantidades reales. El sistema ajusta diferencias.',
          maxWidth: 480,
          contenido: FoodyFormSeccion(
            titulo: 'Ingredientes',
            icono: Icons.fact_check_outlined,
            hijo: SizedBox(
              height: 320,
              child: ListView(
                children: _ingredientes.map((ing) {
                  final id = ing['id'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: cantidades[id],
                      keyboardType: TextInputType.number,
                      decoration: FoodyFormEstilo.campo(
                        label: ing['nombre'] as String? ?? '',
                        helper:
                            'Teórico: ${ing['stock_actual']} ${ing['unidad_base'] ?? ''}',
                        suffix: ing['unidad_base'] as String? ?? '',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          acciones: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cerrar conteo'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;

      final items = _ingredientes
          .map(
            (ing) => {
              'ingrediente_id': ing['id'] as String,
              'cantidad_real': double.tryParse(
                    cantidades[ing['id'] as String]!.text.replaceAll(',', '.'),
                  ) ??
                  0,
            },
          )
          .toList();

      try {
        final conteoId = await _repo.iniciarConteo(sid);
        await _repo.cerrarConteo(conteoId: conteoId, items: items);
        await _cargar();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conteo cerrado y stock actualizado')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'cerrar conteo')),
            ),
          );
        }
      }
    } finally {
      for (final c in cantidades.values) {
        c.dispose();
      }
    }
  }

  Widget _tabConteo() {
    final compacto = FoodyBreakpoints.esCompact(
      FoodyBreakpoints.widthOf(context),
    );
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compacto ? 20 : 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: EdgeInsets.all(compacto ? 20 : 24),
            decoration: BoxDecoration(
              color: AnaliticaTokens.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AnaliticaTokens.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    size: 24,
                    color: AnaliticaTokens.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Conteo físico de inventario',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: compacto ? 16 : 18,
                    color: AnaliticaTokens.ink,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Registra las cantidades reales de cada ingrediente. '
                  'El sistema ajustará el stock donde haya diferencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AnaliticaTokens.inkMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _ingredientes.isEmpty ? null : _ejecutarConteo,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Iniciar conteo'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AnaliticaTokens.ink,
                    minimumSize: Size(compacto ? double.infinity : 180, 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _listaSubrecetas() {
    final monedaDetalle = NumberFormat.currency(
      locale: 'es_CO',
      symbol: r'$',
      decimalDigits: 2,
    );
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    if (_subrecetas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_tree_outlined,
              size: 40,
              color: AnaliticaTokens.inkSoft,
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin subrecetas aún',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AnaliticaTokens.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Por defecto el stock de insumos baja al vender el plato. '
              'Solo activa «lote» si cocinas el preparado de antemano.',
              style: TextStyle(color: AnaliticaTokens.inkSoft, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _dialogoSubreceta(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Crear subreceta'),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
              ),
            ),
            if (widget.onIrCostos != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: widget.onIrCostos,
                style: TextButton.styleFrom(
                  foregroundColor: AnaliticaTokens.inkMuted,
                ),
                icon: const Icon(Icons.pie_chart_outline, size: 18),
                label: const Text('Luego armar receta en Costos'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 16,
        8,
        compacto ? 12 : 16,
        80,
      ),
      itemCount: _subrecetas.length,
      itemBuilder: (_, i) {
        final sr = _subrecetas[i];
        final unidad = sr['unidad_resultado'] as String? ?? 'g';
        final costoUnit = num.tryParse('${sr['costo_por_unidad']}');
        final costoTotal = num.tryParse('${sr['costo_total']}');
        final numItems = sr['num_items'] as int? ?? 0;
        final usaLote = sr['usa_produccion_lote'] == true;
        final stockLote = num.tryParse('${sr['stock_lote']}');
        final sinPreparar = usaLote && (stockLote == null || stockLote <= 0);

        return LayoutBuilder(
          builder: (context, c) {
            final estrecho = c.maxWidth < 520;
            final precio = costoUnit != null
                ? Text(
                    '${monedaDetalle.format(costoUnit)}/$unidad',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AnaliticaTokens.ink,
                    ),
                  )
                : null;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AnaliticaTokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: sinPreparar
                      ? AnaliticaTokens.pedidos.withValues(alpha: 0.45)
                      : AnaliticaTokens.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A111827),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _dialogoSubreceta(existente: sr),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    estrecho ? 10 : 12,
                    10,
                    4,
                    10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: sinPreparar
                              ? AnaliticaTokens.pedidos.withValues(alpha: 0.12)
                              : AnaliticaTokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.account_tree_outlined,
                          color: sinPreparar
                              ? AnaliticaTokens.pedidos
                              : AnaliticaTokens.inkMuted,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (estrecho) ...[
                              Text(
                                sr['nombre'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AnaliticaTokens.ink,
                                ),
                              ),
                              if (precio != null) ...[
                                const SizedBox(height: 2),
                                precio,
                              ],
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sr['nombre'] as String? ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AnaliticaTokens.ink,
                                      ),
                                    ),
                                  ),
                                  if (precio != null) ...[
                                    const SizedBox(width: 8),
                                    precio,
                                  ],
                                ],
                              ),
                            const SizedBox(height: 4),
                            Text(
                              'Rinde ${sr['cantidad_resultado']} $unidad · $numItems insumo${numItems == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AnaliticaTokens.inkSoft,
                              ),
                            ),
                            if (costoTotal != null)
                              Text(
                                'Total ${_moneda.format(costoTotal)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AnaliticaTokens.inkSoft,
                                ),
                              ),
                            if (usaLote) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _miniBadge(
                                    'Modo lote',
                                    AnaliticaTokens.pedidos,
                                  ),
                                  if (sinPreparar)
                                    _miniBadge(
                                      'Sin preparar',
                                      AnaliticaTokens.pedidos,
                                    )
                                  else if (stockLote != null)
                                    _miniBadge(
                                      'Stock: $stockLote $unidad',
                                      AnaliticaTokens.inventario,
                                    ),
                                ],
                              ),
                              if (sinPreparar) ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => _dialogoProduccionLote(sr),
                                    icon: const Icon(
                                      Icons.soup_kitchen_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Preparar lote'),
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ] else ...[
                              const SizedBox(height: 6),
                              _miniBadge(
                                'Stock al vender',
                                AnaliticaTokens.inventario,
                              ),
                            ],
                          ],
                        ),
                      ),
                      // NAV-MC-06: acciones secundarias en ⋮ (evita overflow móvil).
                      PopupMenuButton<String>(
                        tooltip: 'Más acciones',
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: AnaliticaTokens.inkSoft,
                        ),
                        onSelected: (v) {
                          switch (v) {
                            case 'editar':
                              _dialogoSubreceta(existente: sr);
                            case 'recalcular':
                              _recalcularSubreceta(sr);
                            case 'producir':
                              _dialogoProduccionLote(sr);
                            case 'historial':
                              _mostrarHistorialProducciones(
                                recetaId: sr['id'] as String,
                              );
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'recalcular',
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              // NAV-MC-18: mismo icono que «Recalcular todo» en Costos.
                              leading: Icon(Icons.calculate_outlined),
                              title: Text('Recalcular'),
                            ),
                          ),
                          if (usaLote)
                            const PopupMenuItem(
                              value: 'producir',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.soup_kitchen_outlined),
                                title: Text('Preparar lote'),
                              ),
                            ),
                          if (usaLote)
                            const PopupMenuItem(
                              value: 'historial',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.history),
                                title: Text('Historial de lotes'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
