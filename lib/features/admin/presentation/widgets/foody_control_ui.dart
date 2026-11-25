import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/widgets/foody_dialogo.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';

/// Estilo compartido del panel Foody Control (super admin).
class FoodyControlUi {
  static const fondo = Color(0xFFF1F5F9);
  static const sidebar = Color(0xFF0F172A);
  static const sidebarCard = Color(0xFF1E293B);
  static const borde = Color(0xFF334155);

  static const secciones = [
    (id: 'resumen', titulo: 'Resumen', icono: Icons.insights_outlined),
    (
      id: 'restaurantes',
      titulo: 'Restaurantes',
      icono: Icons.storefront_outlined
    ),
    (id: 'planes', titulo: 'Planes', icono: Icons.card_membership_outlined),
    (id: 'usuarios', titulo: 'Usuarios', icono: Icons.people_outline_rounded),
    (id: 'ciudades', titulo: 'Ciudades', icono: Icons.location_city_outlined),
    (id: 'config', titulo: 'Configuración', icono: Icons.tune_outlined),
    (
      id: 'repartidores',
      titulo: 'Repartidores',
      icono: Icons.delivery_dining_outlined
    ),
  ];

  static const planes = ['basico', 'pro', 'enterprise'];
  static const estadosSuscripcion = [
    'prueba',
    'activa',
    'vencida',
    'bloqueada'
  ];

  static const rolesStaff = [
    ('admin', 'Administrador'),
    ('gerente', 'Gerente'),
    ('cajero', 'Cajero'),
    ('mesero', 'Mesero'),
    ('domiciliario_planta', 'Domiciliario planta'),
    ('cocina_principal', 'Cocina'),
  ];

  static String etiquetaPlan(String plan) {
    switch (plan) {
      case 'pro':
        return 'Pro';
      case 'enterprise':
        return 'Enterprise';
      default:
        return 'Básico';
    }
  }

  static String etiquetaEstado(String estado) {
    switch (estado) {
      case 'activa':
        return 'Activa';
      case 'vencida':
        return 'Vencida';
      case 'bloqueada':
        return 'Bloqueada';
      default:
        return 'Prueba';
    }
  }

  static Color colorEstado(String? estado) {
    switch (estado) {
      case 'activa':
        return ColoresFoody.exito;
      case 'prueba':
        return ColoresFoody.secundario;
      case 'vencida':
        return Colors.orange.shade800;
      case 'bloqueada':
        return ColoresFoody.error;
      default:
        return Colors.grey;
    }
  }
}

class FoodyControlTarjetaKpi extends StatelessWidget {
  const FoodyControlTarjetaKpi({
    super.key,
    required this.titulo,
    required this.valor,
    required this.icono,
    this.color,
    this.descripcion,
  });

  final String titulo;
  final String valor;
  final IconData icono;
  final Color? color;
  final String? descripcion;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ColoresFoody.primario;
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, color: c, size: 22),
              const SizedBox(height: 10),
              Text(
                titulo,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (descripcion != null) ...[
                const SizedBox(height: 6),
                Text(
                  descripcion!,
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FoodyControlChipEstado extends StatelessWidget {
  const FoodyControlChipEstado({
    super.key,
    required this.estado,
    this.plan,
  });

  final String? estado;
  final String? plan;

  @override
  Widget build(BuildContext context) {
    final e = estado ?? '—';
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Chip(
          label: Text(
            FoodyControlUi.etiquetaEstado(e),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          backgroundColor:
              FoodyControlUi.colorEstado(e).withValues(alpha: 0.12),
          side: BorderSide(
            color: FoodyControlUi.colorEstado(e).withValues(alpha: 0.35),
          ),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        if (plan != null)
          Chip(
            label: Text(
              FoodyControlUi.etiquetaPlan(plan!),
              style: const TextStyle(fontSize: 11),
            ),
            backgroundColor: ColoresFoody.primario.withValues(alpha: 0.08),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class FoodyControlBarraBusqueda extends StatelessWidget {
  const FoodyControlBarraBusqueda({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.acciones,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final List<Widget>? acciones;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hint,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
              ),
            ),
          ),
          if (acciones != null) ...[
            const SizedBox(width: 8),
            ...acciones!,
          ],
        ],
      ),
    );
  }
}

/// Overlay de carga bloqueante para operaciones lentas (crear restaurante).
Future<T?> foodyControlConCarga<T>(
  BuildContext context,
  Future<T> Function() operacion, {
  String mensaje = 'Procesando…',
}) async {
  FoodyDialogo.mostrar<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(mensaje)),
          ],
        ),
      ),
    ),
  );
  try {
    return await operacion();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
