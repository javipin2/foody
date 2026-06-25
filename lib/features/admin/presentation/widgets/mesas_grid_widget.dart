import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/admin/data/pedidos_repository.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_api_capacidades.dart';
import 'package:reserva_canchas/features/mesa/presentation/mesa_pedidos_sheet.dart';
import 'package:reserva_canchas/features/mesa/data/mesas_repository.dart';
import 'package:reserva_canchas/features/admin/presentation/widgets/operacion_ui.dart';
import 'package:reserva_canchas/features/pedidos/presentation/pedido_cajero_screen.dart';
import 'package:reserva_canchas/core/realtime/foody_realtime.dart';
import 'package:reserva_canchas/features/usuarios/data/usuarios_repository.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Grid de mesas (Sprint 4) — colores por estado + aprobar/rechazar QR.
class MesasGridWidget extends StatefulWidget {
  const MesasGridWidget({
    super.key,
    this.sucursalId,
    this.modoMesero = false,
    this.modoCajero = false,
    this.meseraUsuarioId,
  }) : assert(
          !(modoMesero && modoCajero),
          'modoMesero y modoCajero son mutuamente excluyentes',
        );

  final String? sucursalId;
  final bool modoMesero;
  /// Cajero: pedir/cobrar en cualquier mesa sin turno ni asignación de mesera.
  final bool modoCajero;
  final String? meseraUsuarioId;

  @override
  State<MesasGridWidget> createState() => _MesasGridWidgetState();
}

class _MesasGridWidgetState extends State<MesasGridWidget> {
  final _pedidosRepo = PedidosRepository();
  final _mesasRepo = MesasRepository();
  final _usuariosRepo = UsuariosRepository();
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _mesasCache;
  RealtimeChannel? _canal;
  bool _pulso = true;
  Timer? _pulsoTimer;
  bool? _apiMesasOk;

  bool get _operacionPiso => widget.modoMesero || widget.modoCajero;

  @override
  void initState() {
    super.initState();
    _future = _cargarMesas();
    _comprobarApiMesas();
    _pulsoTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _pulso = !_pulso);
    });
    _suscribirRealtime();
  }

  @override
  void didUpdateWidget(MesasGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sucursalId != widget.sucursalId) {
      _canal?.unsubscribe();
      _canal = null;
      _mesasCache = null;
      _future = _cargarMesas();
      _suscribirRealtime();
    }
  }

  @override
  void dispose() {
    _canal?.unsubscribe();
    _pulsoTimer?.cancel();
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
              backgroundColor: ColoresFoody.primario,
              duration: Duration(seconds: 4),
            ),
          );
        }
        _recargarMesas();
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
    final ok = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'crear mesa'))),
        );
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
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('QR ${mesa['nombre']}'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enlace copiado')),
                );
              },
              child: const Text('Copiar enlace'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'QR'))),
        );
      }
    }
  }

  Future<void> _renombrarMesa(Map<String, dynamic> mesa) async {
    final sid = widget.sucursalId;
    if (sid == null) return;
    final ctrl = TextEditingController(text: '${mesa['nombre']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar mesa'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar mesa'),
        content: Text('¿Desactivar ${mesa['nombre']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desactivar')),
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
            SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'desactivar'))),
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
      text: DateTime.now().add(const Duration(hours: 2)).toString().substring(0, 16),
    );
    final ok = await showDialog<bool>(
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reservar')),
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
      await _mesasRepo.cancelarReserva(mesaId: '${mesa['id']}', sucursalId: sid);
      _recargarMesas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cancelar reserva'))),
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
    final ok = await showDialog<bool>(
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: seleccionadas.isEmpty ? null : () => Navigator.pop(ctx, true),
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
      return const Color(0xFF5C6BC0);
    }
    final estado = mesa['pedido_estado'] as String?;
    if (estado == 'pendiente_aprobacion') {
      return _pulso ? const Color(0xFFFF9800) : const Color(0xFFFFB74D);
    }
    if (estado != null) return ColoresFoody.primario;
    return const Color(0xFF639922);
  }

  Color _puntoEstado(Map<String, dynamic> mesa) => _bordeMesa(mesa);

  Future<void> _mostrarDetalleMesa(Map<String, dynamic> mesa) async {
    final estado = mesa['pedido_estado'] as String?;
    final pedidoId = mesa['pedido_id'] as String?;

    if (pedidoId == null && estado != 'pendiente_aprobacion') {
      await _accionMesaLibre(mesa);
      return;
    }

    if (estado == 'pendiente_aprobacion' && pedidoId != null) {
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
          onAgregarProductos: _operacionPiso
              ? (pedidoId) => _abrirPedidoMesa(mesa, pedidoIdAgregar: pedidoId)
              : null,
          onTransferir: () {
            Navigator.pop(ctx);
            _transferirMesa(mesa, pedidoId);
          },
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
    destino = await showDialog<Map<String, dynamic>>(
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
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'transferir mesa'))),
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
                leading: const Icon(Icons.add_shopping_cart, color: ColoresFoody.primario),
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
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cargar turno'))),
        );
      }
      return;
    }

    final asignaciones = {
      for (final m in mesas)
        m['id'] as String: m['mesera_asignada_id'] as String?,
    };

    final ok = await showDialog<bool>(
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
                              value: asignaciones[mesaId],
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
                onPressed: mesas.isEmpty ? null : () => Navigator.pop(ctx, true),
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
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'asignar turno'))),
        );
      }
    }
  }

  Future<void> _rechazarConMotivo(String pedidoId) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de rechazo'),
        content: TextField(controller: ctrl, maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isNotEmpty),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _pedidosRepo.rechazarMesa(
        pedidoId,
        motivo: ctrl.text.trim(),
        sucursalId: widget.sucursalId,
      );
      _recargarMesas();
    }
    ctrl.dispose();
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

  Widget? _bannerQrUrgente(List<Map<String, dynamic>> mesas) {
    final urgentes = _contarQrUrgentes(mesas);
    if (urgentes == 0) return null;
    return MaterialBanner(
      content: Text(
        urgentes == 1
            ? 'Hay 1 pedido QR esperando aprobacion (+3 min)'
            : 'Hay $urgentes pedidos QR esperando aprobacion (+3 min)',
      ),
      leading: const Icon(Icons.qr_code_scanner, color: ColoresFoody.primario),
      backgroundColor: ColoresFoody.acento.withValues(alpha: 0.35),
      actions: [
        TextButton(onPressed: _recargarMesas, child: const Text('Actualizar')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperacionPageHeader(
              titulo: 'Mesas',
              subtitulo: widget.sucursalId != null ? 'Salón' : null,
              acciones: [
                _leyenda(),
                if (!widget.modoMesero && !widget.modoCajero) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _asignarTurnoMesas,
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Turno mesas'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _crearMesa,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoresFoody.primario,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Mesa'),
                  ),
                ],
              ],
            ),
            if (_apiMesasOk == false)
              MaterialBanner(
                content: const Text(
                  'El API en ejecución es antiguo (falta crear mesa, QR, transferir). '
                  'Cierra la ventana del backend y ejecuta scripts\\iniciar-backend-wsl.bat hasta ver '
                  '"Nest application successfully started", luego recarga esta página.',
                ),
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                backgroundColor: Colors.orange.shade50,
                actions: [
                  TextButton(
                    onPressed: _comprobarApiMesas,
                    child: const Text('Revisar de nuevo'),
                  ),
                ],
              ),
            if (_mesasCache != null) ...[
              if (_bannerQrUrgente(_mesasCache!) != null)
                _bannerQrUrgente(_mesasCache!)!,
            ],
            Expanded(child: _grid()),
          ],
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statMesa('$libres', 'Libres', const Color(0xFF639922)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statMesa('$ocupadas', 'Ocupadas', ColoresFoody.primario),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statMesa('$qr', 'QR pendiente', const Color(0xFF185FA5)),
          ),
        ],
      ),
    );
  }

  Widget _statMesa(String num, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: OperacionUi.tarjeta(),
      child: Column(
        children: [
          Text(
            num,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: OperacionUi.textoTerciario),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        final mesas = snapshot.data ?? [];
        if (mesas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Sin mesas configuradas'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _crearMesa,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear primera mesa'),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _resumenMesas(mesas),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final f = _cargarMesas();
                  setState(() => _future = f);
                  await f;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: mesas.length,
                  itemBuilder: (context, index) {
                    final mesa = mesas[index];
                    final borde = _bordeMesa(mesa);
                    final ocupada = mesa['pedido_id'] != null;
                    return OperacionTarjeta(
                      acentoIzquierdo: borde,
                      onTap: () => _mostrarDetalleMesa(mesa),
                      onLongPress: _operacionPiso
                          ? null
                          : () => _opcionesMesa(mesa),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      mesa['nombre'] as String? ?? 'Mesa',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _puntoEstado(mesa),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              if (mesa['numero_pedido'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  mesa['numero_pedido'] as String,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: ColoresFoody.primario,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (mesa['mesera_nombre'] != null && ocupada)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 12),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          mesa['mesera_nombre'] as String,
                                          style: const TextStyle(fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const Spacer(),
                              if (_operacionPiso && !ocupada)
                                Text(
                                  widget.modoMesero
                                      ? 'Toca para pedir'
                                      : 'Toca para registrar',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                )
                              else if (!ocupada)
                                Text(
                                  mesa['estado_operativo'] == 'reservada'
                                      ? 'Reservada · ${mesa['reserva_cliente_nombre'] ?? ''}'
                                      : 'Libre',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mesa['estado_operativo'] == 'reservada'
                                        ? const Color(0xFF5C6BC0)
                                        : Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else
                                OutlinedButton(
                                  onPressed: () => _mostrarDetalleMesa(mesa),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Ver pedido', style: TextStyle(fontSize: 11)),
                                ),
                        ],
                      ),
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

  Widget _leyenda() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _puntoLeyenda(const Color(0xFF639922), 'Libre'),
        const SizedBox(width: 8),
        _puntoLeyenda(ColoresFoody.primario, 'Ocupada'),
        const SizedBox(width: 8),
        _puntoLeyenda(const Color(0xFF185FA5), 'QR'),
      ],
    );
  }

  Widget _puntoLeyenda(Color c, String t) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 11)),
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
                    ? ColoresFoody.error.withValues(alpha: 0.15)
                    : advertencia
                        ? ColoresFoody.acento.withValues(alpha: 0.35)
                        : ColoresFoody.grisSuave,
                borderRadius: BorderRadius.circular(12),
                border: urgente
                    ? Border.all(color: ColoresFoody.error, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: urgente ? ColoresFoody.error : ColoresFoody.primario,
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
                        color: urgente ? ColoresFoody.error : ColoresFoody.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: widget.onAprobar, child: const Text('Aprobar')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: widget.onRechazar, child: const Text('Rechazar')),
          ],
        ),
      ),
    );
  }
}
