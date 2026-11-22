import 'package:flutter/material.dart';
import 'package:reserva_canchas/core/saas_ui/saas_tokens.dart';

class SaaSFilterChip {
  const SaaSFilterChip({
    required this.id,
    required this.label,
    this.icono,
  });

  final String id;
  final String label;
  final IconData? icono;
}

/// Barra de presets + acciones (periodos, comparar, filtros).
class SaaSFilterBar extends StatelessWidget {
  const SaaSFilterBar({
    super.key,
    required this.presets,
    required this.selectedId,
    required this.onSelect,
    this.trailing = const [],
  });

  final List<SaaSFilterChip> presets;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in presets) ...[
            _Chip(
              label: p.label,
              selected: selectedId == p.id,
              icono: p.icono,
              onTap: () => onSelect(p.id),
            ),
            const SizedBox(width: 6),
          ],
          ...trailing,
        ],
      ),
    );
  }
}

class SaaSActionChip extends StatelessWidget {
  const SaaSActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icono,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final IconData? icono;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: label,
      selected: selected,
      icono: icono,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icono,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icono;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? SaaSTokens.ink(context).withValues(alpha: 0.08)
                : SaaSTokens.surface(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? SaaSTokens.ink(context).withValues(alpha: 0.25)
                  : SaaSTokens.border(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(
                  icono,
                  size: 14,
                  color: selected
                      ? SaaSTokens.ink(context)
                      : SaaSTokens.inkMuted(context),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? SaaSTokens.ink(context)
                      : SaaSTokens.inkMuted(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown compacto moderno.
class SaaSDropdown<T> extends StatelessWidget {
  const SaaSDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: SaaSTokens.surface(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SaaSTokens.border(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: width != null,
          value: value,
          hint: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: SaaSTokens.inkMuted(context),
            ),
          ),
          icon: Icon(
            Icons.expand_more,
            size: 18,
            color: SaaSTokens.inkMuted(context),
          ),
          style: TextStyle(
            fontSize: 12,
            color: SaaSTokens.ink(context),
            fontWeight: FontWeight.w600,
          ),
          dropdownColor: SaaSTokens.surface(context),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
