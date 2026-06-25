import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reserva_canchas/models/config_lugar.dart';
import 'package:reserva_canchas/providers/sede_provider.dart';
import 'package:reserva_canchas/services/config_lugar_service.dart';
import 'package:reserva_canchas/services/lugar_helper.dart';

/// Pantalla de configuración del lugar: horarios de actividad (L-D), WhatsApp y cuentas.
/// Para admin usa el lugar del usuario; para superadmin permite elegir lugar.
class ConfigLugarScreen extends StatefulWidget {
  const ConfigLugarScreen({super.key});

  @override
  State<ConfigLugarScreen> createState() => _ConfigLugarScreenState();
}

class _ConfigLugarScreenState extends State<ConfigLugarScreen> {
  // ── Paleta monocromática (resto de tonos en widgets hijos) ────────────────
  static const _ink = Color(0xFF0A0A0A);

  String? _lugarId;
  bool _loadingLugar = true;
  bool _loadingConfig = true;
  bool _saving = false;
  ConfigLugar _config = ConfigLugar();
  final _formKey = GlobalKey<FormState>();
  final _whatsappController = TextEditingController();
  final _cuentasController = TextEditingController();
  final Map<String, TextEditingController> _whatsappPorSede = {};
  final Map<String, TextEditingController> _cuentasPorSede = {};
  bool _usarMismaInfoParaTodas = false;
  final List<String> _nombresDias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  EdgeInsets _pagePaddingForWidth(double width) {
    if (width < 520) return const EdgeInsets.all(14);
    if (width < 900) return const EdgeInsets.all(20);
    return const EdgeInsets.symmetric(horizontal: 28, vertical: 24);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final lugarId = await LugarHelper.getLugarId();
    if (!mounted) return;
    setState(() {
      _lugarId = lugarId;
      _loadingLugar = false;
    });
    if (lugarId != null && lugarId.isNotEmpty) {
      final sedeProv = context.read<SedeProvider>();
      sedeProv.setLugar(lugarId);
      await sedeProv.fetchSedes();
      await _cargarConfig(lugarId);
    } else {
      setState(() => _loadingConfig = false);
    }
  }

  Future<void> _cargarConfig(String lugarId) async {
    setState(() => _loadingConfig = true);
    final config = await ConfigLugarService.getConfig(lugarId);
    if (!mounted) return;
    setState(() {
      _config = config;
      _whatsappController.text = config.whatsappReservas;
      _cuentasController.text = config.textoCuentasReservas;
      _loadingConfig = false;
    });
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    _cuentasController.dispose();
    for (final c in _whatsappPorSede.values) c.dispose();
    for (final c in _cuentasPorSede.values) c.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_lugarId == null || _lugarId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un lugar para guardar')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final sedes = context.read<SedeProvider>().sedes;

    final Map<String, ConfigContactoSede> contactosPorSede = {};
    if (_usarMismaInfoParaTodas) {
      final wsp = _whatsappController.text.trim();
      final txt = _cuentasController.text.trim();
      for (final sede in sedes) {
        final sedeId = sede['id'] as String;
        contactosPorSede[sedeId] = ConfigContactoSede(whatsapp: wsp, textoCuentas: txt);
      }
    } else {
      for (final sede in sedes) {
        final sedeId = sede['id'] as String;
        final wsp = _whatsappPorSede[sedeId]?.text.trim() ?? _whatsappController.text.trim();
        final txt = _cuentasPorSede[sedeId]?.text.trim() ?? _cuentasController.text.trim();
        if (wsp.isNotEmpty || txt.isNotEmpty) {
          contactosPorSede[sedeId] = ConfigContactoSede(whatsapp: wsp, textoCuentas: txt);
        }
      }
    }

    final config = ConfigLugar(
      horariosActividad: Map.from(_config.horariosActividad),
      whatsappReservas: _whatsappController.text.trim(),
      textoCuentasReservas: _cuentasController.text.trim(),
      contactosPorSede: contactosPorSede,
    );

    setState(() => _saving = true);
    try {
      await ConfigLugarService.setConfig(_lugarId!, config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Configuración guardada correctamente'),
            ],
          ),
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _actualizarHorarioDia(int weekday, HorarioDia value) {
    setState(() {
      _config = _config.copyWith(
        horariosActividad: Map.from(_config.horariosActividad)..[weekday] = value,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingLugar) {
      return const Center(
        child: CircularProgressIndicator(color: _ink, strokeWidth: 1.5),
      );
    }

    final sedeProv = context.watch<SedeProvider>();
    final sedes = sedeProv.sedes;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final pagePadding = _pagePaddingForWidth(width);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: pagePadding,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ───────────────────────────────────────────────
                _PageHeader(),
                const SizedBox(height: 24),

                // ── Sin lugar asignado ────────────────────────────────────
                if (_lugarId == null)
                  _InfoBanner(
                    icon: Icons.info_outline_rounded,
                    text: 'No tienes un lugar asignado. Contacta al administrador.',
                  )
                else if (_lugarId != null && _lugarId!.isNotEmpty) ...[
                  if (_loadingConfig)
                    const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(
                        child: CircularProgressIndicator(color: _ink, strokeWidth: 1.5),
                      ),
                    )
                  else ...[
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _HorarioCard(
                              config: _config,
                              nombresDias: _nombresDias,
                              onChanged: _actualizarHorarioDia,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _WhatsAppCard(
                              config: _config,
                              sedes: sedes,
                              usarMismaInfoParaTodas: _usarMismaInfoParaTodas,
                              onCambiarUsarMismaInfoParaTodas: (v) {
                                setState(() => _usarMismaInfoParaTodas = v);
                                if (v) {
                                  for (final sede in sedes) {
                                    final id = sede['id'] as String;
                                    _whatsappPorSede[id]?.text = _whatsappController.text;
                                    _cuentasPorSede[id]?.text = _cuentasController.text;
                                  }
                                }
                              },
                              whatsappGlobalController: _whatsappController,
                              cuentasGlobalController: _cuentasController,
                              whatsappPorSede: _whatsappPorSede,
                              cuentasPorSede: _cuentasPorSede,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _HorarioCard(
                        config: _config,
                        nombresDias: _nombresDias,
                        onChanged: _actualizarHorarioDia,
                      ),
                      const SizedBox(height: 16),
                      _WhatsAppCard(
                        config: _config,
                        sedes: sedes,
                        usarMismaInfoParaTodas: _usarMismaInfoParaTodas,
                        onCambiarUsarMismaInfoParaTodas: (v) {
                          setState(() => _usarMismaInfoParaTodas = v);
                          if (v) {
                            for (final sede in sedes) {
                              final id = sede['id'] as String;
                              _whatsappPorSede[id]?.text = _whatsappController.text;
                              _cuentasPorSede[id]?.text = _cuentasController.text;
                            }
                          }
                        },
                        whatsappGlobalController: _whatsappController,
                        cuentasGlobalController: _cuentasController,
                        whatsappPorSede: _whatsappPorSede,
                        cuentasPorSede: _cuentasPorSede,
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── Botón guardar ─────────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _guardar,
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          disabledBackgroundColor: const Color(0xFF555555),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Guardando…',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Guardar configuración',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header de página ──────────────────────────────────────────────────────────

class _PageHeader extends StatelessWidget {
  static const _ink   = Color(0xFF0A0A0A);
  static const _muted = Color(0xFF888888);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración del lugar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Horarios de actividad, WhatsApp y cuentas',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _muted),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),
      ],
    );
  }
}

// ── Banner de información ─────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF888888), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF555555)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de horarios ──────────────────────────────────────────────────────────

class _HorarioCard extends StatelessWidget {
  final ConfigLugar config;
  final List<String> nombresDias;
  final void Function(int weekday, HorarioDia value) onChanged;

  const _HorarioCard({
    required this.config,
    required this.nombresDias,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.schedule_outlined,
              title: 'Horarios de actividad',
              subtitle:
                  'Los días cerrados no aceptarán reservas.',
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (i) {
              final weekday = i + 1;
              final h = config.horarioDia(weekday);
              return _FilaHorarioDia(
                nombreDia: nombresDias[i],
                cerrado: h.cerrado,
                inicio: h.inicio,
                fin: h.fin,
                isLast: i == 6,
                onChanged: (cerrado, inicio, fin) => onChanged(
                  weekday,
                  HorarioDia(cerrado: cerrado, inicio: inicio, fin: fin),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Card de WhatsApp / cuentas ────────────────────────────────────────────────

class _WhatsAppCard extends StatelessWidget {
  final ConfigLugar config;
  final List<Map<String, dynamic>> sedes;
  final bool usarMismaInfoParaTodas;
  final ValueChanged<bool> onCambiarUsarMismaInfoParaTodas;
  final TextEditingController whatsappGlobalController;
  final TextEditingController cuentasGlobalController;
  final Map<String, TextEditingController> whatsappPorSede;
  final Map<String, TextEditingController> cuentasPorSede;

  const _WhatsAppCard({
    required this.config,
    required this.sedes,
    required this.usarMismaInfoParaTodas,
    required this.onCambiarUsarMismaInfoParaTodas,
    required this.whatsappGlobalController,
    required this.cuentasGlobalController,
    required this.whatsappPorSede,
    required this.cuentasPorSede,
  });

  static const _ink    = Color(0xFF0A0A0A);
  static const _border = Color(0xFFE8E8E8);
  static const _subtle = Color(0xFFF5F5F5);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'WhatsApp y cuentas',
              subtitle: 'Se incluyen en el mensaje de confirmación al cliente.',
            ),
            const SizedBox(height: 16),

            // Campo WhatsApp global
            _MinimalTextField(
              controller: whatsappGlobalController,
              label: 'Número de WhatsApp',
              hint: '+573001234567',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            const SizedBox(height: 12),

            // Campo cuentas global
            _MinimalTextField(
              controller: cuentasGlobalController,
              label: 'Texto de cuentas para transferencia',
              prefixIcon: Icons.account_balance_outlined,
              maxLines: 5,
              alignLabelWithHint: true,
            ),
            const SizedBox(height: 16),

            // Toggle "misma info para todas"
            _ToggleRow(
              value: usarMismaInfoParaTodas,
              onChanged: onCambiarUsarMismaInfoParaTodas,
              title: 'Usar la misma información para todas las sedes',
              subtitle:
                  'El WhatsApp y las cuentas de arriba se aplicarán a todas.',
            ),

            // Config por sede
            if (!usarMismaInfoParaTodas) ...[
              const SizedBox(height: 16),
              const _SubsectionLabel(label: 'Configurar por sede'),
              const SizedBox(height: 10),
              if (sedes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No hay sedes activas para este lugar.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                )
              else
                ...sedes.map((sede) {
                  final sedeId = sede['id'] as String;
                  final sedeNombre = sede['nombre'] as String? ?? '';

                  whatsappPorSede.putIfAbsent(
                    sedeId,
                    () => TextEditingController(
                      text: config.contactoParaSede(sedeId)?.whatsapp.isNotEmpty == true
                          ? config.contactoParaSede(sedeId)!.whatsapp
                          : whatsappGlobalController.text,
                    ),
                  );
                  cuentasPorSede.putIfAbsent(
                    sedeId,
                    () => TextEditingController(
                      text: config.contactoParaSede(sedeId)?.textoCuentas.isNotEmpty == true
                          ? config.contactoParaSede(sedeId)!.textoCuentas
                          : cuentasGlobalController.text,
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _subtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: _ink,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  sedeNombre,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _MinimalTextField(
                              controller: whatsappPorSede[sedeId]!,
                              label: 'WhatsApp de la sede',
                              keyboardType: TextInputType.phone,
                              prefixIcon: Icons.phone_outlined,
                              fillColor: Colors.white,
                            ),
                            const SizedBox(height: 8),
                            _MinimalTextField(
                              controller: cuentasPorSede[sedeId]!,
                              label: 'Cuentas de pago de la sede',
                              prefixIcon: Icons.account_balance_outlined,
                              maxLines: 3,
                              alignLabelWithHint: true,
                              fillColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Campo de texto minimalista ────────────────────────────────────────────────

class _MinimalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final int? maxLines;
  final bool alignLabelWithHint;
  final Color? fillColor;

  const _MinimalTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.maxLines = 1,
    this.alignLabelWithHint = false,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final fill = fillColor ?? const Color(0xFFF5F5F5);
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Color(0xFF0A0A0A)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: alignLabelWithHint,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: const Color(0xFF888888))
            : null,
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0A0A0A), width: 1.5),
        ),
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  const _ToggleRow({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? const Color(0xFF0A0A0A) : const Color(0xFFE8E8E8),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: value ? Colors.white : const Color(0xFF0A0A0A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: value ? const Color(0xFFBBBBBB) : const Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF444444),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Etiqueta de sub-sección ───────────────────────────────────────────────────

class _SubsectionLabel extends StatelessWidget {
  final String label;
  const _SubsectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0A0A0A),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0A0A0A), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0A0A0A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Fila de horario por día ───────────────────────────────────────────────────

class _FilaHorarioDia extends StatefulWidget {
  final String nombreDia;
  final bool cerrado;
  final String inicio;
  final String fin;
  final bool isLast;
  final void Function(bool cerrado, String inicio, String fin) onChanged;

  const _FilaHorarioDia({
    required this.nombreDia,
    required this.cerrado,
    required this.inicio,
    required this.fin,
    required this.isLast,
    required this.onChanged,
  });

  @override
  State<_FilaHorarioDia> createState() => _FilaHorarioDiaState();
}

class _FilaHorarioDiaState extends State<_FilaHorarioDia> {
  late bool _cerrado;
  late TextEditingController _inicioController;
  late TextEditingController _finController;

  @override
  void initState() {
    super.initState();
    _cerrado = widget.cerrado;
    _inicioController = TextEditingController(text: widget.inicio);
    _finController = TextEditingController(text: widget.fin);
  }

  @override
  void didUpdateWidget(_FilaHorarioDia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inicio != widget.inicio) _inicioController.text = widget.inicio;
    if (oldWidget.fin != widget.fin) _finController.text = widget.fin;
    if (oldWidget.cerrado != widget.cerrado) _cerrado = widget.cerrado;
  }

  @override
  void dispose() {
    _inicioController.dispose();
    _finController.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      _cerrado,
      _inicioController.text.trim(),
      _finController.text.trim(),
    );
  }

  static int _parseHour(String hhmm) {
    final parts = hhmm.split(':');
    return int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  }

  static String _fmtHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  Future<String?> _pickHour({
    required String title,
    required int initialHour,
    required int minHour,
    required int maxHour,
  }) async {
    final hours = <int>[for (int h = minHour; h <= maxHour; h++) h];
    final width = MediaQuery.of(context).size.width;
    final useBottomSheet = width < 700;

    Widget content = ListView.separated(
      shrinkWrap: true,
      itemCount: hours.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, idx) {
        final h = hours[idx];
        final selected = h == initialHour;
        return ListTile(
          dense: true,
          selected: selected,
          selectedColor: const Color(0xFF0A0A0A),
          selectedTileColor: const Color(0xFFF5F5F5),
          title: Text(
            _fmtHour(h),
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check, size: 16, color: Color(0xFF0A0A0A))
              : null,
          onTap: () => Navigator.of(context).pop(h),
        );
      },
    );

    final result = useBottomSheet
        ? await showModalBottomSheet<int>(
            context: context,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (context) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      Flexible(child: content),
                    ],
                  ),
                ),
              );
            },
          )
        : await showDialog<int>(
            context: context,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                content: SizedBox(width: 320, child: content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A0A0A)),
                    child: const Text('Cancelar'),
                  ),
                ],
              );
            },
          );

    if (result == null) return null;
    return _fmtHour(result);
  }

  Future<void> _onTapInicio() async {
    if (_cerrado) return;
    final currentStart = _inicioController.text.trim();
    final currentEnd = _finController.text.trim();
    final startHour = _parseHour(currentStart);
    final endHour = _parseHour(currentEnd);

    final picked = await _pickHour(
      title: '${widget.nombreDia} · Hora de inicio',
      initialHour: startHour.clamp(0, 22),
      minHour: 0,
      maxHour: 22,
    );
    if (picked == null) return;

    final newStart = _parseHour(picked);
    var newEnd = endHour;
    if (newEnd <= newStart) {
      newEnd = (newStart + 1).clamp(1, 23);
      _finController.text = _fmtHour(newEnd);
    }
    _inicioController.text = _fmtHour(newStart);
    _notify();
    setState(() {});
  }

  Future<void> _onTapFin() async {
    if (_cerrado) return;
    final currentStart = _inicioController.text.trim();
    final currentEnd = _finController.text.trim();
    final startHour = _parseHour(currentStart);
    final endHour = _parseHour(currentEnd);

    final picked = await _pickHour(
      title: '${widget.nombreDia} · Hora de cierre',
      initialHour: endHour.clamp((startHour + 1).clamp(1, 23), 23),
      minHour: (startHour + 1).clamp(1, 23),
      maxHour: 23,
    );
    if (picked == null) return;

    _finController.text = picked;
    _notify();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _cerrado;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 520;

              final dayLabel = AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isClosed ? const Color(0xFFBBBBBB) : const Color(0xFF0A0A0A),
                ),
                child: Text(widget.nombreDia),
              );

              final toggleRow = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isClosed ? const Color(0xFF0A0A0A) : const Color(0xFFBBBBBB),
                    ),
                    child: const Text('Cerrado'),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 28,
                    child: Switch.adaptive(
                      value: _cerrado,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF0A0A0A),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCCCCCC),
                      onChanged: (v) {
                        setState(() {
                          _cerrado = v;
                          _notify();
                        });
                      },
                    ),
                  ),
                ],
              );

              final timeRow = AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isClosed ? 0.3 : 1.0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimeChip(
                      label: 'Inicio',
                      value: _inicioController.text.trim(),
                      enabled: !_cerrado,
                      onTap: _onTapInicio,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '→',
                        style: TextStyle(
                          fontSize: 12,
                          color: isClosed ? const Color(0xFFCCCCCC) : const Color(0xFF888888),
                        ),
                      ),
                    ),
                    _TimeChip(
                      label: 'Fin',
                      value: _finController.text.trim(),
                      enabled: !_cerrado,
                      onTap: _onTapFin,
                    ),
                  ],
                ),
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: dayLabel),
                        toggleRow,
                      ],
                    ),
                    const SizedBox(height: 8),
                    timeRow,
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(width: 88, child: dayLabel),
                  toggleRow,
                  const Spacer(),
                  timeRow,
                ],
              );
            },
          ),
        ),
        if (!widget.isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),
      ],
    );
  }
}

// ── Chip de hora ──────────────────────────────────────────────────────────────

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeChip({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF5F5F5) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? '--:--' : value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A0A0A),
                    ),
                  ),
                ),
                const Icon(Icons.unfold_more_rounded, size: 12, color: Color(0xFFAAAAAA)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}