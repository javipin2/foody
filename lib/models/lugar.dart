import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:reserva_canchas/utils/supabase_parse.dart';

class Lugar {
  final String id;
  final String nombre;
  final String ciudadId;
  final String direccion;
  final String telefono;
  final bool activo;
  final String? fotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Plan del lugar: basico, premium, pro, prueba, etc.
  final String? plan;

  /// Fecha de inicio del plan (para control de mensualidades)
  final DateTime? planInicio;

  /// Valor mensual del plan (cuánto se cobrará)
  final double? planValorMensual;

  /// Fecha del último pago registrado del plan (no cambia el día base de cobro).
  final DateTime? planUltimoPago;

  /// Límite de sedes configurado para este lugar (null = ilimitadas o usar valor por defecto de plan).
  final int? maxSedes;

  /// Límite de canchas configurado para este lugar (null = ilimitadas o usar valor por defecto de plan).
  final int? maxCanchas;

  Lugar({
    required this.id,
    required this.nombre,
    required this.ciudadId,
    required this.direccion,
    required this.telefono,
    required this.activo,
    this.fotoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
    this.planInicio,
    this.planValorMensual,
    this.planUltimoPago,
    this.maxSedes,
    this.maxCanchas,
  });

  factory Lugar.fromSupabase(Map<String, dynamic> row) {
    return Lugar(
      id: row['id'] as String,
      nombre: (row['nombre'] as String?) ?? '',
      ciudadId: (row['ciudad_id'] as String?) ?? '',
      direccion: (row['direccion'] as String?) ?? '',
      telefono: (row['telefono'] as String?) ?? '',
      activo: (row['activo'] as bool?) ?? true,
      fotoUrl: row['foto_url'] as String?,
      createdAt: parseSupabaseDate(row['created_at']),
      updatedAt: parseSupabaseDate(row['updated_at']),
      plan: row['plan'] as String?,
      planInicio: row['plan_inicio'] != null
          ? parseSupabaseDate(row['plan_inicio'])
          : null,
      planValorMensual: row['plan_valor_mensual'] is num
          ? (row['plan_valor_mensual'] as num).toDouble()
          : null,
      planUltimoPago: row['plan_ultimo_pago'] != null
          ? parseSupabaseDate(row['plan_ultimo_pago'])
          : null,
      maxSedes: row['max_sedes'] is num ? (row['max_sedes'] as num).toInt() : null,
      maxCanchas:
          row['max_canchas'] is num ? (row['max_canchas'] as num).toInt() : null,
    );
  }

  Map<String, dynamic> toSupabaseInsert() {
    final now = DateTime.now().toIso8601String();
    return {
      'ciudad_id': ciudadId,
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
      'activo': activo,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      'created_at': now,
      'updated_at': now,
      if (plan != null) 'plan': plan,
      if (planInicio != null) 'plan_inicio': planInicio!.toIso8601String(),
      if (planValorMensual != null) 'plan_valor_mensual': planValorMensual,
      if (planUltimoPago != null)
        'plan_ultimo_pago': planUltimoPago!.toIso8601String(),
      if (maxSedes != null) 'max_sedes': maxSedes,
      if (maxCanchas != null) 'max_canchas': maxCanchas,
    };
  }

  factory Lugar.fromFirestore(Map<String, dynamic> data, String id) {
    return Lugar(
      id: id,
      nombre: data['nombre'] ?? '',
      ciudadId: data['ciudadId'] ?? '',
      direccion: data['direccion'] ?? '',
      telefono: data['telefono'] ?? '',
      activo: data['activo'] ?? true,
      fotoUrl: data['fotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      plan: data['plan'] as String?,
      planInicio: (data['planInicio'] is Timestamp)
          ? (data['planInicio'] as Timestamp).toDate()
          : null,
      planValorMensual: data['planValorMensual'] is num
          ? (data['planValorMensual'] as num).toDouble()
          : null,
      planUltimoPago: (data['planUltimoPago'] is Timestamp)
          ? (data['planUltimoPago'] as Timestamp).toDate()
          : null,
      maxSedes: data['maxSedes'] is num
          ? (data['maxSedes'] as num).toInt()
          : null,
      maxCanchas: data['maxCanchas'] is num
          ? (data['maxCanchas'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'ciudadId': ciudadId,
      'direccion': direccion,
      'telefono': telefono,
      'activo': activo,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (plan != null) 'plan': plan,
      if (planInicio != null) 'planInicio': Timestamp.fromDate(planInicio!),
      if (planValorMensual != null) 'planValorMensual': planValorMensual,
      if (planUltimoPago != null)
        'planUltimoPago': Timestamp.fromDate(planUltimoPago!),
      if (maxSedes != null) 'maxSedes': maxSedes,
      if (maxCanchas != null) 'maxCanchas': maxCanchas,
    };
  }

  Lugar copyWith({
    String? id,
    String? nombre,
    String? ciudadId,
    String? direccion,
    String? telefono,
    bool? activo,
    String? fotoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? plan,
    DateTime? planInicio,
    double? planValorMensual,
    DateTime? planUltimoPago,
    int? maxSedes,
    int? maxCanchas,
  }) {
    return Lugar(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      ciudadId: ciudadId ?? this.ciudadId,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      plan: plan ?? this.plan,
      planInicio: planInicio ?? this.planInicio,
      planValorMensual: planValorMensual ?? this.planValorMensual,
      planUltimoPago: planUltimoPago ?? this.planUltimoPago,
      maxSedes: maxSedes ?? this.maxSedes,
      maxCanchas: maxCanchas ?? this.maxCanchas,
    );
  }
}
