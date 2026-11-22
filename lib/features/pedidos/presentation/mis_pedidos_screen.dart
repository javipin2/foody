import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/utilidades/parsear_numero.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_cliente_service.dart';
import 'package:reserva_canchas/features/pedidos/data/historial_pedidos_service.dart';
import 'package:reserva_canchas/features/pedidos/data/pedidos_cliente_repository.dart';
import 'package:reserva_canchas/features/pedidos/data/sesion_cliente_service.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
import 'package:reserva_canchas/features/pedidos/presentation/widgets/pedido_estado_pill.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:reserva_canchas/services/ciudad_preference_service.dart';

/// Historial de pedidos del dispositivo (+ nube si hay Google).
class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  final _repo = PedidosClienteRepository();
  List<Map<String, dynamic>> _pedidos = [];
  bool _cargando = true;
  bool _oauthBusy = false;
  String? _error;
  SesionClientePerfil? _sesion;

  final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );
  final _formatoFecha = DateFormat('d MMM yyyy · HH:mm', 'es_CO');

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _resolverOAuthSiAplica();
    await _refrescarSesion();
    await _cargar();
  }

  Future<void> _resolverOAuthSiAplica() async {
    final errorOAuth = GoogleOAuthClienteService.errorOAuthEnUrl();
    if (errorOAuth != null && errorOAuth.isNotEmpty) {
      await GoogleOAuthClienteService.limpiarMarcadoresOAuth();
      if (mounted) {
        GoogleOAuthClienteService.limpiarQueryOAuthEnRuta(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorOAuth)),
        );
      }
      return;
    }
    if (!await GoogleOAuthClienteService.hayRetornoOAuthPendiente()) return;
    if (!mounted) return;
    setState(() => _oauthBusy = true);
    try {
      final ok = await GoogleOAuthClienteService.procesarRetorno(context);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión guardada. Tus pedidos quedan en la nube.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'iniciar sesión')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _oauthBusy = false);
    }
  }

  Future<void> _refrescarSesion() async {
    final s = await SesionClienteService.obtener();
    if (mounted) setState(() => _sesion = s);
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final api = await _repo.listarMios();
      final local = await HistorialPedidosService.listarLocal();
      final fusion = _fusionar(api, local);
      if (!mounted) return;
      setState(() {
        _pedidos = fusion;
        _cargando = false;
      });
    } catch (e) {
      final local = await HistorialPedidosService.listarLocal();
      if (!mounted) return;
      setState(() {
        _pedidos = local;
        _cargando = false;
        _error =
            local.isEmpty ? mensajeErrorHttp(e, contexto: 'cargar pedidos') : null;
      });
    }
  }

  List<Map<String, dynamic>> _fusionar(
    List<Map<String, dynamic>> api,
    List<Map<String, dynamic>> local,
  ) {
    final mapa = <String, Map<String, dynamic>>{};
    for (final p in local) {
      final id = p['pedido_id'] as String?;
      if (id != null) mapa[id] = Map<String, dynamic>.from(p);
    }
    for (final p in api) {
      final id = p['id'] as String?;
      if (id == null) continue;
      final prev = mapa[id];
      mapa[id] = {
        'pedido_id': id,
        'numero_pedido': p['numero_pedido'],
        'estado': p['estado'],
        'tipo': p['tipo'],
        'total': p['total'],
        'sucursal_nombre': p['sucursal_nombre'],
        'created_at': p['created_at'],
        if (p['seguimiento_token'] != null)
          'seguimiento_token': p['seguimiento_token']
        else if (prev?['seguimiento_token'] != null)
          'seguimiento_token': prev!['seguimiento_token'],
      };
    }
    final lista = mapa.values.toList();
    lista.sort((a, b) {
      final da = DateTime.tryParse('${a['created_at']}') ?? DateTime(1970);
      final db = DateTime.tryParse('${b['created_at']}') ?? DateTime(1970);
      return db.compareTo(da);
    });
    return lista;
  }

  Future<void> _iniciarGoogle() async {
    if (!AppBackend.supabaseReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google no disponible: falta configurar Supabase.'),
        ),
      );
      return;
    }
    setState(() => _oauthBusy = true);
    try {
      await GoogleOAuthClienteService.iniciarOAuth();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'iniciar sesión')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _oauthBusy = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await GoogleOAuthClienteService.cerrarSesion();
    await _refrescarSesion();
    await _cargar();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión cerrada. Sigues viendo pedidos de este dispositivo.'),
        ),
      );
    }
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: AnaliticaTokens.surface,
      foregroundColor: AnaliticaTokens.ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: const Text(
        'Mis pedidos',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AnaliticaTokens.ink,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh, color: AnaliticaTokens.inkMuted),
          tooltip: 'Actualizar',
        ),
      ],
    );
  }

  Widget _bannerSesion() {
    if (_oauthBusy) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (_sesion != null) {
      final etiqueta = _sesion!.nombre?.trim().isNotEmpty == true
          ? _sesion!.nombre!
          : (_sesion!.email ?? 'Cuenta Google');
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AnaliticaTokens.surface,
            borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
            border: Border.all(color: AnaliticaTokens.border),
            boxShadow: AnaliticaTokens.shadowSoft,
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_outlined,
                  color: AnaliticaTokens.inventario, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AnaliticaTokens.ink,
                      ),
                    ),
                    const Text(
                      'Historial sincronizado en la nube',
                      style: TextStyle(
                        fontSize: 12,
                        color: AnaliticaTokens.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _cerrarSesion,
                child: const Text(
                  'Salir',
                  style: TextStyle(color: AnaliticaTokens.inkMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AnaliticaTokens.surface,
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          border: Border.all(color: AnaliticaTokens.border),
          boxShadow: AnaliticaTokens.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Guarda tu historial',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Inicia sesión con Google para ver tus pedidos en cualquier dispositivo.',
              style: TextStyle(
                fontSize: 13,
                color: AnaliticaTokens.inkMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _iniciarGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 22),
              label: const Text('Continuar con Google'),
              style: FilledButton.styleFrom(
                backgroundColor: AnaliticaTokens.ink,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FoodyScaffoldCliente(
      appBar: _appBar(),
      body: ColoredBox(
        color: AnaliticaTokens.canvas,
        child: RefreshIndicator(
          color: AnaliticaTokens.ink,
          onRefresh: () async {
            await _refrescarSesion();
            await _cargar();
          },
          child: _cargando
              ? FoodyEstadoUi.cargando(mensaje: 'Cargando pedidos…')
              : CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _bannerSesion()),
                    if (_pedidos.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            FoodyEstadoUi.vacio(
                              titulo: _error ?? 'Aún no tienes pedidos',
                              subtitulo:
                                  'Cuando ordenes, aparecerán aquí para que los revises cuando quieras.',
                              icono: Icons.receipt_long_outlined,
                              etiquetaAccion: 'Explorar restaurantes',
                              onAccion: () async {
                                final ruta = await CiudadPreferenceService
                                    .rutaHomeCliente();
                                if (context.mounted) context.go(ruta);
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: _pedidos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = _pedidos[i];
                            final id = p['pedido_id'] as String;
                            final numero =
                                p['numero_pedido'] as String? ?? id;
                            final estado = p['estado'] as String?;
                            final total = p['total'];
                            final fecha =
                                DateTime.tryParse('${p['created_at']}');
                            final token = p['seguimiento_token'] as String?;
                            final qs = token != null && token.isNotEmpty
                                ? '?token=$token'
                                : '';
                            return Material(
                              color: AnaliticaTokens.surface,
                              borderRadius:
                                  BorderRadius.circular(AnaliticaTokens.r12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(
                                  AnaliticaTokens.r12,
                                ),
                                onTap: () => context
                                    .push('/pedidos/$id/seguimiento$qs'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AnaliticaTokens.r12,
                                    ),
                                    border: Border.all(
                                      color: AnaliticaTokens.border,
                                    ),
                                    boxShadow: AnaliticaTokens.shadowSoft,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              numero,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AnaliticaTokens.ink,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                if (p['sucursal_nombre'] !=
                                                    null)
                                                  p['sucursal_nombre'],
                                                if (fecha != null)
                                                  _formatoFecha.format(
                                                    fecha.toLocal(),
                                                  ),
                                              ].join(' · '),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AnaliticaTokens.inkMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          if (total != null)
                                            Text(
                                              _formatoMoneda.format(
                                                parsearNumero(total),
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AnaliticaTokens.ink,
                                              ),
                                            ),
                                          if (estado != null) ...[
                                            const SizedBox(height: 6),
                                            PedidoEstadoPill(
                                              estado: estado,
                                              paraCliente: true,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
