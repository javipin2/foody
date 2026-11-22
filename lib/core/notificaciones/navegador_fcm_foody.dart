import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/main.dart' show appNavigatorKey;

/// Navegación al abrir una notificación FCM (deep link).
class NavegadorFcmFoody {
  NavegadorFcmFoody._();

  static void manejar(Map<String, dynamic> data) {
    Future<void> navegar() async {
      final pedidoId = data['pedido_id']?.toString();
      final mesaId = data['mesa_id']?.toString();
      var ruta = data['ruta']?.toString();
      final tipo = data['tipo']?.toString() ?? '';
      final staff = await SesionStaffService.cargar();
      final dash = staff?.dashboard;
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      if (ruta != null && ruta.isNotEmpty) {
        if (ruta.startsWith('/pedidos/') && ruta.contains('/seguimiento')) {
          ctx.push(ruta);
          return;
        }
        // Legacy `?tab=` → `?seccion=` o shell mesero (NAV-MS-33/35).
        if (ruta.contains('/admin/panel') &&
            (ruta.contains('tab=pedidos') || ruta.contains('seccion=pedidos'))) {
          if (dash == 'mesero') {
            final q = <String>[];
            if (pedidoId != null && pedidoId.isNotEmpty) {
              q.add('pedido_id=$pedidoId');
            }
            if (mesaId != null && mesaId.isNotEmpty) q.add('mesa_id=$mesaId');
            q.add('tab=pedidos');
            ctx.go('/admin/mesero?${q.join('&')}');
            return;
          }
          ruta = ruta
              .replaceFirst('?tab=', '?seccion=')
              .replaceFirst('&tab=', '&seccion=');
        }
        if (ruta == '/admin/mesero' || ruta.startsWith('/admin/mesero?')) {
          final uri = Uri.parse(ruta.startsWith('/') ? ruta : '/$ruta');
          final params = Map<String, String>.from(uri.queryParameters);
          if (mesaId != null &&
              mesaId.isNotEmpty &&
              !params.containsKey('mesa_id')) {
            params['mesa_id'] = mesaId;
          }
          if (pedidoId != null &&
              pedidoId.isNotEmpty &&
              !params.containsKey('pedido_id')) {
            params['pedido_id'] = pedidoId;
          }
          final q = params.entries.map((e) => '${e.key}=${e.value}').join('&');
          ctx.go(q.isEmpty ? '/admin/mesero' : '/admin/mesero?$q');
          return;
        }
        ctx.go(ruta);
        return;
      }

      if (pedidoId != null && pedidoId.isNotEmpty) {
        if (tipo.contains('cliente') ||
            tipo.contains('seguimiento') ||
            tipo == 'pedido_cliente') {
          ctx.push('/pedidos/$pedidoId/seguimiento');
          return;
        }
        if (dash == 'mesero') {
          final q = <String>['tab=pedidos', 'pedido_id=$pedidoId'];
          if (mesaId != null && mesaId.isNotEmpty) q.add('mesa_id=$mesaId');
          ctx.go('/admin/mesero?${q.join('&')}');
          return;
        }
        ctx.go('/admin/panel?seccion=pedidos&pedido_id=$pedidoId');
        return;
      }

      if (tipo.contains('cocina') ||
          tipo.contains('kds') ||
          tipo == 'pedido_cocina') {
        ctx.go('/admin/cocina');
        return;
      }
      if (tipo.contains('mesero') ||
          tipo.contains('qr_pendiente') ||
          tipo == 'llamar_mesera') {
        final q = <String>[];
        if (mesaId != null && mesaId.isNotEmpty) q.add('mesa_id=$mesaId');
        ctx.go(q.isEmpty ? '/admin/mesero' : '/admin/mesero?${q.join('&')}');
        return;
      }
      if (tipo.contains('oferta') || tipo == 'oferta_domicilio') {
        ctx.go('/domiciliario/independiente');
        return;
      }
      // NAV-DP-01: planta ≠ independiente.
      if (tipo.contains('domiciliario') || tipo.contains('domicilio')) {
        if (dash == 'domiciliario_independiente') {
          ctx.go('/domiciliario/independiente');
          return;
        }
        final q = <String>[];
        if (pedidoId != null && pedidoId.isNotEmpty) {
          q.add('pedido_id=$pedidoId');
        }
        ctx.go(
          q.isEmpty
              ? '/admin/domiciliario'
              : '/admin/domiciliario?${q.join('&')}',
        );
        return;
      }
      if (tipo.startsWith('alerta_riesgo_')) {
        ctx.go('/admin/panel?seccion=alertas');
      }
    }

    if (appNavigatorKey.currentContext != null) {
      unawaited(navegar());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        unawaited(navegar());
      });
    });
  }
}
