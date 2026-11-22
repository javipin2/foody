import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

class SaaSTableColumn {
  const SaaSTableColumn({
    required this.id,
    required this.label,
    this.flex = 1,
    this.numeric = false,
  });

  final String id;
  final String label;
  final int flex;
  final bool numeric;
}

/// Tabla moderna → cards en móvil (&lt;768).
class SaaSResponsiveTable extends StatelessWidget {
  const SaaSResponsiveTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.rowActions,
    this.breakpoint = 768,
  });

  final List<SaaSTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final ValueChanged<Map<String, dynamic>>? onRowTap;
  final Widget Function(Map<String, dynamic> row)? rowActions;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < breakpoint) {
          return Column(
            children: [
              for (final row in rows) ...[
                _MobileCard(
                  columns: columns,
                  row: row,
                  onTap: onRowTap == null ? null : () => onRowTap!(row),
                  actions: rowActions?.call(row),
                ),
                const SizedBox(height: 8),
              ],
            ],
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(SaaSTokens.r12),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    for (final col in columns)
                      Expanded(
                        flex: col.flex,
                        child: Text(
                          col.label,
                          textAlign:
                              col.numeric ? TextAlign.end : TextAlign.start,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SaaSTokens.inkMuted(context),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    if (rowActions != null) const SizedBox(width: 72),
                  ],
                ),
              ),
              Divider(height: 1, color: SaaSTokens.borderSoft(context)),
              for (var i = 0; i < rows.length; i++)
                _DesktopRow(
                  columns: columns,
                  row: rows[i],
                  onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
                  actions: rowActions?.call(rows[i]),
                  last: i == rows.length - 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopRow extends StatefulWidget {
  const _DesktopRow({
    required this.columns,
    required this.row,
    required this.last,
    this.onTap,
    this.actions,
  });

  final List<SaaSTableColumn> columns;
  final Map<String, dynamic> row;
  final bool last;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  State<_DesktopRow> createState() => _DesktopRowState();
}

class _DesktopRowState extends State<_DesktopRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hover
                ? SaaSTokens.surfaceMuted(context)
                : Colors.transparent,
            border: widget.last
                ? null
                : Border(
                    bottom: BorderSide(color: SaaSTokens.borderSoft(context)),
                  ),
          ),
          child: Row(
            children: [
              for (final col in widget.columns)
                Expanded(
                  flex: col.flex,
                  child: Text(
                    '${widget.row[col.id] ?? '—'}',
                    textAlign: col.numeric ? TextAlign.end : TextAlign.start,
                    style: TextStyle(
                      fontSize: 13,
                      color: SaaSTokens.ink(context),
                      fontWeight:
                          col.numeric ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.actions != null) widget.actions!,
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileCard extends StatelessWidget {
  const _MobileCard({
    required this.columns,
    required this.row,
    this.onTap,
    this.actions,
  });

  final List<SaaSTableColumn> columns;
  final Map<String, dynamic> row;
  final VoidCallback? onTap;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SaaSTokens.surface(context),
      borderRadius: BorderRadius.circular(SaaSTokens.r12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SaaSTokens.r12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SaaSTokens.r12),
            border: Border.all(color: SaaSTokens.borderSoft(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final col in columns) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        col.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: SaaSTokens.inkMuted(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${row[col.id] ?? '—'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: SaaSTokens.ink(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              if (actions != null) ...[
                const SizedBox(height: 4),
                Align(alignment: Alignment.centerRight, child: actions!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de estado discreto.
class SaaSStatusChip extends StatelessWidget {
  const SaaSStatusChip({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SaaSTokens.inkMuted(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}
