import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
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

  late Set<String> _expandidos;

  @override
  void initState() {
    super.initState();
    _expandidos = _expansionInicial();
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
                compacto ? 8 : 12,
                8,
                compacto ? 8 : 12,
                16,
              ),
              children: [
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

  Widget _cabecera(bool compacto) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compacto ? 12 : 16,
        compacto ? 16 : 20,
        compacto ? 12 : 16,
        compacto ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _borde, width: 1)),
      ),
      child: compacto
          ? Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ColoresFoody.primario,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.restaurant, color: Colors.white, size: 22),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ColoresFoody.primario,
                            ColoresFoody.primario.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Colors.white,
                        size: 20,
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
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Panel restaurante',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.nombreSucursal != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
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
                          color: ColoresFoody.secundario.withValues(alpha: 0.9),
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
              ? ColoresFoody.primario.withValues(alpha: 0.06)
              : _superficie.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tieneActivo
                ? ColoresFoody.primario.withValues(alpha: 0.25)
                : _borde.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleGrupo(grupo.id, soloUno: soloUnGrupo),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Icon(
                      grupo.icono,
                      size: 20,
                      color: tieneActivo
                          ? ColoresFoody.primario
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
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem<String>(
              value: item.ruta,
              child: Row(
                children: [
                  Icon(
                    item.bloqueadoPorPlan ? Icons.lock_outline : item.icono,
                    size: 18,
                    color: item.ruta == widget.seccionActiva
                        ? ColoresFoody.primario
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
                            ? ColoresFoody.primario
                            : item.bloqueadoPorPlan
                                ? Colors.white54
                                : Colors.white,
                        fontWeight: item.ruta == widget.seccionActiva
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: tieneActivo
              ? ColoresFoody.primario.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              grupo.icono,
              color: tieneActivo ? ColoresFoody.primario : Colors.white60,
              size: 22,
            ),
            if (tieneActivo)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: ColoresFoody.primario,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: indent ? 10 : (compacto ? 8 : 12),
            vertical: indent ? 9 : 11,
          ),
          decoration: BoxDecoration(
            color: seleccionado
                ? ColoresFoody.primario.withValues(alpha: bloqueado ? 0.12 : 0.22)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: seleccionado
                ? Border.all(
                    color: ColoresFoody.primario.withValues(alpha: 0.35),
                  )
                : null,
          ),
          child: Row(
            children: [
              if (seleccionado && indent)
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: ColoresFoody.primario,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Icon(
                bloqueado ? Icons.lock_outline : item.icono,
                size: indent ? 18 : 20,
                color: bloqueado
                    ? Colors.white.withValues(alpha: 0.35)
                    : seleccionado
                        ? ColoresFoody.primario
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
            backgroundColor: ColoresFoody.secundario.withValues(alpha: 0.25),
            child: Text(
              nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
              style: const TextStyle(
                color: ColoresFoody.secundario,
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

/// Breakpoints del panel admin.
class PanelLayoutBreakpoints {
  static const movil = 720.0;
  static const tablet = 1100.0;

  static bool esMovil(double ancho) => ancho < movil;
  static bool esTablet(double ancho) => ancho >= movil && ancho < tablet;
  static bool esEscritorio(double ancho) => ancho >= tablet;

  static double anchoSidebar(double ancho) {
    if (esMovil(ancho)) return ancho * 0.85;
    if (esTablet(ancho)) return 72;
    return 272;
  }
}
