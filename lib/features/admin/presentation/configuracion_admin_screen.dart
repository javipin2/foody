import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

/// Índice responsive a las configuraciones existentes del establecimiento.
/// El panel aplica permisos y conserva las rutas profundas de cada módulo.
class ConfiguracionAdminScreen extends StatelessWidget {
  const ConfiguracionAdminScreen({
    required this.permisos,
    required this.onAbrir,
    super.key,
  });

  final List<String> permisos;
  final ValueChanged<String> onAbrir;

  static const _opciones = <({
    String grupo,
    String ruta,
    String titulo,
    String detalle,
    IconData icono,
    String permiso,
  })>[
    (
      grupo: 'Negocio',
      ruta: 'sucursales',
      titulo: 'Establecimiento y sedes',
      detalle: 'Datos del negocio, marca y sucursales',
      icono: Icons.store_outlined,
      permiso: 'gestionar_sucursales',
    ),
    (
      grupo: 'Negocio',
      ruta: 'horarios',
      titulo: 'Horarios de atención',
      detalle: 'Disponibilidad de cada sucursal',
      icono: Icons.schedule_outlined,
      permiso: 'gestionar_sucursales',
    ),
    (
      grupo: 'Servicio',
      ruta: 'zonas',
      titulo: 'Domicilios y cobertura',
      detalle: 'Zonas y condiciones de entrega',
      icono: Icons.delivery_dining_outlined,
      permiso: 'gestionar_sucursales',
    ),
    (
      grupo: 'Servicio',
      ruta: 'cocinas',
      titulo: 'Cocinas e impresión',
      detalle: 'Estaciones y destino de comandas',
      icono: Icons.soup_kitchen_outlined,
      permiso: 'editar_productos',
    ),
    (
      grupo: 'Equipo',
      ruta: 'usuarios',
      titulo: 'Equipo y acceso',
      detalle: 'Usuarios y permisos del personal',
      icono: Icons.people_outline,
      permiso: 'gestionar_usuarios',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final opcionesVisibles =
        _opciones.where((opcion) => permisos.contains(opcion.permiso)).toList();
    final grupos = ['Negocio', 'Servicio', 'Equipo'];

    return ColoredBox(
      color: SaaSTokens.canvas(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < FoodyBreakpoints.compact
              ? SaaSTokens.s16
              : SaaSTokens.s24;
          final anchoContenido =
              (constraints.maxWidth - padding * 2).clamp(0.0, 1120.0);
          final columnas = anchoContenido >= FoodyBreakpoints.large
              ? 3
              : anchoContenido >= FoodyBreakpoints.expanded
                  ? 2
                  : 1;
          const espacio = SaaSTokens.s12;
          final anchoOpcion = columnas == 1
              ? anchoContenido
              : (anchoContenido - espacio * (columnas - 1)) / columnas;

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
            children: [
              Center(
                child: SizedBox(
                  width: anchoContenido,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuración',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: SaaSTokens.ink(context),
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: SaaSTokens.s4),
                      Text(
                        'Ajustes del establecimiento, el servicio y el equipo.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: SaaSTokens.inkMuted(context),
                            ),
                      ),
                      const SizedBox(height: SaaSTokens.s24),
                      if (opcionesVisibles.isEmpty)
                        Text(
                          'Tu perfil no tiene ajustes disponibles.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: SaaSTokens.inkMuted(context),
                                  ),
                        )
                      else
                        for (final grupo in grupos)
                          if (opcionesVisibles
                              .any((o) => o.grupo == grupo)) ...[
                            _EncabezadoGrupo(titulo: grupo),
                            const SizedBox(height: SaaSTokens.s8),
                            Wrap(
                              spacing: espacio,
                              runSpacing: espacio,
                              children: opcionesVisibles
                                  .where((o) => o.grupo == grupo)
                                  .map(
                                    (opcion) => SizedBox(
                                      width: anchoOpcion,
                                      child: _OpcionConfiguracion(
                                        titulo: opcion.titulo,
                                        detalle: opcion.detalle,
                                        icono: opcion.icono,
                                        onTap: () => onAbrir(opcion.ruta),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: SaaSTokens.s24),
                          ],
                      _AvisoMediosPago(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EncabezadoGrupo extends StatelessWidget {
  const _EncabezadoGrupo({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SaaSTokens.s4),
        child: Text(
          titulo,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: SaaSTokens.ink(context),
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _OpcionConfiguracion extends StatelessWidget {
  const _OpcionConfiguracion({
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.onTap,
  });

  final String titulo;
  final String detalle;
  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borde = SaaSTokens.borderSoft(context);
    return Material(
      color: SaaSTokens.surface(context),
      borderRadius: BorderRadius.circular(SaaSTokens.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.symmetric(
            horizontal: SaaSTokens.s16,
            vertical: SaaSTokens.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SaaSTokens.r12),
            border: Border.all(color: borde),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SaaSTokens.surfaceMuted(context),
                  borderRadius: BorderRadius.circular(SaaSTokens.r10),
                ),
                child: Icon(
                  icono,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: SaaSTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: SaaSTokens.ink(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: SaaSTokens.s4),
                    Text(
                      detalle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: SaaSTokens.inkMuted(context),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SaaSTokens.s8),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: SaaSTokens.inkSoft(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoMediosPago extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(SaaSTokens.s12),
        decoration: BoxDecoration(
          color: SaaSTokens.surfaceMuted(context),
          borderRadius: BorderRadius.circular(SaaSTokens.r10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: SaaSTokens.inkMuted(context),
            ),
            const SizedBox(width: SaaSTokens.s8),
            Expanded(
              child: Text(
                'La configuración central de medios de pago del establecimiento aún no está disponible. La suscripción de Foody se administra en Cuenta Foody.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SaaSTokens.inkMuted(context),
                    ),
              ),
            ),
          ],
        ),
      );
}
