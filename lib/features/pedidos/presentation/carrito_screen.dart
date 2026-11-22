import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/tema/foody_formato.dart';
import 'package:reserva_canchas/core/widgets/foody_estado_ui.dart';
import 'package:reserva_canchas/core/widgets/foody_pasos_pedido.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/cliente/presentation/foody_scaffold_cliente.dart';
import 'package:reserva_canchas/features/pedidos/domain/linea_carrito.dart';
import 'package:reserva_canchas/features/pedidos/providers/carrito_provider.dart';

class CarritoScreen extends ConsumerWidget {
  const CarritoScreen({
    super.key,
    required this.sucursalId,
    required this.sucursalNombre,
    this.mesaId,
    this.mesaNombre,
  });

  final String sucursalId;
  final String sucursalNombre;
  final String? mesaId;
  final String? mesaNombre;

  void _irCheckout(BuildContext context) {
    var q = 'sucursalNombre=${Uri.encodeComponent(sucursalNombre)}';
    if (mesaId != null) {
      q += '&mesa_id=$mesaId';
      if (mesaNombre != null) {
        q += '&mesa_nombre=${Uri.encodeComponent(mesaNombre!)}';
      }
    }
    context.push('/checkout/$sucursalId?$q');
  }

  Future<void> _confirmarVaciar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Vaciar carrito?'),
        content: const Text('Se quitarán todos los productos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      HapticFeedback.mediumImpact();
      ref.read(carritoProvider.notifier).limpiar();
    }
  }

  void _mostrarDetalle(
    BuildContext context,
    WidgetRef ref,
    LineaCarrito linea,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DetalleLineaSheet(
        linea: linea,
        onQuitar: () {
          ref.read(carritoProvider.notifier).eliminarLinea(linea.clave);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final carrito = ref.watch(carritoProvider);
    final notifier = ref.read(carritoProvider.notifier);
    final lineas = carrito.lineas.values.toList();

    return FoodyScaffoldCliente(
      mostrarNavInferior: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Carrito',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              sucursalNombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: carrito.lineas.isEmpty
            ? null
            : [
                TextButton(
                  onPressed: () => _confirmarVaciar(context, ref),
                  child: Text(
                    'Vaciar',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
      ),
      body: ColoredBox(
        color: AnaliticaTokens.canvasOf(context),
        child: carrito.lineas.isEmpty
            ? FoodyEstadoUi.vacio(
                titulo: 'Tu carrito está vacío',
                subtitulo: 'Agrega platos desde el menú',
                icono: Icons.shopping_bag_outlined,
                etiquetaAccion: 'Ver menú',
                onAccion: () => context.pop(),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      const FoodyPasosPedido(pasoActual: 1),
                      Text(
                        'Toca un ítem para ver qué incluye. Desliza para quitarlo.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < lineas.length; i++)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                            milliseconds: 180 + (i.clamp(0, 6) * 30),
                          ),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) {
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 8 * (1 - t)),
                                child: child,
                              ),
                            );
                          },
                          child: Dismissible(
                            key: ValueKey(lineas[i].clave),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AnaliticaTokens.alertas
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AnaliticaTokens.r12),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: AnaliticaTokens.alertas,
                              ),
                            ),
                            onDismissed: (_) {
                              HapticFeedback.mediumImpact();
                              notifier.eliminarLinea(lineas[i].clave);
                            },
                            child: _LineaCarritoCard(
                              linea: lineas[i],
                              onTap: () =>
                                  _mostrarDetalle(context, ref, lineas[i]),
                              onMenos: () {
                                HapticFeedback.selectionClick();
                                notifier.quitarUno(lineas[i].clave);
                              },
                              onMas: () {
                                HapticFeedback.selectionClick();
                                notifier.agregarUno(lineas[i].clave);
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      bottomBar: carrito.lineas.isEmpty
          ? null
          : Material(
              elevation: 0,
              color: scheme.surface,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${carrito.totalItems} ${carrito.totalItems == 1 ? 'producto' : 'productos'}',
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                FoodyFormato.monedaDe(carrito.totalPrecio),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AnaliticaTokens.r12),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _irCheckout(context);
                            },
                            child: const Text(
                              'Continuar al checkout',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _LineaCarritoCard extends StatelessWidget {
  const _LineaCarritoCard({
    required this.linea,
    required this.onTap,
    required this.onMenos,
    required this.onMas,
  });

  final LineaCarrito linea;
  final VoidCallback onTap;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = <String>[
      if (linea.toppings.isNotEmpty)
        linea.toppings.map((t) => t.nombre).join(', '),
      if (linea.bebidas.isNotEmpty)
        linea.bebidas.map((b) => b.nombre).join(', '),
    ];
    final previewIncluye = (linea.detalleIncluye ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AnaliticaTokens.r12),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: AnaliticaTokens.shadowSoft,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                linea.nombre,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: scheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                linea.etiquetaTipoResuelta,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (previewIncluye.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            previewIncluye,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.25,
                            ),
                          ),
                        ],
                        if (extras.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '+ ${extras.join(' · ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              FoodyFormato.monedaDe(linea.subtotal),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ver detalle',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Evita que el tap del qty abra el sheet.
                  GestureDetector(
                    onTap: () {},
                    child: _QtyPill(
                      cantidad: linea.cantidad,
                      onMenos: onMenos,
                      onMas: onMas,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({
    required this.cantidad,
    required this.onMenos,
    required this.onMas,
  });

  final int cantidad;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove_rounded, onTap: onMenos, filled: false),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                '$cantidad',
                key: ValueKey(cantidad),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add_rounded, onTap: onMas, filled: true),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? scheme.primary : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: filled ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _DetalleLineaSheet extends StatelessWidget {
  const _DetalleLineaSheet({
    required this.linea,
    required this.onQuitar,
  });

  final LineaCarrito linea;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final incluye = (linea.detalleIncluye ?? '').trim();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              linea.nombre,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                linea.etiquetaTipoResuelta,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (linea.imagenUrl != null &&
                          linea.imagenUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AnaliticaTokens.r12),
                          child: CachedNetworkImage(
                            imageUrl: linea.imagenUrl!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                  if (incluye.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      'Incluye',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...incluye.split(' · ').map(
                          (part) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 18,
                                  color: scheme.primary.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    part.trim(),
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                  if (linea.toppings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Extras',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...linea.toppings.map(
                      (t) => _FilaPrecio(
                        nombre: t.nombre,
                        precio: t.precio * linea.cantidad,
                        nota: linea.cantidad > 1
                            ? '${FoodyFormato.monedaDe(t.precio)} × ${linea.cantidad}'
                            : null,
                      ),
                    ),
                  ],
                  if (linea.bebidas.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Bebidas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...linea.bebidas.map(
                      (b) => _FilaPrecio(
                        nombre: b.cantidad > 1
                            ? '${b.nombre} × ${b.cantidad}'
                            : b.nombre,
                        precio: b.precio * b.cantidad,
                      ),
                    ),
                  ],
                  if ((linea.observaciones ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Observaciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      linea.observaciones!.trim(),
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 10),
                  _FilaPrecio(
                    nombre:
                        'Base × ${linea.cantidad} (${FoodyFormato.monedaDe(linea.precioUnitario)} c/u)',
                    precio: linea.precioUnitario * linea.cantidad,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        FoodyFormato.monedaDe(linea.subtotal),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onQuitar();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AnaliticaTokens.alertas,
                      side: const BorderSide(color: AnaliticaTokens.alertas),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r12),
                      ),
                    ),
                    child: const Text(
                      'Quitar del carrito',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaPrecio extends StatelessWidget {
  const _FilaPrecio({
    required this.nombre,
    required this.precio,
    this.nota,
  });

  final String nombre;
  final double precio;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (nota != null)
                  Text(
                    nota!,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            FoodyFormato.monedaDe(precio),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
