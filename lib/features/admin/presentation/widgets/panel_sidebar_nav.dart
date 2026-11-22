import 'dart:async';

import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/layout/foody_breakpoints.dart';
import 'package:reserva_canchas/core/preferencias/panel_favoritos_service.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_grupo.dart';
import 'package:reserva_canchas/features/admin/domain/menu_admin_item.dart';

/// Sidebar admin con acordeones por categoría — móvil, tablet y escritorio.
class PanelSidebarNav extends StatefulWidget {
  const PanelSidebarNav({
    super.key,
    required this.grupos,
    required this.seccionActiva,
    required this.onSeleccionar,
    this.anchoCompacto = false,
    this.nombreUsuario,
    this.nombreSucursal,
  });

  final List<({MenuAdminGrupo grupo, List<MenuAdminItem> items})> grupos;
  final String seccionActiva;
  final ValueChanged<String> onSeleccionar;
  final bool anchoCompacto;
  final String? nombreUsuario;
  final String? nombreSucursal;

  @override
  State<PanelSidebarNav> createState() => _PanelSidebarNavState();
}

class _PanelSidebarNavState extends State<PanelSidebarNav> {
  static const _fondo = Color(0xFF0F172A);
  static const _superficie = Color(0xFF1E293B);
  static const _borde = Color(0xFF334155);
  // Activo neutro (sin naranja chrome); logo sigue con marca Foody.
  static const _activoBarra = Color(0xFFF8FAFC);
  static final _activoFondo = Colors.white.withValues(alpha: 0.10);
  static final _activoBorde = Colors.white.withValues(alpha: 0.18);
  static final _estrella = Colors.white.withValues(alpha: 0.55);

  late Set<String> _expandidos;
  List<String> _favoritos = [];

  @override
  void initState() {
    super.initState();
    _expandidos = _expansionInicial();
    unawaited(_cargarFavoritos());
  }

  Future<void> _cargarFavoritos() async {
    final f = await PanelFavoritosService.listar();
    if (mounted) setState(() => _favoritos = f);
  }

  Future<void> _toggleFavorito(String ruta) async {
    final agregado = await PanelFavoritosService.alternar(ruta);
    await _cargarFavoritos();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          agregado ? 'Añadido a favoritos' : 'Quitado de favoritos',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  MenuAdminItem? _itemPorRuta(String ruta) {
    for (final g in widget.grupos) {
      for (final item in g.items) {
        if (item.ruta == ruta) return item;
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(PanelSidebarNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seccionActiva != widget.seccionActiva) {
      final gid = MenuAdminGrupoData.grupoIdParaRuta(widget.seccionActiva);
      if (gid != null) {
        _expandidos.add(gid);
      }
    }
  }

  Set<String> _expansionInicial() {
    final gid = MenuAdminGrupoData.grupoIdParaRuta(widget.seccionActiva);
    if (gid == null) return {'inicio', 'operacion'};
    return {gid};
  }

  void _toggleGrupo(String id, {required bool soloUno}) {
    setState(() {
      if (_expandidos.contains(id)) {
        _expandidos.remove(id);
      } else {
        if (soloUno) _expandidos.clear();
        _expandidos.add(id);
      }
    });
  }

  void _ir(String ruta) {
    widget.onSeleccionar(ruta);
    final gid = MenuAdminGrupoData.grupoIdParaRuta(ruta);
    if (gid != null) {
      setState(() => _expandidos.add(gid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final compacto = widget.anchoCompacto;
    final soloUnGrupo = compacto;

    return Material(
      color: _fondo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cabecera(compacto),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                compacto ? 8 : 10,
                6,
                compacto ? 8 : 10,
                12,
              ),
              children: [
                if (_favoritos.isNotEmpty)
                  compacto
                      ? _bloqueFavoritosCompacto()
                      : _bloqueFavoritos(),
                for (final g in widget.grupos)
                  _grupoAcordeon(
                    g.grupo,
                    g.items,
                    compacto: compacto,
                    soloUnGrupo: soloUnGrupo,
                  ),
              ],
            ),
          ),
          if (!compacto) _pie(),
        ],
      ),
    );
  }

  Widget _bloqueFavoritos() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  size: 14,
                  color: _estrella,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Favoritos',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final ruta in _favoritos)
            if (_itemPorRuta(ruta) != null)
              _itemHijo(
                _itemPorRuta(ruta)!,
                seleccionado: ruta == widget.seccionActiva,
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Text(
              'Toca ★ en un módulo para fijarlo (máx. ${PanelFavoritosService.maxFavoritos})',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rail tablet: solo iconos de favoritos (NAV-ADM-01).
  Widget _bloqueFavoritosCompacto() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Tooltip(
            message: 'Favoritos — mantén pulsado para quitar',
            child: Icon(
              Icons.star_rounded,
              size: 16,
              color: _estrella,
            ),
          ),
          const SizedBox(height: 6),
          for (final ruta in _favoritos)
            if (_itemPorRuta(ruta) != null)
              _favoritoCompacto(_itemPorRuta(ruta)!),
          const SizedBox(height: 4),
          Divider(color: _borde.withValues(alpha: 0.8), height: 12),
        ],
      ),
    );
  }

  Widget _favoritoCompacto(MenuAdminItem item) {
    final sel = item.ruta == widget.seccionActiva;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tooltip(
        message: '${item.titulo} — mantén pulsado para quitar',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _ir(item.ruta),
            onLongPress: () => _toggleFavorito(item.ruta),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _activoFondo : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: sel ? Border.all(color: _activoBorde) : null,
              ),
              child: Icon(
                item.bloqueadoPorPlan ? Icons.lock_outline : item.icono,
                size: 22,
                color: sel
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _esFavorito(String ruta) => _favoritos.contains(ruta);

  Widget _cabecera(bool compacto) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compacto ? 10 : 14,
        compacto ? 12 : 14,
        compacto ? 10 : 14,
        compacto ? 10 : 12,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borde, width: 1)),
      ),
      child: compacto
          ? Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: ColoresFoody.primario,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 20),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: ColoresFoody.primario,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Foody',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'Panel restaurante',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.nombreSucursal != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _superficie,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borde),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.nombreSucursal!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _grupoAcordeon(
    MenuAdminGrupo grupo,
    List<MenuAdminItem> items, {
    required bool compacto,
    required bool soloUnGrupo,
  }) {
    final expandido = _expandidos.contains(grupo.id);
    final tieneActivo = items.any((i) => i.ruta == widget.seccionActiva);
    final unSoloItem = items.length == 1;

    if (unSoloItem && grupo.id == 'inicio') {
      return _itemPlano(items.first, compacto: compacto);
    }

    if (compacto) {
      return _grupoCompacto(grupo, items, expandido: expandido);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tieneActivo
              ? _activoFondo
              : _superficie.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tieneActivo ? _activoBorde : _borde.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleGrupo(grupo.id, soloUno: soloUnGrupo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    Icon(
                      grupo.icono,
                      size: 20,
                      color: tieneActivo
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grupo.titulo,
                            style: TextStyle(
                              color: tieneActivo
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            grupo.subtitulo,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandido ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Column(
                  children: [
                    for (final item in items)
                      _itemHijo(
                        item,
                        seleccionado: item.ruta == widget.seccionActiva,
                      ),
                  ],
                ),
              ),
              crossFadeState: expandido
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupoCompacto(
    MenuAdminGrupo grupo,
    List<MenuAdminItem> items, {
    required bool expandido,
  }) {
    final tieneActivo = items.any((i) => i.ruta == widget.seccionActiva);

    return PopupMenuButton<String>(
      tooltip: grupo.titulo,
      offset: const Offset(72, 0),
      color: _superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _borde),
      ),
      onSelected: _ir,
      itemBuilder: (menuCtx) => items
          .map(
            (item) {
              final fav = _esFavorito(item.ruta);
              return PopupMenuItem<String>(
                value: item.ruta,
                child: Row(
                  children: [
                    Icon(
                      item.bloqueadoPorPlan ? Icons.lock_outline : item.icono,
                      size: 18,
                      color: item.ruta == widget.seccionActiva
                          ? Colors.white
                          : item.bloqueadoPorPlan
                              ? Colors.white38
                              : Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.titulo,
                        style: TextStyle(
                          color: item.ruta == widget.seccionActiva
                              ? Colors.white
                              : item.bloqueadoPorPlan
                                  ? Colors.white54
                                  : Colors.white,
                          fontWeight: item.ruta == widget.seccionActiva
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    // Evita disparar onSelected al pinnear.
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(menuCtx);
                        unawaited(_toggleFavorito(item.ruta));
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          fav ? Icons.star_rounded : Icons.star_border_rounded,
                          size: 20,
                          color: fav
                              ? Colors.white.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
          .toList(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: tieneActivo ? _activoFondo : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: tieneActivo ? Border.all(color: _activoBorde) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              grupo.icono,
              color: tieneActivo ? Colors.white : Colors.white60,
              size: 22,
            ),
            if (tieneActivo)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: _activoBarra,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _itemPlano(MenuAdminItem item, {required bool compacto}) {
    final sel = item.ruta == widget.seccionActiva;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _tile(
        item: item,
        seleccionado: sel,
        compacto: compacto,
        onTap: () => _ir(item.ruta),
      ),
    );
  }

  Widget _itemHijo(MenuAdminItem item, {required bool seleccionado}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _tile(
        item: item,
        seleccionado: seleccionado,
        compacto: false,
        indent: true,
        onTap: () => _ir(item.ruta),
      ),
    );
  }

  Widget _tile({
    required MenuAdminItem item,
    required bool seleccionado,
    required bool compacto,
    required VoidCallback onTap,
    bool indent = false,
  }) {
    final bloqueado = item.bloqueadoPorPlan;
    final fav = _esFavorito(item.ruta);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _toggleFavorito(item.ruta),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: indent ? 10 : (compacto ? 8 : 12),
            vertical: indent ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: seleccionado
                ? (bloqueado
                    ? Colors.white.withValues(alpha: 0.06)
                    : _activoFondo)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: seleccionado ? Border.all(color: _activoBorde) : null,
          ),
          child: Row(
            children: [
              if (seleccionado && indent)
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _activoBarra,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(
                bloqueado ? Icons.lock_outline : item.icono,
                size: indent ? 18 : 20,
                color: bloqueado
                    ? Colors.white.withValues(alpha: 0.35)
                    : seleccionado
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
              ),
              if (!compacto) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: bloqueado
                          ? Colors.white.withValues(alpha: 0.45)
                          : seleccionado
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.78),
                      fontWeight:
                          seleccionado ? FontWeight.w600 : FontWeight.w500,
                      fontSize: indent ? 13 : 14,
                    ),
                  ),
                ),
                Tooltip(
                  message: fav
                      ? 'Quitar de favoritos'
                      : 'Añadir a favoritos',
                  child: InkWell(
                    onTap: () => _toggleFavorito(item.ruta),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        fav ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: fav
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pie() {
    final nombre = widget.nombreUsuario;
    if (nombre == null || nombre.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _borde)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Breakpoints del panel admin — delegan en [FoodyBreakpoints] (RS-20).
class PanelLayoutBreakpoints {
  static const movil = FoodyBreakpoints.expanded;
  static const tablet = FoodyBreakpoints.large;

  static bool esMovil(double ancho) => FoodyBreakpoints.esCompact(ancho);
  static bool esTablet(double ancho) =>
      FoodyBreakpoints.esExpanded(ancho) && !FoodyBreakpoints.esLarge(ancho);
  static bool esEscritorio(double ancho) => FoodyBreakpoints.esLarge(ancho);

  static double anchoSidebar(double ancho) {
    if (esMovil(ancho)) return ancho * 0.85;
    if (esTablet(ancho)) return 72;
    return 272;
  }
}
