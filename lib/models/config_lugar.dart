/// Configuración por lugar: horarios de actividad, WhatsApp y cuentas para reservas.
/// Se guarda en Firestore en: config/lugar_{lugarId}
class ConfigLugar {
  /// Lunes=1 .. Domingo=7. Cada entrada: cerrado, o inicio/fin en "HH:mm" (24h).
  final Map<int, HorarioDia> horariosActividad;
  /// Número de WhatsApp para el mensaje de reserva (ej: +573013435434).
  final String whatsappReservas;
  /// Texto de cuentas bancarias que se incluye en el mensaje de WhatsApp.
  final String textoCuentasReservas;
  /// Configuración de contacto específica por sede (opcional). Clave: sedeId.
  final Map<String, ConfigContactoSede> contactosPorSede;

  ConfigLugar({
    Map<int, HorarioDia>? horariosActividad,
    this.whatsappReservas = '',
    this.textoCuentasReservas = '',
    Map<String, ConfigContactoSede>? contactosPorSede,
  })  : horariosActividad = horariosActividad ?? _defaultHorarios(),
        contactosPorSede = contactosPorSede ?? {};

  static Map<int, HorarioDia> _defaultHorarios() {
    return {
      // Abierto 24 horas por defecto (00:00 - 23:59) para lugares sin configuración explícita.
      1: HorarioDia(inicio: '00:00', fin: '23:59'), // Lunes
      2: HorarioDia(inicio: '00:00', fin: '23:59'),
      3: HorarioDia(inicio: '00:00', fin: '23:59'),
      4: HorarioDia(inicio: '00:00', fin: '23:59'),
      5: HorarioDia(inicio: '00:00', fin: '23:59'),
      6: HorarioDia(inicio: '00:00', fin: '23:59'),
      7: HorarioDia(inicio: '00:00', fin: '23:59'), // Domingo
    };
  }

  /// Devuelve el horario del día (1=lunes .. 7=domingo).
  HorarioDia horarioDia(int weekday) {
    return horariosActividad[weekday] ?? HorarioDia(inicio: '06:00', fin: '22:00');
  }

  /// Indica si el lugar está cerrado ese día.
  bool estaCerradoDia(int weekday) {
    return horarioDia(weekday).cerrado;
  }

  /// Indica si en el día y hora dados el lugar está dentro del horario de actividad.
  /// [weekday] 1=lunes .. 7=domingo; [hora] y [minuto] en formato 24h.
  bool estaDentroDeHorario(int weekday, int hora, int minuto) {
    final h = horarioDia(weekday);
    if (h.cerrado) return false;
    final totalMinutos = hora * 60 + minuto;
    final inicioMin = _parseHHmm(h.inicio);
    final finMin = _parseHHmm(h.fin);
    return totalMinutos >= inicioMin && totalMinutos < finMin;
  }

  static int _parseHHmm(String s) {
    final parts = s.split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  factory ConfigLugar.fromFirestore(Map<String, dynamic> data) {
    Map<int, HorarioDia> horarios = {};
    final raw = data['horariosActividad'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final k = int.tryParse(e.key.toString()) ?? 0;
        if (k >= 1 && k <= 7 && e.value is Map) {
          horarios[k] = HorarioDia.fromMap(Map<String, dynamic>.from(e.value as Map));
        }
      }
    }
    if (horarios.length < 7) {
      final def = _defaultHorarios();
      for (int i = 1; i <= 7; i++) {
        horarios.putIfAbsent(i, () => def[i]!);
      }
    }
    // Contactos por sede (opcional y retrocompatible).
    final contactosMap = <String, ConfigContactoSede>{};
    final rawContactos = data['contactosPorSede'];
    if (rawContactos is Map) {
      for (final entry in rawContactos.entries) {
        final sedeId = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          contactosMap[sedeId] =
              ConfigContactoSede.fromMap(Map<String, dynamic>.from(value));
        }
      }
    }
    return ConfigLugar(
      horariosActividad: horarios,
      whatsappReservas: data['whatsappReservas'] as String? ?? '',
      textoCuentasReservas: data['textoCuentasReservas'] as String? ?? '',
      contactosPorSede: contactosMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    final horariosMap = <String, dynamic>{};
    for (final e in horariosActividad.entries) {
      horariosMap['${e.key}'] = e.value.toMap();
    }
    final contactosMap = <String, dynamic>{};
    for (final e in contactosPorSede.entries) {
      contactosMap[e.key] = e.value.toMap();
    }
    return {
      'horariosActividad': horariosMap,
      'whatsappReservas': whatsappReservas,
      'textoCuentasReservas': textoCuentasReservas,
      if (contactosMap.isNotEmpty) 'contactosPorSede': contactosMap,
    };
  }

  ConfigLugar copyWith({
    Map<int, HorarioDia>? horariosActividad,
    String? whatsappReservas,
    String? textoCuentasReservas,
    Map<String, ConfigContactoSede>? contactosPorSede,
  }) {
    return ConfigLugar(
      horariosActividad: horariosActividad ?? Map.from(this.horariosActividad),
      whatsappReservas: whatsappReservas ?? this.whatsappReservas,
      textoCuentasReservas: textoCuentasReservas ?? this.textoCuentasReservas,
      contactosPorSede:
          contactosPorSede ?? Map.from(this.contactosPorSede),
    );
  }

  /// Devuelve la configuración de contacto para una sede concreta, o null si no existe.
  ConfigContactoSede? contactoParaSede(String sedeId) =>
      contactosPorSede[sedeId];

  /// WhatsApp para reservas: el de la sede si está definido y no vacío; si no, el global.
  String whatsappEfectivoParaSede(String sedeId) {
    final porSede = contactoParaSede(sedeId);
    final w = porSede?.whatsapp.trim() ?? '';
    if (w.isNotEmpty) return w;
    return whatsappReservas.trim();
  }

  /// Texto de cuentas: el de la sede si está definido y no vacío; si no, el global.
  String textoCuentasEfectivoParaSede(String sedeId) {
    final porSede = contactoParaSede(sedeId);
    final c = porSede?.textoCuentas.trim() ?? '';
    if (c.isNotEmpty) return c;
    return textoCuentasReservas.trim();
  }
}

class HorarioDia {
  final bool cerrado;
  final String inicio; // "HH:mm" 24h
  final String fin;

  HorarioDia({this.cerrado = false, this.inicio = '06:00', this.fin = '22:00'});

  Map<String, dynamic> toMap() => {
        'cerrado': cerrado,
        'inicio': inicio,
        'fin': fin,
      };

  factory HorarioDia.fromMap(Map<String, dynamic> m) {
    return HorarioDia(
      cerrado: m['cerrado'] as bool? ?? false,
      inicio: m['inicio'] as String? ?? '06:00',
      fin: m['fin'] as String? ?? '22:00',
    );
  }

  HorarioDia copyWith({bool? cerrado, String? inicio, String? fin}) {
    return HorarioDia(
      cerrado: cerrado ?? this.cerrado,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
    );
  }
}

/// Configuración de contacto (WhatsApp + texto cuentas) específica para una sede.
class ConfigContactoSede {
  final String whatsapp;
  final String textoCuentas;

  ConfigContactoSede({
    this.whatsapp = '',
    this.textoCuentas = '',
  });

  factory ConfigContactoSede.fromMap(Map<String, dynamic> map) {
    return ConfigContactoSede(
      whatsapp: map['whatsapp'] as String? ?? '',
      textoCuentas: map['textoCuentas'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'whatsapp': whatsapp,
        'textoCuentas': textoCuentas,
      };

  ConfigContactoSede copyWith({
    String? whatsapp,
    String? textoCuentas,
  }) {
    return ConfigContactoSede(
      whatsapp: whatsapp ?? this.whatsapp,
      textoCuentas: textoCuentas ?? this.textoCuentas,
    );
  }
}
