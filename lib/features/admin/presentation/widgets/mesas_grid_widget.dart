import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/red/mostrar_error_snackbar.dart';
import 'package:reserva_canchas/core/red/manejo_error_plan.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_skeleton.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/admin/providers/operacion_sucursal_provider.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_api_capacidades.dart';
import 'package:reserva_canchas/features/mesa/presentation/mesa_pedidos_sheet.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/mesa/utils/mesa_qr_pdf.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/core/realtime/poll_realtime_respaldo.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Grid de mesas (Sprint 4) — colores por estado + aprobar/rechazar QR.

const _motivosRechazoQr = [
  'Cliente se equivocó',
  'Producto no disponible',
  'Mesa incorrecta',
  'Pedido duplicado',
  'Otro',
];

class MesasGridWidget extends ConsumerStatefulWidget {
  const MesasGridWidget({
    super.key,
    this.sucursalId,
    this.modoMesero = false,
    this.modoCajero = false,
    this.ocultarCabecera = false,
    this.meseraUsuarioId,
    this.mesaIdInicial,
    this.onMesaAbierta,
  }) : assert(
          !(modoMesero && modoCajero),
          'modoMesero y modoCajero son mutuamente excluyentes',
        );

  final String? sucursalId;
  final bool modoMesero;

  /// Cajero: pedir/cobrar en cualquier mesa sin turno ni asignación de mesera.
  final bool modoCajero;

  /// NAV-CJ-01: shell cajero ya tiene AppBar.
  final bool ocultarCabecera;
  final String? meseraUsuarioId;
  final String? mesaIdInicial;
  final VoidCallback? onMesaAbierta;

  @override
  ConsumerState<MesasGridWidget> createState() => _MesasGridWidgetState();
}

class _MesasGridWidgetState extends ConsumerState<MesasGridWidget>
    with WidgetsBindingObserver {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  final _pedidosRepo = PedidosRepository();
  final _mesasRepo = MesasRepository();
  final _usuariosRepo = UsuariosRepository();
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _mesasCache;
  RealtimeChannel? _canal;
  bool _pulso = true;
  Timer? _pulsoTimer;
  PollRealtimeRespaldo? _pollRespaldo;
  bool? _apiMesasOk;
  bool _avisoApiDescartado = false;
  bool _mesaInicialAbierta = false;

  /// NAV-CJ-08: todas | por_cobrar | libres
  String _filtroMesas = 'todas';

  bool get _operacionPiso => widget.modoMesero || widget.modoCajero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _cargarMesas();
    _comprobarApiMesas();
    _pulsoTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      // PERF-FL-MEM-03: no rebuild si no hay mesas que pulsen.
      if (!mounted) return;
      final cache = _mesasCache;
      final hayPulso = cache != null &&
          cache.any((m) {
            final e = (m['estado'] ?? m['estado_mesa'] ?? '').toString();
            return e == 'ocupada' || e == 'cuenta' || e == 'reservada';
          });
      if (hayPulso) setState(() => _pulso = !_pulso);
    });
    _suscribirRealtime();
    _pollRespaldo = PollRealtimeRespaldo(onActualizar: () async {
      if (mounted) _recargarMesas();
    });
    unawaited(_pollRespaldo!.iniciar());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _recargarMesas();
    }
  }

  @override
  void didUpdateWidget(MesasGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId ||
        oldWidget.mesaIdInicial != widget.mesaIdInicial) {
      FoodyRealtime.liberarCanal(_canal);
      _canal = null;
      _mesasCache = null;
      _mesaInicialAbierta = false;
      _future = _cargarMesas();
      _suscribirRealtime();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FoodyRealtime.liberarCanal(_canal);
    _pulsoTimer?.cancel();
    _pollRespaldo?.detener();
    super.dispose();
  }

  void _suscribirRealtime() {
    final id = widget.sucursalId;
    if (!AppBackend.supabaseReady || id == null) return;
    _canal = FoodyRealtime.suscribirSucursal(
      id,
      onEvento: (evento) {
        if (evento == 'qr_aprobacion_urgente' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido QR pendiente de aprobacion en mesa'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        if (evento == 'llamar_mesera' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cliente pide atencion en mesa'),
              backgroundColor: AnaliticaTokens.inventario,
              duration: Duration(seconds: 5),
            ),
          );
        }
        _recargarMesas();
      },
      onReconectado: () {
        if (mounted) _recargarMesas();
      },
    );
  }

  Future<void> _comprobarApiMesas() async {
    final ok = await backendMesasActualizado();
    if (mounted) setState(() => _apiMesasOk = ok);
  }

  Future<List<Map<String, dynamic>>> _cargarMesas() async {
    if (widget.sucursalId == null) return [];
    final lista = await _mesasRepo.listar(widget.sucursalId!);
    _mesasCache = lista;
    if (!_mesaInicialAbierta && widget.mesaIdInicial != null) {
      Map<String, dynamic>? mesa;
      for (final m in lista) {
        if ('${m['id']}' == widget.mesaIdInicial) {
          mesa = m;
          break;
        }
      }
      if (mesa != null) {
        _mesaInicialAbierta = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mostrarDetalleMesa(mesa!);
          widget.onMesaAbierta?.call();
        });
      }
    }
    return lista;
  }

  void _recargarMesas() {
    setState(() {
      _future = _cargarMesas();
    });
  }

  Future<void> _crearMesa() async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final ctrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva mesa'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nombre (ej. Mesa 5)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isNotEmpty),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      return;
    }
    try {
      await _mesasRepo.crear(sucursalId: sid, nombre: ctrl.text.trim());
      _recargarMesas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesa creada')),
        );
      }
    } catch (e) {
      if (mounted) {
        if (!ManejoErrorPlan.manejarEnPantalla(context, e)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(mensajeErrorHttp(e, contexto: 'crear mesa'))),
          );
        }
      }
    }
    ctrl.dispose();
  }

  Future<void> _opcionesMesa(Map<String, dynamic> mesa) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_seat),
              title: const Text('Reservar mesa'),
              onTap: () => Navigator.pop(ctx, 'reservar'),
            ),
            if (mesa['estado_operativo'] == 'reservada')
              ListTile(
                leading: const Icon(Icons.event_busy),
                title: const Text('Cancelar reserva'),
                onTap: () => Navigator.pop(ctx, 'cancelar_reserva'),
              ),
            ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('Unir con otra mesa'),
              onTap: () => Navigator.pop(ctx, 'unir'),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Ver enlace QR'),
              onTap: () => Navigator.pop(ctx, 'qr'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Renombrar'),
              onTap: () => Navigator.pop(ctx, 'renombrar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Desactivar mesa'),
              onTap: () => Navigator.pop(ctx, 'eliminar'),
            ),
          ],
        ),
      ),
    );
    if (accion == 'qr') await _mostrarQr(mesa);
    if (accion == 'reservar') await _reservarMesa(mesa);
    if (accion == 'cancelar_reserva') await _cancelarReservaMesa(mesa);
    if (accion == 'unir') await _unirMesas(mesa);
    if (accion == 'renombrar') await _renombrarMesa(mesa);
    if (accion == 'eliminar') await _desactivarMesa(mesa);
  }

  Future<void> _mostrarQr(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      final datos = await _mesasRepo.obtenerQr(
        mesaId: '${mesa['id']}',
        sucursalId: sid,
        baseUrl: kIsWeb ? Uri.base.origin : null,
      );
      final url = datos['url'] as String? ?? '';
      if (!mounted) return;
      final nombre = mesa['nombre'] as String? ?? 'Mesa';
      await FoodyDialogo.mostrar<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          return Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'QR — $nombre',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: url,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 72),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          url,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final bytes = await MesaQrPdfFoody.generar(
                            nombreMesa: nombre,
                            urlQr: url,
                          );
                          await _compartirPdfQr(bytes, nombre);
                        } catch (e) {
                          if (ctx.mounted) {
                            mostrarErrorSnackBar(
                              ctx,
                              e,
                              contexto: 'generar PDF del QR',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: const Text('PDF / Imprimir'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enlace copiado')),
                        );
                      },
                      icon: const Icon(Icons.link, size: 18),
                      label: const Text('Copiar enlace'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        mostrarErrorSnackBar(context, e, contexto: 'obtener QR de mesa');
      }
    }
  }

  Future<void> _renombrarMesa(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final ctrl = TextEditingController(text: '${mesa['nombre']}');
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar mesa'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isNotEmpty),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _mesasRepo.actualizar(
        mesaId: '${mesa['id']}',
        sucursalId: sid,
        nombre: ctrl.text.trim(),
      );
      _recargarMesas();
    }
    ctrl.dispose();
  }

  Future<void> _desactivarMesa(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar mesa'),
        content: Text('¿Desactivar ${mesa['nombre']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Desactivar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _mesasRepo.desactivar('${mesa['id']}', sid);
        _recargarMesas();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(mensajeErrorHttp(e, contexto: 'desactivar'))),
          );
        }
      }
    }
  }

  Future<void> _reservarMesa(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final nombreCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final hastaCtrl = TextEditingController(
      text: DateTime.now()
          .add(const Duration(hours: 2))
          .toString()
          .substring(0, 16),
    );
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reservar ${mesa['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre cliente',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: telCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: hastaCtrl,
              decoration: const InputDecoration(
                labelText: 'Reserva hasta (YYYY-MM-DD HH:MM)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reservar')),
        ],
      ),
    );
    if (ok != true) {
      nombreCtrl.dispose();
      telCtrl.dispose();
      hastaCtrl.dispose();
      return;
    }
    try {
      final hasta = DateTime.tryParse(hastaCtrl.text.replaceFirst(' ', 'T')) ??
          DateTime.now().add(const Duration(hours: 2));
      await _mesasRepo.reservar(
        mesaId: '${mesa['id']}',
        sucursalId: sid,
        clienteNombre: nombreCtrl.text.trim(),
        reservaHasta: hasta,
        clienteTelefono: telCtrl.text.trim(),
      );
      _recargarMesas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'reservar'))),
        );
      }
    }
    nombreCtrl.dispose();
    telCtrl.dispose();
    hastaCtrl.dispose();
  }

  Future<void> _cancelarReservaMesa(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    try {
      await _mesasRepo.cancelarReserva(
          mesaId: '${mesa['id']}', sucursalId: sid);
      _recargarMesas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'cancelar reserva'))),
        );
      }
    }
  }

  Future<void> _unirMesas(Map<String, dynamic> mesaPrincipal) async {
    final sid = widget.sucursalId;
    if (sid == null || _mesasCache == null) return;
    final otras = _mesasCache!
        .where((m) => m['id'] != mesaPrincipal['id'] && m['activa'] != false)
        .toList();
    if (otras.isEmpty) return;

    final seleccionadas = <String>{};
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Unir con ${mesaPrincipal['nombre']}'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: otras
                  .map(
                    (m) => CheckboxListTile(
                      value: seleccionadas.contains(m['id']),
                      title: Text(m['nombre'] as String? ?? 'Mesa'),
                      onChanged: (v) {
                        setDialog(() {
                          if (v == true) {
                            seleccionadas.add('${m['id']}');
                          } else {
                            seleccionadas.remove('${m['id']}');
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed:
                  seleccionadas.isEmpty ? null : () => Navigator.pop(ctx, true),
              child: const Text('Unir mesas'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _mesasRepo.unirMesas(
        sucursalId: sid,
        mesaPrincipalId: '${mesaPrincipal['id']}',
        mesasSecundarias: seleccionadas.toList(),
      );
      _recargarMesas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesas unidas en una cuenta')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'unir mesas'))),
        );
      }
    }
  }

  Color _bordeMesa(Map<String, dynamic> mesa) {
    if (mesa['estado_operativo'] == 'reservada') {
      return AnaliticaTokens.clientes;
    }
    final estado = mesa['pedido_estado'] as String?;
    if (estado == 'pendiente_aprobacion') {
      return _pulso ? const Color(0xFFD97706) : const Color(0xFFFBBF24);
    }
    if (estado != null) return AnaliticaTokens.pedidos;
    return AnaliticaTokens.inventario;
  }

  String _etiquetaEstado(Map<String, dynamic> mesa) {
    if (mesa['estado_operativo'] == 'reservada') return 'Reservada';
    final estado = mesa['pedido_estado'] as String?;
    if (estado == 'pendiente_aprobacion') return 'QR pendiente';
    if (mesa['pedido_id'] != null) {
      if (widget.modoMesero) return 'En mesa';
      return 'Por cobrar';
    }
    return 'Libre';
  }

  String _ctaMesa(Map<String, dynamic> mesa) {
    final ocupada = mesa['pedido_id'] != null;
    final qr = mesa['pedido_estado'] == 'pendiente_aprobacion';
    if (_operacionPiso && !ocupada) {
      return widget.modoMesero ? 'Pedir' : 'Registrar';
    }
    if (qr) {
      return widget.modoCajero ? 'Esperando mesero' : 'Aprobar QR';
    }
    if (_operacionPiso && ocupada) {
      return widget.modoMesero ? 'Cuenta · agregar' : 'Cobrar';
    }
    if (ocupada) return 'Ver cuenta';
    return mesa['estado_operativo'] == 'reservada' ? 'Reservada' : 'Libre';
  }

  IconData _iconoCta(Map<String, dynamic> mesa) {
    final ocupada = mesa['pedido_id'] != null;
    final qr = mesa['pedido_estado'] == 'pendiente_aprobacion';
    if (qr) return Icons.qr_code_scanner;
    if (!ocupada) return Icons.add_shopping_cart_outlined;
    if (widget.modoMesero) return Icons.receipt_long_outlined;
    return Icons.payments_outlined;
  }

  /// MES-012: tiempo visible en tarjeta sin abrir el sheet.
  Widget _badgeTimerQr(dynamic creadoRaw) {
    final creado =
        creadoRaw != null ? DateTime.tryParse('$creadoRaw')?.toLocal() : null;
    if (creado == null) return const SizedBox.shrink();
    final seg = DateTime.now().difference(creado).inSeconds;
    final minutos = seg ~/ 60;
    final segundos = seg % 60;
    final urgente = minutos >= 5;
    final advertencia = minutos >= 3 && minutos < 5;
    final texto =
        '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: urgente
            ? AnaliticaTokens.alertas.withValues(alpha: 0.15)
            : advertencia
                ? Color(0xFFD97706).withValues(alpha: 0.4)
                : const Color(0xFF185FA5).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: urgente
            ? Border.all(color: AnaliticaTokens.alertas, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: urgente
                ? AnaliticaTokens.alertas
                : advertencia
                    ? _scheme.onSurface
                    : const Color(0xFF185FA5),
          ),
          const SizedBox(width: 4),
          Text(
            urgente ? '$texto · urgente' : texto,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: urgente ? AnaliticaTokens.alertas : _scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDetalleMesa(Map<String, dynamic> mesa) async {
    final estado = mesa['pedido_estado'] as String?;
    final pedidoId = mesa['pedido_id'] as String?;

    if (pedidoId == null && estado != 'pendiente_aprobacion') {
      await _accionMesaLibre(mesa);
      return;
    }

    if (estado == 'pendiente_aprobacion' && pedidoId != null) {
      // NAV-CJ-09: cajero no aprueba QR.
      if (widget.modoCajero) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pedido QR pendiente: un mesero o admin debe aprobarlo',
              ),
            ),
          );
        }
        return;
      }
      final creadoRaw = mesa['pedido_creado_at'];
      final creado = creadoRaw != null ? DateTime.tryParse('$creadoRaw') : null;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _SheetAprobacionQr(
          mesaNombre: mesa['nombre'] as String? ?? 'Mesa',
          numeroPedido: mesa['numero_pedido'] as String? ?? '',
          pedidoCreadoAt: creado,
          onAprobar: () async {
            Navigator.pop(ctx);
            await _pedidosRepo.aprobarMesa(
              pedidoId,
              sucursalId: widget.sucursalId,
            );
            _recargarMesas();
          },
          onRechazar: () async {
            Navigator.pop(ctx);
            await _rechazarConMotivo(pedidoId);
          },
        ),
      );
      return;
    }

    if (pedidoId != null) {
      final sid = widget.sucursalId;
      if (sid == null) return;
      final meseraAsignada = mesa['mesera_asignada_id'] as String?;
      if (widget.modoMesero &&
          meseraAsignada != null &&
          meseraAsignada != widget.meseraUsuarioId) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mesa atendida por ${mesa['mesera_nombre'] ?? 'otra mesera'}',
              ),
            ),
          );
        }
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => MesaPedidosSheet(
          mesaId: '${mesa['id']}',
          mesaNombre: mesa['nombre'] as String? ?? 'Mesa',
          sucursalId: sid,
          onActualizado: _recargarMesas,
          modoMesero: widget.modoMesero,
          onAgregarProductos: _operacionPiso
              ? (pedidoId) => _abrirPedidoMesa(mesa, pedidoIdAgregar: pedidoId)
              : null,
          // MES-XFER-UI-01: admin y cajero; mesero de piso no.
          onTransferir: (!widget.modoMesero)
              ? () {
                  Navigator.pop(ctx);
                  _transferirMesa(mesa, pedidoId);
                }
              : null,
        ),
      );
    }
  }

  Future<void> _transferirMesa(
    Map<String, dynamic> mesaOrigen,
    String pedidoId,
  ) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    List<Map<String, dynamic>> mesas = _mesasCache ?? [];
    if (mesas.isEmpty) {
      mesas = await _cargarMesas();
    }

    final libres = mesas.where((m) {
      if (m['id'] == mesaOrigen['id']) return false;
      return m['pedido_id'] == null && m['activa'] != false;
    }).toList();

    if (libres.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay mesas libres disponibles')),
        );
      }
      return;
    }

    Map<String, dynamic>? destino;
    final motivoCtrl = TextEditingController();

    if (!mounted) return;
    destino = await FoodyDialogo.mostrar<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transferir pedido'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Desde ${mesaOrigen['nombre']} → elige mesa destino',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: libres.length,
                  itemBuilder: (context, i) {
                    final m = libres[i];
                    return ListTile(
                      title: Text(m['nombre'] as String? ?? 'Mesa'),
                      onTap: () => Navigator.pop(ctx, m),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: motivoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Motivo (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (destino == null) {
      motivoCtrl.dispose();
      return;
    }

    try {
      final resultado = await _mesasRepo.transferir(
        sucursalId: sid,
        pedidoId: pedidoId,
        mesaOrigenId: '${mesaOrigen['id']}',
        mesaDestinoId: '${destino['id']}',
        motivo: motivoCtrl.text.trim().isEmpty ? null : motivoCtrl.text.trim(),
      );
      _recargarMesas();
      if (mounted) {
        final alerta = resultado['alerta_transferencias_multiples'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              alerta
                  ? 'Pedido transferido a ${destino['nombre']}. Alerta: más de 2 transferencias.'
                  : 'Pedido transferido a ${destino['nombre']}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'transferir mesa'))),
        );
      }
    }
    motivoCtrl.dispose();
  }

  Future<void> _abrirPedidoMesa(
    Map<String, dynamic> mesa, {
    String? pedidoIdAgregar,
  }) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              pedidoIdAgregar != null
                  ? 'Agregar · ${mesa['nombre']}'
                  : 'Pedido · ${mesa['nombre']}',
            ),
          ),
          body: PedidoCajeroScreen(
            sucursalId: sid,
            mesaIdFija: '${mesa['id']}',
            mesaNombreFija: mesa['nombre'] as String? ?? 'Mesa',
            modoMesero: widget.modoMesero,
            pedidoIdAgregar: pedidoIdAgregar,
            ocultarCabecera: true,
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      _recargarMesas();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pedidoIdAgregar != null
                ? 'Ítems agregados a ${mesa['nombre']}'
                : 'Pedido creado en ${mesa['nombre']}',
          ),
        ),
      );
    }
  }

  Future<void> _accionMesaLibre(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    final meseraAsignada = mesa['mesera_asignada_id'] as String?;
    if (widget.modoMesero &&
        meseraAsignada != null &&
        meseraAsignada != widget.meseraUsuarioId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mesa atendida por ${mesa['mesera_nombre'] ?? 'otra mesera'}',
            ),
          ),
        );
      }
      return;
    }

    if (widget.modoMesero || widget.modoCajero) {
      final crear = await showModalBottomSheet<bool>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    Icon(Icons.add_shopping_cart, color: _scheme.onSurface),
                title: Text('Crear pedido · ${mesa['nombre']}'),
                subtitle: Text(
                  widget.modoMesero
                      ? 'Tomarás esta mesa al confirmar el pedido'
                      : 'Registrar consumo en esta mesa (sin asignarte el turno)',
                ),
                onTap: () => Navigator.pop(ctx, true),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      );
      if (crear != true || !mounted) return;
      await _abrirPedidoMesa(mesa);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesa libre. Mantén pulsado para opciones de admin.'),
        ),
      );
    }
  }

  Future<void> _asignarTurnoMesas() async {
    final sid = widget.sucursalId;
    if (sid == null) return;

    List<Map<String, dynamic>> mesas;
    List<Map<String, dynamic>> meseras;
    try {
      mesas = await _mesasRepo.listar(sid);
      final usuarios = await _usuariosRepo.listar(sid);
      meseras = usuarios
          .where((u) => u['rol'] == 'mesero' && u['activo'] == true)
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'cargar turno'))),
        );
      }
      return;
    }

    final asignaciones = {
      for (final m in mesas)
        m['id'] as String: m['mesera_asignada_id'] as String?,
    };

    if (!mounted) return;
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: const Text('Asignar turno de mesas'),
            content: SizedBox(
              width: 420,
              child: mesas.isEmpty
                  ? const Text('No hay mesas activas en esta sucursal.')
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: mesas.map((mesa) {
                          final mesaId = mesa['id'] as String;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: DropdownButtonFormField<String?>(
                              initialValue: asignaciones[mesaId],
                              decoration: InputDecoration(
                                labelText: mesa['nombre'] as String? ?? 'Mesa',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Sin asignar'),
                                ),
                                ...meseras.map(
                                  (u) => DropdownMenuItem<String?>(
                                    value: u['id'] as String,
                                    child: Text(u['nombre'] as String? ?? ''),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                setDialog(() => asignaciones[mesaId] = v);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed:
                    mesas.isEmpty ? null : () => Navigator.pop(ctx, true),
                child: const Text('Guardar turno'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;

    try {
      await _mesasRepo.asignarTurno(
        sucursalId: sid,
        asignaciones: asignaciones.entries
            .map(
              (e) => {
                'mesa_id': e.key,
                'mesera_asignada_id': e.value,
              },
            )
            .toList(),
      );
      _recargarMesas();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turno de mesas actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(mensajeErrorHttp(e, contexto: 'asignar turno'))),
        );
      }
    }
  }

  Future<void> _compartirPdfQr(Uint8List bytes, String nombreMesa) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'application/pdf',
            name:
                'foody-qr-${nombreMesa.replaceAll(' ', '-').toLowerCase()}.pdf',
          ),
        ],
        text: 'QR mesa $nombreMesa — Foody',
      ),
    );
  }

  Future<void> _rechazarConMotivo(String pedidoId) async {
    var motivoSel = _motivosRechazoQr.first;
    final otroCtrl = TextEditingController();
    final ok = await FoodyDialogo.mostrar<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Motivo de rechazo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: motivoSel,
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  border: OutlineInputBorder(),
                ),
                items: _motivosRechazoQr
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setSt(() => motivoSel = v);
                },
              ),
              if (motivoSel == 'Otro') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: otroCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Detalle',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (motivoSel == 'Otro' && otroCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Rechazar'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final motivo = motivoSel == 'Otro' ? otroCtrl.text.trim() : motivoSel;
      await _pedidosRepo.rechazarMesa(
        pedidoId,
        motivo: motivo,
        sucursalId: widget.sucursalId,
      );
      _recargarMesas();
    }
    otroCtrl.dispose();
  }

  int _contarQrPendientes(List<Map<String, dynamic>> mesas) {
    return mesas
        .where((m) => m['pedido_estado'] == 'pendiente_aprobacion')
        .length;
  }

  int _contarQrUrgentes(List<Map<String, dynamic>> mesas) {
    final ahora = DateTime.now();
    var n = 0;
    for (final m in mesas) {
      if (m['pedido_estado'] != 'pendiente_aprobacion') continue;
      final raw = m['pedido_creado_at'];
      final creado = raw != null ? DateTime.tryParse('$raw') : null;
      if (creado == null) continue;
      if (ahora.difference(creado.toLocal()).inMinutes >= 3) n++;
    }
    return n;
  }

  /// Prioriza QR &gt;3 min; si no, la primera pendiente (NAV-ADM-04).
  Map<String, dynamic>? _mesaQrPrioritaria(List<Map<String, dynamic>> mesas) {
    final ahora = DateTime.now();
    Map<String, dynamic>? primeraPendiente;
    for (final m in mesas) {
      if (m['pedido_estado'] != 'pendiente_aprobacion') continue;
      primeraPendiente ??= m;
      final raw = m['pedido_creado_at'];
      final creado = raw != null ? DateTime.tryParse('$raw') : null;
      if (creado != null && ahora.difference(creado.toLocal()).inMinutes >= 3) {
        return m;
      }
    }
    return primeraPendiente;
  }

  Widget? _bannerQrPendientes(List<Map<String, dynamic>> mesas) {
    final pendientes = _contarQrPendientes(mesas);
    if (pendientes == 0) return null;

    final urgentes = _contarQrUrgentes(mesas);
    final mesaPrioritaria = _mesaQrPrioritaria(mesas);

    void abrirPrioritaria() {
      if (mesaPrioritaria != null) {
        unawaited(_mostrarDetalleMesa(mesaPrioritaria));
      }
    }

    // Mesero y admin: mismo patrón con CTA Revisar (NAV-ADM-04).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: abrirPrioritaria,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: urgentes > 0
                ? AnaliticaTokens.alertas.withValues(alpha: 0.1)
                : const Color(0xFFD97706).withValues(alpha: 0.1),
            border: Border.all(
              color: urgentes > 0
                  ? AnaliticaTokens.alertas
                  : const Color(0xFFD97706),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: urgentes > 0
                    ? AnaliticaTokens.alertas
                    : const Color(0xFFD97706),
                foregroundColor: Colors.white,
                child: Text(
                  '$pendientes',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pendientes == 1
                          ? '1 pedido QR por aprobar'
                          : '$pendientes pedidos QR por aprobar',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      urgentes > 0
                          ? (urgentes == 1
                              ? '1 lleva más de 3 min — toca para revisar'
                              : '$urgentes llevan más de 3 min — toca para revisar')
                          : 'Toca para abrir la mesa',
                      style: TextStyle(
                        fontSize: 12,
                        color: urgentes > 0
                            ? Colors.red.shade700
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: abrirPrioritaria,
                child: const Text('Revisar'),
              ),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: _recargarMesas,
                icon: Icon(Icons.refresh, color: _scheme.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(
      operacionSucursalProvider.select((s) => s.epochPedidos),
      (prev, next) {
        if (prev != null && prev != next && mounted) _recargarMesas();
      },
    );
    final ancho = FoodyBreakpoints.widthOf(context);
    final compacto = FoodyBreakpoints.esCompact(ancho);

    return ColoredBox(
      color: _scheme.surface,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.ocultarCabecera)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compacto ? 12 : 16,
                    8,
                    compacto ? 12 : 16,
                    4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.modoMesero
                            ? 'Piso / Mesero'
                            : widget.modoCajero
                                ? 'Piso / Cajero'
                                : 'Admin / Operación',
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
                                  'Mesas',
                                  style: TextStyle(
                                    fontSize: compacto ? 18 : 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: _scheme.onSurface,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.modoMesero
                                      ? 'Toca una mesa para pedir, agregar o presentar cuenta'
                                      : widget.modoCajero
                                          ? 'Toca para cobrar o registrar en mesa'
                                          : 'Salón en vivo · filtros por estado',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!compacto) _leyenda(),
                        ],
                      ),
                      if (!widget.modoMesero && !widget.modoCajero) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => context.push('/admin/cajero'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _scheme.onSurface,
                                side: BorderSide(
                                  color: _scheme.outlineVariant,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(
                                Icons.point_of_sale_outlined,
                                size: 18,
                              ),
                              label: const Text('Modo caja'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _asignarTurnoMesas,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _scheme.onSurface,
                                side: BorderSide(
                                  color: _scheme.outlineVariant,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.people_outline, size: 18),
                              label: const Text('Turno mesas'),
                            ),
                            FilledButton.icon(
                              onPressed: _crearMesa,
                              style: FilledButton.styleFrom(
                                backgroundColor: _scheme.primary,
                                foregroundColor: _scheme.onPrimary,
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Nueva mesa'),
                            ),
                          ],
                        ),
                      ],
                      if (compacto) ...[
                        const SizedBox(height: 8),
                        _leyenda(),
                      ],
                    ],
                  ),
                )
              else if (!widget.modoMesero && !widget.modoCajero)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _leyenda(),
                  ),
                ),
              if (_apiMesasOk == false && !_avisoApiDescartado)
                MaterialBanner(
                  content: const Text(
                    'El API en ejecución parece antiguo (faltan acciones de mesa). '
                    'Reinicia el backend y pulsa Revisar.',
                  ),
                  leading: const Icon(
                    Icons.warning_amber,
                    color: Color(0xFFD97706),
                  ),
                  backgroundColor:
                      const Color(0xFFD97706).withValues(alpha: 0.12),
                  actions: [
                    TextButton(
                      onPressed: _comprobarApiMesas,
                      child: const Text('Revisar'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _avisoApiDescartado = true),
                      child: const Text('Ocultar'),
                    ),
                  ],
                ),
              if (_mesasCache != null && !widget.modoCajero) ...[
                if (_bannerQrPendientes(_mesasCache!) != null)
                  _bannerQrPendientes(_mesasCache!)!,
              ],
              Expanded(child: _grid()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumenMesas(List<Map<String, dynamic>> mesas) {
    var libres = 0, ocupadas = 0, qr = 0;
    for (final m in mesas) {
      final e = m['pedido_estado'] as String?;
      if (e == 'pendiente_aprobacion') {
        qr++;
      } else if (m['pedido_id'] != null) {
        ocupadas++;
      } else {
        libres++;
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _statMesa(
                  '$libres',
                  'Libres',
                  AnaliticaTokens.inventario,
                  icono: Icons.event_available_outlined,
                  seleccionado: _filtroMesas == 'libres',
                  onTap: () => setState(
                    () => _filtroMesas =
                        _filtroMesas == 'libres' ? 'todas' : 'libres',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _statMesa(
                  '$ocupadas',
                  widget.modoMesero ? 'Ocupadas' : 'Por cobrar',
                  AnaliticaTokens.pedidos,
                  icono: Icons.table_restaurant_outlined,
                  seleccionado: _filtroMesas == 'por_cobrar',
                  onTap: () => setState(
                    () => _filtroMesas =
                        _filtroMesas == 'por_cobrar' ? 'todas' : 'por_cobrar',
                  ),
                ),
              ),
              if (!widget.modoCajero) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _statMesa(
                    '$qr',
                    'QR',
                    const Color(0xFFD97706),
                    icono: Icons.qr_code_2_outlined,
                    seleccionado: _filtroMesas == 'qr',
                    urgente: qr > 0,
                    onTap: () => setState(
                      () =>
                          _filtroMesas = _filtroMesas == 'qr' ? 'todas' : 'qr',
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_filtroMesas != 'todas')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _filtroMesas = 'todas'),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Ver todas'),
                style: TextButton.styleFrom(
                  foregroundColor: _scheme.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statMesa(
    String num,
    String label,
    Color color, {
    required IconData icono,
    bool seleccionado = false,
    bool urgente = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: seleccionado
                  ? _scheme.onSurface
                  : (urgente
                      ? color.withValues(alpha: 0.4)
                      : _scheme.outlineVariant),
              width: seleccionado ? 1.4 : 1,
            ),
            boxShadow: seleccionado ? AnaliticaTokens.shadowSoft : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(icono, size: 14, color: _scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                num,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: seleccionado ? _scheme.onSurface : _scheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                  color: seleccionado
                      ? _scheme.onSurface
                      : _scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AnaliticaSkeleton.tab();
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: _scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    mensajeErrorHttp(snapshot.error!, contexto: 'cargar mesas'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _recargarMesas,
                    style: FilledButton.styleFrom(
                      backgroundColor: _scheme.primary,
                      foregroundColor: _scheme.onPrimary,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final mesas = snapshot.data ?? [];
        if (mesas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.table_restaurant_outlined,
                      size: 32,
                      color: _scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sin mesas en el salón',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.modoMesero || widget.modoCajero
                        ? 'Pide al administrador que cree las mesas del salón.'
                        : 'Crea la primera mesa para empezar a operar.',
                    style: TextStyle(
                      color: _scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!widget.modoMesero && !widget.modoCajero) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _crearMesa,
                      style: FilledButton.styleFrom(
                        backgroundColor: _scheme.primary,
                        foregroundColor: _scheme.onPrimary,
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear primera mesa'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _resumenMesas(mesas),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final f = _cargarMesas();
                  setState(() => _future = f);
                  await f;
                },
                color: _scheme.onSurface,
                child: Builder(
                  builder: (context) {
                    final filtradas = mesas.where((m) {
                      final e = m['pedido_estado'] as String?;
                      final ocupada =
                          m['pedido_id'] != null && e != 'pendiente_aprobacion';
                      final libre = m['pedido_id'] == null;
                      final qr = e == 'pendiente_aprobacion';
                      switch (_filtroMesas) {
                        case 'por_cobrar':
                          return ocupada;
                        case 'libres':
                          return libre;
                        case 'qr':
                          return qr;
                        default:
                          return true;
                      }
                    }).toList();
                    // ponytail: orden visual piso — QR → ocupadas → libres.
                    filtradas.sort((a, b) {
                      int peso(Map<String, dynamic> m) {
                        if (m['pedido_estado'] == 'pendiente_aprobacion') {
                          return 0;
                        }
                        if (m['pedido_id'] != null) return 1;
                        if (m['estado_operativo'] == 'reservada') return 2;
                        return 3;
                      }

                      final c = peso(a).compareTo(peso(b));
                      if (c != 0) return c;
                      return '${a['nombre']}'.compareTo('${b['nombre']}');
                    });
                    if (filtradas.isEmpty) {
                      return ListView(
                        children: [
                          const SizedBox(height: 48),
                          Center(
                            child: Text(
                              _filtroMesas == 'por_cobrar'
                                  ? 'No hay mesas por cobrar'
                                  : _filtroMesas == 'libres'
                                      ? 'No hay mesas libres'
                                      : 'Sin mesas en este filtro',
                              style: TextStyle(
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final w = MediaQuery.sizeOf(context).width;
                    final cols = FoodyBreakpoints.esLarge(w)
                        ? 5
                        : FoodyBreakpoints.esExpanded(w)
                            ? 4
                            : w < 400
                                ? 2
                                : 3;
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        // Más alto = mejor hit target para meseros en tablet/móvil.
                        childAspectRatio: w < 400
                            ? 0.82
                            : w < 700
                                ? 0.9
                                : 1.05,
                      ),
                      itemCount: filtradas.length,
                      itemBuilder: (context, index) =>
                          _tarjetaMesaPiso(filtradas[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetaMesaPiso(Map<String, dynamic> mesa) {
    final borde = _bordeMesa(mesa);
    final ocupada = mesa['pedido_id'] != null;
    final qr = mesa['pedido_estado'] == 'pendiente_aprobacion';
    final nombre = mesa['nombre'] as String? ?? 'Mesa';
    final etiqueta = _etiquetaEstado(mesa);
    final cta = _ctaMesa(mesa);

    return Material(
      color: _scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _mostrarDetalleMesa(mesa),
        onLongPress: _operacionPiso ? null : () => _opcionesMesa(mesa),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: _scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  qr ? borde.withValues(alpha: 0.55) : _scheme.outlineVariant,
            ),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: borde),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: borde,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                etiqueta,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (!_operacionPiso)
                              IconButton(
                                tooltip: 'Opciones (QR, unir, renombrar…)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                iconSize: 18,
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.more_vert,
                                  color: _scheme.onSurfaceVariant,
                                ),
                                onPressed: () => _opcionesMesa(mesa),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.3,
                            color: _scheme.onSurface,
                            height: 1.15,
                          ),
                        ),
                        if (mesa['numero_pedido'] != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${mesa['numero_pedido']}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: _scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (qr) _badgeTimerQr(mesa['pedido_creado_at']),
                        if ((mesa['qr_pendientes_count'] as int? ?? 0) > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${mesa['qr_pendientes_count']} QR pendientes',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (mesa['mesera_nombre'] != null && ocupada)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: _scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    mesa['mesera_nombre'] as String,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _scheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ocupada || qr
                                ? _scheme.primary
                                : _scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _iconoCta(mesa),
                                size: 14,
                                color: ocupada || qr
                                    ? _scheme.onPrimary
                                    : _scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  cta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: ocupada || qr
                                        ? _scheme.onPrimary
                                        : _scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        _puntoLeyenda(AnaliticaTokens.inventario, 'Libre'),
        _puntoLeyenda(AnaliticaTokens.pedidos, 'Ocupada'),
        _puntoLeyenda(const Color(0xFFD97706), 'QR'),
      ],
    );
  }

  Widget _puntoLeyenda(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          t,
          style: TextStyle(
            fontSize: 11,
            color: _scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet con timer de aprobación QR (alerta a 3 y 5 min).
class _SheetAprobacionQr extends StatefulWidget {
  const _SheetAprobacionQr({
    required this.mesaNombre,
    required this.numeroPedido,
    required this.pedidoCreadoAt,
    required this.onAprobar,
    required this.onRechazar,
  });

  final String mesaNombre;
  final String numeroPedido;
  final DateTime? pedidoCreadoAt;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  @override
  State<_SheetAprobacionQr> createState() => _SheetAprobacionQrState();
}

class _SheetAprobacionQrState extends State<_SheetAprobacionQr> {
  ColorScheme get _scheme => Theme.of(context).colorScheme;

  Timer? _timer;
  int _segundos = 0;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final creado = widget.pedidoCreadoAt;
    if (creado == null) return;
    setState(() {
      _segundos = DateTime.now().difference(creado.toLocal()).inSeconds;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _textoTiempo {
    final m = _segundos ~/ 60;
    final s = _segundos % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final minutos = _segundos ~/ 60;
    final urgente = minutos >= 5;
    final advertencia = minutos >= 3 && minutos < 5;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.mesaNombre} — pedido QR',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(widget.numeroPedido),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: urgente
                    ? AnaliticaTokens.alertas.withValues(alpha: 0.15)
                    : advertencia
                        ? Color(0xFFD97706).withValues(alpha: 0.35)
                        : _scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: urgente
                    ? Border.all(color: AnaliticaTokens.alertas, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color:
                        urgente ? AnaliticaTokens.alertas : _scheme.onSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      urgente
                          ? 'Esperando $_textoTiempo — ¡Aprueba o rechaza ya!'
                          : advertencia
                              ? 'Esperando $_textoTiempo — revisa pronto'
                              : 'Esperando $_textoTiempo',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: urgente
                            ? AnaliticaTokens.alertas
                            : _scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: widget.onAprobar, child: const Text('Aprobar')),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: widget.onRechazar, child: const Text('Rechazar')),
          ],
        ),
      ),
    );
  }
}
