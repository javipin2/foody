import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import '../models/cancha.dart';
import '../models/horario.dart';
import '../providers/sede_provider.dart';
import '../providers/cancha_provider.dart';
import '../models/reserva_recurrente.dart';
import '../providers/reserva_recurrente_provider.dart';
import '../providers/promocion_provider.dart';
import '../models/config_lugar.dart';
import '../services/config_lugar_service.dart';
import 'detalles_screen.dart';
import 'reserva_detalles_screen.dart';
import '../main.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

/// Paleta alineada con el panel admin (teal / slate).
final class _HorariosUi {
  const _HorariosUi._();
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color accent = Color.fromARGB(78, 13, 148, 137);
  static const Color accentDark = Color(0xFF0F766E);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color bgTop = Color(0xFFF1F5F9);
}

class HorariosScreen extends StatefulWidget {
  final Cancha cancha;

  const HorariosScreen({super.key, required this.cancha});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> with RouteAware, TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<Horario> horarios = [];
  bool _isLoading = false;
  bool _calendarExpanded = false;
  final Map<String, QuerySnapshot> _reservasSnapshots = {};
  Timer? _debounceTimer;
  Cancha? _updatedCancha;
  Timer? _updateTimer;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  // ✅ OPTIMIZADO: Variables para promociones (ahora usando Provider centralizado)
  Map<String, Map<String, dynamic>> _promocionesPorHorario = {}; // horarioNormalizado -> {precio, id, precio_promocional, ...}
  StreamSubscription<Map<String, Map<String, dynamic>>>? _promocionesSubscription;
  late AnimationController _goldShimmerController;
  
  /// Animación de pulso sutil para la tarjeta seleccionada.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // ✅ NUEVO: Streams en tiempo real para reservas
  StreamSubscription<QuerySnapshot>? _reservasSubscription;
  StreamSubscription<QuerySnapshot>? _reservasTemporalesSubscription;

  /// Horario seleccionado por el usuario para continuar a reserva (al pulsar Confirmar Reserva).
  Horario? _selectedHorario;

  /// Configuración del lugar (horarios de actividad). Si el día está cerrado o fuera de horario, no se puede reservar.
  ConfigLugar? _configLugar;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // ✅ NUEVO: Controlador para efecto dorado
    _goldShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final canchaProvider = Provider.of<CanchaProvider>(context, listen: false);
    final sedeProvider = Provider.of<SedeProvider>(context, listen: false);

    sedeProvider.fetchSedes().then((_) {
      if (!mounted) return;
      String selectedSede = sedeProvider.selectedSede.isNotEmpty
          ? sedeProvider.selectedSede
          : sedeProvider.sedeNames.isNotEmpty
              ? sedeProvider.sedeNames.first
              : '';
      if (selectedSede.isNotEmpty) {
        sedeProvider.setSede(selectedSede);
        canchaProvider.fetchCanchas(selectedSede).then((_) {
          if (!mounted) return;
          setState(() {
            _updatedCancha = canchaProvider.canchas.firstWhere(
              (c) => c.id == widget.cancha.id,
              orElse: () => widget.cancha,
            );
            _loadHorarios();
          });
        }).catchError((error) {
          if (!mounted) return;
          setState(() {
            _updatedCancha = widget.cancha;
            _loadHorarios();
          });
        });
      } else {
        if (!mounted) return;
        setState(() {
          _updatedCancha = widget.cancha;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No hay sedes disponibles'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ),
        );
      }
    });

    _fadeController.forward();
    _slideController.forward();

    _updateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        _refreshHorariosEstados();
      }
    });
    
    // ✅ NUEVO: Iniciar escucha de promociones
    _iniciarEscuchaPromociones();

    // Cargar configuración del lugar (horarios de actividad para mostrar "Cerrado" / bloquear reservas)
    final lugarId = widget.cancha.lugarId;
    if (lugarId != null && lugarId.isNotEmpty) {
      ConfigLugarService.getConfig(lugarId).then((c) {
        if (mounted) setState(() => _configLugar = c);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _fadeController.dispose();
    _slideController.dispose();
    _goldShimmerController.dispose(); // ✅ NUEVO
    _pulseController.dispose();
    _promocionesSubscription?.cancel(); // ✅ NUEVO
    _reservasSubscription?.cancel(); // ✅ NUEVO: Cancelar stream de reservas
    _reservasTemporalesSubscription?.cancel(); // ✅ NUEVO: Cancelar stream de reservas temporales
    _debounceTimer?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadHorarios();
  }
  
  // ✅ OPTIMIZADO: Método para escuchar promociones usando Provider centralizado
  void _iniciarEscuchaPromociones() {
    if (!mounted) return;
    _promocionesSubscription?.cancel();
    
    final fechaSeleccionadaStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    debugPrint('🔍 Iniciando escucha de promociones (Provider centralizado)...');
    debugPrint('   - Fecha: $fechaSeleccionadaStr');
    debugPrint('   - Cancha ID: ${widget.cancha.id}');
    
    // ✅ Obtener lugarId desde SedeProvider o desde la cancha
    final sedeProvider = Provider.of<SedeProvider>(context, listen: false);
    final lugarId = sedeProvider.lugarId ?? widget.cancha.lugarId;
    
    if (lugarId == null || lugarId.isEmpty) {
      debugPrint('❌ No se pudo obtener lugarId (SedeProvider: ${sedeProvider.lugarId}, Cancha: ${widget.cancha.lugarId})');
      return;
    }
    
    // Obtener sedeId y sedeNombre
    String? sedeId;
    String? sedeNombre;
    
    if (sedeProvider.selectedSede.isNotEmpty) {
      try {
        final sede = sedeProvider.sedes.firstWhere(
          (s) => s['id'] == sedeProvider.selectedSede || s['nombre'] == sedeProvider.selectedSede,
          orElse: () => {'id': widget.cancha.sedeId, 'nombre': sedeProvider.selectedSede},
        );
        sedeId = sede['id'] as String? ?? widget.cancha.sedeId;
        sedeNombre = sede['nombre'] as String?;
      } catch (e) {
        debugPrint('⚠️ Error obteniendo sede: $e');
        sedeId = widget.cancha.sedeId;
      }
    } else {
      sedeId = widget.cancha.sedeId;
    }
    
    debugPrint('   - Lugar ID: $lugarId (desde ${sedeProvider.lugarId != null ? "SedeProvider" : "Cancha"})');
    debugPrint('   - Sede ID: $sedeId');
    debugPrint('   - Sede Nombre: $sedeNombre');
    
    // ✅ OPTIMIZADO: Usar PromocionProvider centralizado
    final promocionProvider = Provider.of<PromocionProvider>(context, listen: false);
    
    _promocionesSubscription = promocionProvider.getPromociones(
      lugarId: lugarId,
      canchaId: widget.cancha.id,
      fecha: fechaSeleccionadaStr,
      sedeId: sedeId,
      sedeNombre: sedeNombre,
    ).listen(
      (promocionesTemp) {
        if (!mounted) return;
        
        setState(() {
          _promocionesPorHorario = promocionesTemp;
        });
        
        debugPrint('🎯 Promociones cargadas en mapa: ${_promocionesPorHorario.length}');
        if (_promocionesPorHorario.isNotEmpty) {
          _promocionesPorHorario.forEach((key, value) {
            debugPrint('   📌 "$key" -> S/ ${value['precio_promocional']}');
          });
        } else {
          debugPrint('   ⚠️ No se cargaron promociones en el mapa');
        }
      },
      onError: (error) {
        debugPrint('❌ Error en stream de promociones: $error');
        if (mounted) {
          setState(() {
            _promocionesPorHorario = {};
          });
        }
      },
    );
  }

  Future<void> _loadHorarios() async {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        horarios.clear();
      });

      try {
        final sedeProvider = Provider.of<SedeProvider>(context, listen: false);
        final reservaRecurrenteProvider = Provider.of<ReservaRecurrenteProvider>(context, listen: false);
        
        Map<String, dynamic> selectedSede;
        if (sedeProvider.selectedSede.isNotEmpty) {
          selectedSede = sedeProvider.sedes.firstWhere(
            (sede) => sede['id'] == sedeProvider.selectedSede || sede['nombre'] == sedeProvider.selectedSede,
            orElse: () => {'id': widget.cancha.sedeId},
          );
        } else {
          selectedSede = sedeProvider.sedes.firstWhere(
            (sede) => sede['id'] == widget.cancha.sedeId,
            orElse: () => {'id': widget.cancha.sedeId},
          );
        }
        final sedeId = selectedSede['id'] as String;

        debugPrint('🏢 === INICIO CARGA HORARIOS ===');
        debugPrint('🏢 Sede seleccionada: $sedeId');
        debugPrint('🏟️ Cancha: ${widget.cancha.id} - ${widget.cancha.nombre}');
        debugPrint('📅 Fecha: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}');

        // ✅ CORRECCIÓN CRÍTICA: SIEMPRE RECARGAR RESERVAS RECURRENTES PARA LA SEDE ACTUAL
        debugPrint('🔄 Recargando reservas recurrentes para sede: $sedeId');
        await reservaRecurrenteProvider.fetchReservasRecurrentes(sede: sedeId);
        
        final todasReservasRecurrentes = reservaRecurrenteProvider.reservasRecurrentes;
        debugPrint('📊 Total reservas recurrentes cargadas: ${todasReservasRecurrentes.length}');
        debugPrint('📊 Por estado:');
        debugPrint('   - Activas: ${todasReservasRecurrentes.where((r) => r.estado == EstadoRecurrencia.activa).length}');
        debugPrint('   - Canceladas: ${todasReservasRecurrentes.where((r) => r.estado == EstadoRecurrencia.cancelada).length}');
        debugPrint('   - Pausadas: ${todasReservasRecurrentes.where((r) => r.estado == EstadoRecurrencia.pausada).length}');

        // ✅ NUEVO: Iniciar escucha en tiempo real de reservas
        _iniciarEscuchaReservasEnTiempoReal(sedeId);

        // ✅ CARGAR RESERVAS INICIALES (primera carga)
        debugPrint('🔍 Consultando reservas normales (carga inicial)...');
        final reservasSnapshotInicial = await FirebaseFirestore.instance
            .collection('reservas')
            .where('fecha', isEqualTo: DateFormat('yyyy-MM-dd').format(_selectedDate))
            .where('cancha_id', isEqualTo: widget.cancha.id)
            .where('sede', isEqualTo: sedeId)
            .limit(24)
            .get();
        
        debugPrint('📋 Reservas normales encontradas: ${reservasSnapshotInicial.docs.length}');
        
        // Generar horarios base
        final nuevosHorarios = await Horario.generarHorarios(
          fecha: _selectedDate,
          canchaId: widget.cancha.id,
          sede: sedeId,
          reservasSnapshot: reservasSnapshotInicial,
          cancha: _updatedCancha ?? widget.cancha,
        );

        debugPrint('⏰ Horarios base generados: ${nuevosHorarios.length}');

        // ✅ OBTENER RESERVAS RECURRENTES PARA ESTA FECHA ESPECÍFICA
        final reservasRecurrentesActivas = reservaRecurrenteProvider.obtenerReservasActivasParaFecha(
          _selectedDate, 
          sede: sedeId, 
          canchaId: widget.cancha.id
        );

        debugPrint('🔄 === PROCESANDO RESERVAS RECURRENTES ===');
        debugPrint('🔄 Reservas recurrentes activas para esta fecha: ${reservasRecurrentesActivas.length}');
        
        if (reservasRecurrentesActivas.isNotEmpty) {
          debugPrint('🔄 Lista de reservas a procesar:');
          for (var i = 0; i < reservasRecurrentesActivas.length; i++) {
            final reserva = reservasRecurrentesActivas[i];
            debugPrint('   ${i + 1}. ${reserva.clienteNombre} - ${reserva.horario} - Estado: ${reserva.estado}');
          }
        }

        // ✅ PROCESAR CADA RESERVA RECURRENTE CON LOGGING DETALLADO
        int reservasAplicadas = 0;
        for (var reservaRecurrente in reservasRecurrentesActivas) {
          final horarioOriginal = reservaRecurrente.horario.trim();
          final horaNormalizada = _normalizarHorarioMejorado(horarioOriginal);
          
          debugPrint('⏰ Procesando: "$horarioOriginal" -> "$horaNormalizada"');
          
          // Buscar el horario correspondiente
          final indiceHorario = nuevosHorarios.indexWhere((h) {
            final horaNormalizadaDisponible = _normalizarHorarioMejorado(h.horaFormateada);
            final coincide = horaNormalizadaDisponible == horaNormalizada;
            
            if (coincide) {
              debugPrint('   ✅ Match encontrado: "${h.horaFormateada}" -> "$horaNormalizadaDisponible"');
            }
            
            return coincide;
          });
          
          if (indiceHorario != -1) {
            final horarioActual = nuevosHorarios[indiceHorario];
            
            if (horarioActual.estado == EstadoHorario.disponible) {
              nuevosHorarios[indiceHorario] = Horario(
                hora: horarioActual.hora,
                estado: EstadoHorario.reservado,
                esReservaRecurrente: true,
                clienteNombre: reservaRecurrente.clienteNombre,
                reservaRecurrenteData: {
                  'id': reservaRecurrente.id,
                  'clienteId': reservaRecurrente.clienteId,
                  'clienteTelefono': reservaRecurrente.clienteTelefono,
                  'montoTotal': reservaRecurrente.montoTotal,
                  'montoPagado': reservaRecurrente.montoPagado,
                  'precioPersonalizado': reservaRecurrente.precioPersonalizado,
                  'precioOriginal': reservaRecurrente.precioOriginal,
                  'descuentoAplicado': reservaRecurrente.descuentoAplicado,
                  'esReservaRecurrente': true,
                },
              );
              
              reservasAplicadas++;
              debugPrint('   ✅ Reserva recurrente aplicada: ${reservaRecurrente.clienteNombre}');
            } else {
              debugPrint('   ⚠️ Horario ya ocupado por reserva normal (estado: ${horarioActual.estado})');
            }
          } else {
            debugPrint('   ❌ No se encontró horario matching para: "$horaNormalizada"');
            
            // Debug adicional: mostrar todos los horarios disponibles
            debugPrint('   🔍 Horarios disponibles para comparar:');
            for (var h in nuevosHorarios) {
              final hNorm = _normalizarHorarioMejorado(h.horaFormateada);
              debugPrint('      - "${h.horaFormateada}" -> "$hNorm"');
            }
          }
        }

        debugPrint('📊 === RESUMEN FINAL ===');
        debugPrint('📊 Reservas recurrentes aplicadas: $reservasAplicadas de ${reservasRecurrentesActivas.length}');

        // ✅ NUEVO: Recargar promociones después de cargar horarios
        _iniciarEscuchaPromociones();
        
        if (mounted) {
          setState(() {
            horarios = nuevosHorarios;
            _isLoading = false;
          });

          final disponibles = horarios.where((h) => h.estado == EstadoHorario.disponible).length;
          final reservados = horarios.where((h) => h.estado == EstadoHorario.reservado).length;
          final vencidos = horarios.where((h) => h.estado == EstadoHorario.vencido).length;
          final procesando = horarios.where((h) => h.estado == EstadoHorario.procesandoPago).length; // ✅ NUEVO
          final recurrentes = horarios.where((h) => h.esReservaRecurrente == true).length;

          debugPrint('📊 ESTADO FINAL:');
          debugPrint('   - Disponibles: $disponibles');
          debugPrint('   - Reservados: $reservados (de los cuales $recurrentes son recurrentes)');
          debugPrint('   - Procesando pago: $procesando'); // ✅ NUEVO
          debugPrint('   - Vencidos: $vencidos');
          debugPrint('🏢 === FIN CARGA HORARIOS ===');
        }
      } catch (e) {
        debugPrint('❌ Error en _loadHorarios: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar horarios: $e')),
          );
        }
      }
    });
  }

  // ✅ NUEVO: Escuchar reservas en tiempo real
  void _iniciarEscuchaReservasEnTiempoReal(String sedeId) {
    _reservasSubscription?.cancel();
    _reservasTemporalesSubscription?.cancel();
    
    final fechaStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    
    debugPrint('🔍 Iniciando escucha en tiempo real de reservas...');
    debugPrint('   - Fecha: $fechaStr');
    debugPrint('   - Cancha: ${widget.cancha.id}');
    debugPrint('   - Sede: $sedeId');
    
    // ✅ Escuchar reservas normales
    _reservasSubscription = FirebaseFirestore.instance
        .collection('reservas')
        .where('fecha', isEqualTo: fechaStr)
        .where('cancha_id', isEqualTo: widget.cancha.id)
        .where('sede', isEqualTo: sedeId)
        .limit(24)
        .snapshots()
        .listen(
          (querySnapshot) async {
            if (!mounted) return;
            
            debugPrint('📊 Reservas actualizadas: ${querySnapshot.docs.length}');
            await _actualizarHorariosConReservas(querySnapshot, sedeId);
          },
          onError: (error) {
            debugPrint('❌ Error en stream de reservas: $error');
          },
        );
    
    // ✅ Escuchar reservas temporales (en proceso de pago)
    final ahora = DateTime.now().millisecondsSinceEpoch;
    _reservasTemporalesSubscription = FirebaseFirestore.instance
        .collection('reservas_temporales')
        .where('cancha_id', isEqualTo: widget.cancha.id)
        .where('fecha', isEqualTo: fechaStr)
        .where('sede', isEqualTo: sedeId)
        .where('expira_en', isGreaterThan: ahora)
        .snapshots()
        .listen(
          (querySnapshot) async {
            if (!mounted) return;
            
            debugPrint('⏳ Reservas temporales actualizadas: ${querySnapshot.docs.length}');
            // Las reservas temporales se procesan dentro de _actualizarHorariosConReservas
            // pero necesitamos obtener las reservas normales también
            final reservasSnapshot = await FirebaseFirestore.instance
                .collection('reservas')
                .where('fecha', isEqualTo: fechaStr)
                .where('cancha_id', isEqualTo: widget.cancha.id)
                .where('sede', isEqualTo: sedeId)
                .limit(24)
                .get();
            
            await _actualizarHorariosConReservas(reservasSnapshot, sedeId);
          },
          onError: (error) {
            debugPrint('❌ Error en stream de reservas temporales: $error');
          },
        );
  }
  
  // ✅ NUEVO: Actualizar horarios cuando cambian las reservas
  Future<void> _actualizarHorariosConReservas(QuerySnapshot reservasSnapshot, String sedeId) async {
    if (!mounted) return;
    
    try {
      final reservaRecurrenteProvider = Provider.of<ReservaRecurrenteProvider>(context, listen: false);
      
      // Generar horarios base con las reservas actualizadas
      final nuevosHorarios = await Horario.generarHorarios(
        fecha: _selectedDate,
        canchaId: widget.cancha.id,
        sede: sedeId,
        reservasSnapshot: reservasSnapshot,
        cancha: _updatedCancha ?? widget.cancha,
      );
      
      // ✅ OBTENER RESERVAS RECURRENTES PARA ESTA FECHA ESPECÍFICA
      final reservasRecurrentesActivas = reservaRecurrenteProvider.obtenerReservasActivasParaFecha(
        _selectedDate, 
        sede: sedeId, 
        canchaId: widget.cancha.id
      );
      
      // ✅ PROCESAR RESERVAS RECURRENTES
      for (var reservaRecurrente in reservasRecurrentesActivas) {
        final horarioOriginal = reservaRecurrente.horario.trim();
        final horaNormalizada = _normalizarHorarioMejorado(horarioOriginal);
        
        final indiceHorario = nuevosHorarios.indexWhere((h) {
          final horaNormalizadaDisponible = _normalizarHorarioMejorado(h.horaFormateada);
          return horaNormalizadaDisponible == horaNormalizada;
        });
        
        if (indiceHorario != -1) {
          final horarioActual = nuevosHorarios[indiceHorario];
          
          if (horarioActual.estado == EstadoHorario.disponible) {
            nuevosHorarios[indiceHorario] = Horario(
              hora: horarioActual.hora,
              estado: EstadoHorario.reservado,
              esReservaRecurrente: true,
              clienteNombre: reservaRecurrente.clienteNombre,
              reservaRecurrenteData: {
                'id': reservaRecurrente.id,
                'clienteId': reservaRecurrente.clienteId,
                'clienteTelefono': reservaRecurrente.clienteTelefono,
                'montoTotal': reservaRecurrente.montoTotal,
                'montoPagado': reservaRecurrente.montoPagado,
                'precioPersonalizado': reservaRecurrente.precioPersonalizado,
                'precioOriginal': reservaRecurrente.precioOriginal,
                'descuentoAplicado': reservaRecurrente.descuentoAplicado,
                'esReservaRecurrente': true,
              },
            );
          }
        }
      }
      
      if (mounted) {
        setState(() {
          horarios = nuevosHorarios;
        });
        
        debugPrint('✅ Horarios actualizados en tiempo real');
        debugPrint('   - Disponibles: ${horarios.where((h) => h.estado == EstadoHorario.disponible).length}');
        debugPrint('   - Reservados: ${horarios.where((h) => h.estado == EstadoHorario.reservado).length}');
        debugPrint('   - Procesando pago: ${horarios.where((h) => h.estado == EstadoHorario.procesandoPago).length}');
      }
    } catch (e) {
      debugPrint('❌ Error actualizando horarios: $e');
    }
  }

  // ✅ MÉTODO DE NORMALIZACIÓN MEJORADO
  String _normalizarHorarioMejorado(String horaStr) {
    // Limpiar espacios y convertir a mayúsculas
    String normalizada = horaStr.trim().toUpperCase();
    
    // Reemplazar múltiples espacios con uno solo
    normalizada = normalizada.replaceAll(RegExp(r'\s+'), ' ');
    
    // Asegurar formato consistente con AM/PM
    if (normalizada.contains('AM') || normalizada.contains('PM')) {
      // Ya está en formato 12 horas, solo limpiar
      return normalizada;
    }
    
    // Si no tiene AM/PM, asumir que es formato 24 horas y convertir
    try {
      final parts = normalizada.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        if (hour == 0) {
          return '12:${minute.toString().padLeft(2, '0')} AM';
        } else if (hour < 12) {
          return '$hour:${minute.toString().padLeft(2, '0')} AM';
        } else if (hour == 12) {
          return '12:${minute.toString().padLeft(2, '0')} PM';
        } else {
          return '${hour - 12}:${minute.toString().padLeft(2, '0')} PM';
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error convirtiendo horario "$horaStr": $e');
    }
    
    return normalizada;
  }

  void _refreshHorariosEstados() {
    if (!mounted) return;

    bool hayCambios = false;
    for (int i = 0; i < horarios.length; i++) {
      final horario = horarios[i];
      if (horario.estado == EstadoHorario.disponible && horario.estaVencida(_selectedDate)) {
        horarios[i] = Horario(hora: horario.hora, estado: EstadoHorario.vencido);
        hayCambios = true;
      }
    }

    if (hayCambios && mounted) {
      setState(() {});
    }
  }

  void _toggleCalendar() {
    setState(() {
      _calendarExpanded = !_calendarExpanded;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (selectedDay.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No puedes seleccionar fechas pasadas'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
      return;
    }

    if (!isSameDay(_selectedDate, selectedDay)) {
      setState(() {
        _selectedDate = selectedDay;
        horarios.clear();
        _isLoading = true;
        _calendarExpanded = false;
      });

      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _loadHorarios();
        _iniciarEscuchaPromociones(); // ✅ NUEVO: Actualizar promociones al cambiar fecha
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: Provider.of<SedeProvider>(context)),
        ChangeNotifierProvider.value(value: Provider.of<CanchaProvider>(context)),
        ChangeNotifierProvider.value(value: Provider.of<ReservaRecurrenteProvider>(context)),
      ],
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_HorariosUi.bgTop, _HorariosUi.surface],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: _HorariosUi.surface,
            scrolledUnderElevation: 0,
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _HorariosUi.border),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _HorariosUi.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _HorariosUi.ink, size: 18),
                onPressed: () {
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
            title: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Reserva de cancha',
                style: GoogleFonts.montserrat(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _HorariosUi.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _HorariosUi.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _HorariosUi.accent.withValues(alpha: 0.25)),
                ),
                child: IconButton(
                  icon: Icon(Icons.refresh_rounded, color: _HorariosUi.accentDark, size: 22),
                  onPressed: () {
                    _reservasSnapshots.clear();
                    _loadHorarios();
                  },
                  tooltip: 'Actualizar horarios',
                ),
              ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCanchaInfo(),
                          const SizedBox(height: 24),
                          _buildDateSelector(),
                          const SizedBox(height: 8),
                          if (_calendarExpanded) _buildCalendar(),
                          const SizedBox(height: 16),
                          _buildHorariosHeader(),
                          const SizedBox(height: 16),
                          if (_mostrarAvisoCerrado()) _buildAvisoCerrado(),
                          if (_mostrarAvisoCerrado()) const SizedBox(height: 16),
                          _buildHorariosGridContent(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  _buildConfirmarReservaButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanchaInfo() {
    final cancha = _updatedCancha ?? widget.cancha;
    final sedeNombre = Provider.of<SedeProvider>(context).selectedSede.isNotEmpty
        ? Provider.of<SedeProvider>(context).selectedSede
        : Provider.of<SedeProvider>(context).sedeNames.isNotEmpty
            ? Provider.of<SedeProvider>(context).sedeNames.first
            : cancha.ubicacion;
    final esTechada = cancha.techada;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _HorariosUi.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _HorariosUi.border),
        boxShadow: [
          BoxShadow(
            color: _HorariosUi.ink.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              (cancha.imagen).startsWith('http') ? cancha.imagen : 'assets/demo.png',
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              cacheWidth: 152,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 76,
                  height: 76,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.sports_soccer_outlined, color: Colors.grey.shade400, size: 32),
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cancha.nombre.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _HorariosUi.ink,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: _HorariosUi.muted),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        sedeNombre,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: _HorariosUi.muted,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!cancha.disponible && cancha.motivoNoDisponible != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    cancha.motivoNoDisponible!,
                    style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: esTechada ? Colors.blue.shade50 : _HorariosUi.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: esTechada ? Colors.blue.shade200 : _HorariosUi.accent.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Text(
              esTechada ? 'TECHADA' : 'AL AIRE LIBRE',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: esTechada ? Colors.blue.shade700 : _HorariosUi.accentDark,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final canReservar = _updatedCancha?.disponible ?? widget.cancha.disponible;
    return GestureDetector(
      onTap: canReservar ? _toggleCalendar : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _HorariosUi.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _HorariosUi.border),
          boxShadow: [
            BoxShadow(
              color: _HorariosUi.ink.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _HorariosUi.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event_rounded, color: _HorariosUi.accentDark, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'FECHA',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _HorariosUi.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy', 'es').format(_selectedDate),
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _HorariosUi.ink,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _calendarExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: _HorariosUi.muted,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _HorariosUi.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _HorariosUi.border),
        boxShadow: [
          BoxShadow(
            color: _HorariosUi.ink.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 30)),
            focusedDay: _selectedDate,
            selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
            onDaySelected: _onDaySelected,
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: _HorariosUi.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: _HorariosUi.accent,
                shape: BoxShape.circle,
              ),
              outsideDaysVisible: false,
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _HorariosUi.ink,
              ),
            ),
            availableCalendarFormats: const {CalendarFormat.month: 'Mes'},
          ),
        ),
      ),
    );
  }

  Widget _buildHorariosHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.only(top: 5, bottom: 5, left: 9, right: 2),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, color: const Color.fromARGB(255, 0, 0, 0), size: 25),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Horarios',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _HorariosUi.ink,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _HorariosUi.ink,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormat('d MMM', 'es').format(_selectedDate).toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  /// True si ahora mismo el lugar no está en horario de servicio (día de hoy cerrado o hora actual fuera de ventana).
  bool _fueraDeHorarioServicioActual() {
    if (_configLugar == null) return false;
    final now = DateTime.now();
    final w = now.weekday;
    if (_configLugar!.estaCerradoDia(w)) return true;
    return !_configLugar!.estaDentroDeHorario(w, now.hour, now.minute);
  }

  /// True si no se debe permitir reservar: día del calendario cerrado, o fuera de servicio en este momento (aunque el día elegido sea futuro).
  bool _noReservarPorHorario() {
    if (_configLugar == null) return false;
    if (_configLugar!.estaCerradoDia(_selectedDate.weekday)) return true;
    return _fueraDeHorarioServicioActual();
  }

  bool _mostrarAvisoCerrado() => _noReservarPorHorario();

  /// Obtiene precio base, precio promocional y promocionId para un horario (para navegar a reserva).
  ({double precio, double? precioPromocional, String? promocionId}) _getPrecioYPromocionParaHorario(Horario horario) {
    final String day = DateFormat('EEEE', 'es').format(_selectedDate).toLowerCase();
    final String horaStr = horario.horaFormateada;
    final horaNormalizada = Horario.normalizarHora(horaStr);
    final dayPrices = (_updatedCancha?.preciosPorHorario ?? widget.cancha.preciosPorHorario)[day];
    double precio = dayPrices != null && dayPrices.containsKey(horaStr)
        ? (dayPrices[horaStr] is Map<String, dynamic>
            ? (dayPrices[horaStr]!['precio'] as num?)?.toDouble() ?? (_updatedCancha?.precio ?? widget.cancha.precio)
            : (dayPrices[horaStr] as num?)?.toDouble() ?? (_updatedCancha?.precio ?? widget.cancha.precio))
        : (_updatedCancha?.precio ?? widget.cancha.precio);
    final tienePromocion = _promocionesPorHorario.containsKey(horaNormalizada);
    final promocion = tienePromocion ? _promocionesPorHorario[horaNormalizada] : null;
    final precioPromocional = (tienePromocion && promocion != null) ? (promocion['precio_promocional'] as num?)?.toDouble() : null;
    final promocionId = (tienePromocion && promocion != null) ? promocion['id'] as String? : null;
    if (precioPromocional != null && precioPromocional > 0) precio = precioPromocional;
    return (precio: precio, precioPromocional: precioPromocional, promocionId: promocionId);
  }

  /// Botón fijo abajo: "Confirmar Reserva". Navega a reserva si hay horario seleccionado.
  Widget _buildConfirmarReservaButton() {
    final hasSelection = _selectedHorario != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _HorariosUi.surface,
        border: Border(top: BorderSide(color: _HorariosUi.border)),
        boxShadow: [
          BoxShadow(
            color: _HorariosUi.ink.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasSelection)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: _HorariosUi.accentDark, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedHorario!.horaFormateada,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _HorariosUi.ink,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
              // Bloquear si no hay WhatsApp ni cuentas (globales o de esta sede).
              final cfg = _configLugar;
              final cancha = _updatedCancha ?? widget.cancha;
              final canchaSedeId = cancha.sedeId;
              final whatsapp = cfg?.whatsappEfectivoParaSede(canchaSedeId).trim() ?? '';
              final cuentas = cfg?.textoCuentasEfectivoParaSede(canchaSedeId).trim() ?? '';
              if (whatsapp.isEmpty || cuentas.isEmpty) {
                showDialog<void>(
                  context: context,
                  barrierColor: _HorariosUi.ink.withValues(alpha: 0.45),
                  builder: (dialogContext) {
                    return Dialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: _HorariosUi.accent.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.payments_outlined, color: _HorariosUi.accentDark, size: 36),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Configuración pendiente',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _HorariosUi.ink,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Este lugar aún no tiene configurado el WhatsApp ni las cuentas de pago para esta sede. '
                              'Pide al administrador que complete la sección Configuración antes de confirmar reservas.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                height: 1.45,
                                color: _HorariosUi.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Entendido',
                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
                return;
              }

              if (_noReservarPorHorario()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Cerrado o fuera del horario de atención en este momento. No se pueden realizar reservas.',
                    ),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(12),
                  ),
                );
                return;
              }

              if (_selectedHorario == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Selecciona un horario disponible en la lista para continuar con tu reserva.'),
                    backgroundColor: Color(0xFF1A2033),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(12),
                  ),
                );
                return;
              }
              final horario = _selectedHorario!;
              final sedeProvider = Provider.of<SedeProvider>(context, listen: false);
              final sedeNombre = sedeProvider.selectedSede.isNotEmpty ? sedeProvider.selectedSede : sedeProvider.sedeNames.isNotEmpty ? sedeProvider.sedeNames.first : '';
              final sede = sedeProvider.sedes.firstWhere(
                (s) => s['id'] == sedeProvider.selectedSede || s['nombre'] == sedeProvider.selectedSede || s['nombre'] == sedeNombre,
                orElse: () => {'id': widget.cancha.sedeId, 'nombre': sedeNombre},
              );
              final sedeId = sede['id'] as String;
              final precios = _getPrecioYPromocionParaHorario(horario);
              if (mounted) {
                Navigator.push<bool>(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, animation, __) {
                      return FadeTransition(
                        opacity: animation,
                        child: DetallesScreen(
                          cancha: widget.cancha,
                          fecha: _selectedDate,
                          horario: horario,
                          sede: sedeId,
                          precioPromocional: precios.precioPromocional,
                          promocionId: precios.promocionId,
                        ),
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                ).then((reservaRealizada) {
                  if (mounted) {
                    _pulseController.stop();
                    _pulseController.reset();
                    setState(() => _selectedHorario = null);
                  }
                  if (reservaRealizada == true) {
                    _reservasSnapshots.clear();
                    _loadHorarios();
                  }
                });
              }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _HorariosUi.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Confirmar reserva',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvisoCerrado() {
    final bool cerradoDiaElegido = _configLugar!.estaCerradoDia(_selectedDate.weekday);
    final String mensaje = cerradoDiaElegido
        ? 'Cerrado este día. No se pueden realizar reservas.'
        : 'Fuera del horario de atención en este momento. No se pueden realizar reservas hasta el próximo horario de servicio.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule_send_rounded, color: Colors.orange.shade800, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              mensaje,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9A3412),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorariosGridContent() {
    if (!(_updatedCancha?.disponible ?? widget.cancha.disponible)) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_rounded, size: 70, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Cancha no disponible',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _updatedCancha?.motivoNoDisponible ?? widget.cancha.motivoNoDisponible ?? 'No especificado',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _reservasSnapshots.clear();
                  _loadHorarios();
                },
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Actualizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade300),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando horarios...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (horarios.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_rounded, size: 70, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No hay horarios disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Intenta seleccionar otra fecha',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _reservasSnapshots.clear();
                  _loadHorarios();
                },
                icon: const Icon(Icons.refresh_outlined),
                label: const Text('Actualizar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.grey.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width - 32;
    int crossAxisCount;
    const double childAspectRatio = 1.1;
    if (width < 500) {
      crossAxisCount = 3;
    } else if (width < 700) {
      crossAxisCount = 3;
    } else if (width < 900) {
      crossAxisCount = 4;
    } else {
      crossAxisCount = 5;
    }

    final sedeNombre = Provider.of<SedeProvider>(context, listen: false).selectedSede;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: childAspectRatio,
      ),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: horarios.length,
      itemBuilder: (context, index) {
        final horario = horarios[index];
        return _CardEntrance(
          delay: index * 35,
          child: _buildHorarioCard(horario, sedeNombre, index),
        );
      },
    );
  }

  Widget _buildHorarioCard(Horario horario, String sedeNombre, int index) {
    final String day = DateFormat('EEEE', 'es').format(_selectedDate).toLowerCase();
    final String horaStr = horario.horaFormateada;
    final horaNormalizada = Horario.normalizarHora(horaStr);
    final bool isSelected = horario.estado == EstadoHorario.disponible &&
        _selectedHorario != null &&
        Horario.normalizarHora(_selectedHorario!.horaFormateada) == horaNormalizada;
    
    final tienePromocion = _promocionesPorHorario.containsKey(horaNormalizada);
    final promocion = tienePromocion ? _promocionesPorHorario[horaNormalizada] : null;
    
    // Debug para verificar promociones
    if (_promocionesPorHorario.isNotEmpty && horario.estado == EstadoHorario.disponible) {
      debugPrint('🔍 Verificando promoción para: "$horaStr" (normalizado: "$horaNormalizada")');
      debugPrint('   - Promociones disponibles: ${_promocionesPorHorario.keys.toList()}');
      debugPrint('   - Tiene promoción: $tienePromocion');
    }
    
    final Map<String, Map<String, dynamic>>? dayPrices = (_updatedCancha?.preciosPorHorario ?? widget.cancha.preciosPorHorario)[day];
    double precio = dayPrices != null && dayPrices.containsKey(horaStr)
        ? (dayPrices[horaStr] is Map<String, dynamic>
            ? (dayPrices[horaStr]!['precio'] as num?)?.toDouble() ?? (_updatedCancha?.precio ?? widget.cancha.precio)
            : (dayPrices[horaStr] as num?)?.toDouble() ?? (_updatedCancha?.precio ?? widget.cancha.precio))
        : (_updatedCancha?.precio ?? widget.cancha.precio);
    
    // ✅ NUEVO: Aplicar precio promocional si está disponible y no está reservado
    if (tienePromocion && promocion != null && horario.estado == EstadoHorario.disponible) {
      precio = promocion['precio_promocional'] as double;
      debugPrint('✨ Precio promocional aplicado: S/ $precio para $horaStr');
    }

    final sedeProvider = Provider.of<SedeProvider>(context, listen: false);
    final sede = sedeProvider.sedes.firstWhere(
      (s) => s['nombre'] == sedeNombre,
      orElse: () => {'id': '', 'nombre': sedeNombre},
    );
    final sedeId = sede['id'] as String;

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: child,
        );
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Ajustes responsivos para tamaños de texto
          double fontSize = constraints.maxWidth < 90 ? 13 : 15;
          double priceFontSize = constraints.maxWidth < 90 ? 10 : 12;
          double statusFontSize = constraints.maxWidth < 90 ? 9 : 10;
          double iconSize = constraints.maxWidth < 90 ? 11 : 13;
          
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final pulse = isSelected ? _pulseAnimation.value : 0.0;
              return AnimatedScale(
            scale: (horario.estado == EstadoHorario.disponible || isSelected) ? (isSelected ? 1.0 : 1.0) : 1.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: InkWell(
            onTap: () {
              if (horario.estado == EstadoHorario.vencido) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Esta hora ya ha pasado'),
                    backgroundColor: Colors.grey.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(12),
                  ),
                );
                return;
              }

              // ✅ AGREGAR CASO PARA PROCESANDO PAGO
              if (horario.estado == EstadoHorario.procesandoPago) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Se está procesando el pago con otro cliente, si no se confirma, se liberará automáticamente'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(12),
                    duration: const Duration(seconds: 4), // Mensaje más largo
                  ),
                );
                return;
              }

              // Cerrado o fuera de horario de actividad: no permitir reservar
              if (horario.estado == EstadoHorario.disponible && _noReservarPorHorario()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Cerrado o fuera del horario de atención. No se pueden realizar reservas.'),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.all(12),
                  ),
                );
                return;
              }

              // Disponible: marcar como seleccionado (luego Confirmar Reserva navega)
              if (horario.estado == EstadoHorario.disponible) {
                if (mounted) {
                  setState(() => _selectedHorario = horario);
                  _pulseController.repeat(reverse: true);
                }
                return;
              }

              if (horario.estado == EstadoHorario.reservado) {
                if (horario.esReservaRecurrente == true && horario.reservaRecurrenteData != null) {
                  if (mounted) {
                    Navigator.push<bool>(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, animation, __) {
                          return FadeTransition(
                            opacity: animation,
                            child: ReservaDetallesScreen(
                              cancha: widget.cancha,
                              fecha: _selectedDate,
                              horario: horario,
                              sede: sedeId,
                              esReservaRecurrente: true,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    ).then((reservaRealizada) {
                      if (reservaRealizada == true) {
                        _reservasSnapshots.clear();
                        _loadHorarios();
                      }
                    });
                  }
                } else {
                  if (mounted) {
                    Navigator.push<bool>(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, animation, __) {
                          return FadeTransition(
                            opacity: animation,
                            child: ReservaDetallesScreen(
                              cancha: widget.cancha,
                              fecha: _selectedDate,
                              horario: horario,
                              sede: sedeId,
                              esReservaRecurrente: false,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 300),
                      ),
                    ).then((reservaRealizada) {
                      if (reservaRealizada == true) {
                        _reservasSnapshots.clear();
                        _loadHorarios();
                      }
                    });
                  }
                }
                return;
              }

              // Reservado: no acción adicional (el tap ya manejó navegación a detalles si aplicaba)
            },
            borderRadius: BorderRadius.circular(14),
            splashColor: isSelected
                ? Colors.white.withValues(alpha: 0.4)
                : horario.estado == EstadoHorario.reservado
                    ? Colors.green.shade100.withValues(alpha: 0.3)
                    : horario.estado == EstadoHorario.procesandoPago
                        ? Colors.red.shade100.withValues(alpha: 0.3)
                        : Colors.green.shade100.withValues(alpha: 0.5),
            highlightColor: isSelected
                ? Colors.white.withValues(alpha: 0.2)
                : horario.estado == EstadoHorario.reservado
                    ? Colors.green.shade200.withValues(alpha: 0.2)
                    : horario.estado == EstadoHorario.procesandoPago
                        ? Colors.red.shade200.withValues(alpha: 0.2)
                        : Colors.green.shade200.withValues(alpha: 0.3),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => Transform.scale(
                scale: isSelected ? 1.0 + 0.01 * _pulseAnimation.value : 1.0,
                child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? _HorariosUi.accentDark
                      : tienePromocion && horario.estado == EstadoHorario.disponible
                          ? Colors.amber.shade600
                          : horario.estado == EstadoHorario.disponible
                              ? const Color.fromARGB(255, 118, 199, 121) // borde verdoso para combinar con el tema
                              : horario.estado == EstadoHorario.reservado
                                  ? const Color(0xFF1B5E20)
                                  : horario.estado == EstadoHorario.procesandoPago
                                      ? Colors.red.shade600
                                      : Colors.grey.shade400,
                  width: isSelected ? 2.5 : (tienePromocion && horario.estado == EstadoHorario.disponible && !isSelected ? 2 : 1.5),
                ),
                color: isSelected
                    ? _HorariosUi.accent
                    : (horario.estado == EstadoHorario.disponible ? Colors.white : null),
                gradient: isSelected
                    ? null
                    : (horario.estado == EstadoHorario.disponible && tienePromocion
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.amber.shade50, Colors.orange.shade50],
                          )
                        : horario.estado == EstadoHorario.reservado
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                              )
                            : horario.estado == EstadoHorario.procesandoPago
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.red.shade600, Colors.red.shade400],
                                  )
                                : horario.estado == EstadoHorario.vencido
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.grey.shade200, Colors.grey.shade100],
                                      )
                                    : null),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: _HorariosUi.accent.withValues(alpha: 0.35 + 0.2 * pulse),
                      blurRadius: 14 + 6 * pulse,
                      spreadRadius: 1 + 2 * pulse,
                      offset: const Offset(0, 4),
                    )
                  else if (horario.estado == EstadoHorario.disponible && tienePromocion)
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  else if (horario.estado == EstadoHorario.disponible)
                    BoxShadow(
                      color: _HorariosUi.accent.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    // Fondo base (no pintar gradiente cuando está seleccionado; el contenedor exterior ya es verde)
                    Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? null
                            : (tienePromocion && horario.estado == EstadoHorario.disponible
                                ? LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.amber.shade50,
                                      Colors.orange.shade50,
                                      Colors.yellow.shade50,
                                    ],
                                  )
                                : horario.estado == EstadoHorario.disponible
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          const Color(0xFFF1F8E9),
                                          const Color(0xFFE8F5E8),
                                        ],
                                      )
                                    : horario.estado == EstadoHorario.reservado
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              const Color(0xFF1B5E20),
                                              const Color(0xFF2E7D32),
                                              const Color(0xFF388E3C),
                                            ],
                                          )
                                        : horario.estado == EstadoHorario.procesandoPago
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.red.shade600,
                                                  Colors.red.shade500,
                                                  Colors.red.shade400,
                                                ],
                                              )
                                            : LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Colors.grey.shade200,
                                                  Colors.grey.shade100,
                                                ],
                                              )),
                      ),
                    ),
                    
                    // Imagen de fondo para reservados y procesando pago
                    if (horario.estado == EstadoHorario.reservado || horario.estado == EstadoHorario.procesandoPago)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/redi22.png'),
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              opacity: 0.6,
                            ),
                          ),
                        ),
                      ),
                    
                    // Contenido principal
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  horario.horaFormateada,
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.bold,
                                    color: (horario.estado == EstadoHorario.disponible && isSelected)
                                        ? Colors.white
                                        : horario.estado == EstadoHorario.disponible
                                            ? const Color(0xFF1B5E20)
                                            : horario.estado == EstadoHorario.reservado ||
                                                horario.estado == EstadoHorario.procesandoPago
                                                ? Colors.white
                                                : Colors.black54,
                                    letterSpacing: 0.3,
                                    shadows: (horario.estado == EstadoHorario.reservado ||
                                            horario.estado == EstadoHorario.procesandoPago ||
                                            isSelected)
                                        ? [
                                            Shadow(
                                              color: Colors.black.withValues(alpha: 0.3),
                                              offset: const Offset(1, 1),
                                              blurRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            SizedBox(height: constraints.maxHeight * 0.06),
                            if (horario.estado == EstadoHorario.disponible || isSelected) ...[
                              Flexible(
                                child: tienePromocion && !isSelected
                                    ? _buildPrecioPromocional(precio, priceFontSize, constraints)
                                    : FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(precio),
                                          style: TextStyle(
                                            fontSize: priceFontSize + 1,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF1B5E20),
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                              ),
                              SizedBox(height: constraints.maxHeight * 0.05),
                            ] else
                              SizedBox(height: constraints.maxHeight * 0.05),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      horario.estado == EstadoHorario.disponible || isSelected
                                          ? Icons.check_circle_rounded
                                          : horario.estado == EstadoHorario.reservado
                                              ? Icons.sports_soccer
                                              : horario.estado == EstadoHorario.procesandoPago
                                                  ? Icons.hourglass_empty
                                                  : Icons.access_time,
                                      size: iconSize + 1,
                                      color: isSelected
                                          ? Colors.white
                                          : horario.estado == EstadoHorario.disponible
                                              ? _HorariosUi.accent
                                              : horario.estado == EstadoHorario.reservado
                                                  ? Colors.white
                                                  : horario.estado == EstadoHorario.procesandoPago
                                                      ? Colors.white
                                                      : Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      horario.estado == EstadoHorario.disponible || isSelected
                                          ? 'LIBRE'
                                          : horario.estado == EstadoHorario.reservado
                                              ? 'Reservado'
                                              : horario.estado == EstadoHorario.procesandoPago
                                                  ? 'Procesando'
                                                  : 'Vencido',
                                      style: TextStyle(
                                        fontSize: statusFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? Colors.white
                                            : horario.estado == EstadoHorario.disponible
                                                ? _HorariosUi.accent
                                                : horario.estado == EstadoHorario.reservado ||
                                                    horario.estado == EstadoHorario.procesandoPago
                                                    ? Colors.white
                                                    : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // ✅ Efecto dorado animado para promociones (solo si no está seleccionado)
                    if (tienePromocion && horario.estado == EstadoHorario.disponible && !isSelected)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _goldShimmerController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: GoldShimmerPainter(_goldShimmerController.value),
                              );
                            },
                          ),
                        ),
                      ),
                    // Efecto de brillo sutil para reservados y procesando
                    if (horario.estado == EstadoHorario.reservado || horario.estado == EstadoHorario.procesandoPago)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: constraints.maxHeight * 0.3,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
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
            },
          );
        },
      ),
    );
  }
  
  // ✅ NUEVO: Widget para precio promocional con efecto dorado
  Widget _buildPrecioPromocional(double precio, double fontSize, BoxConstraints constraints) {
    return AnimatedBuilder(
      animation: _goldShimmerController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.08,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber.shade400,
                Colors.orange.shade400,
                Colors.amber.shade500,
              ],
            ),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: Colors.amber.shade700,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.0 + (_goldShimmerController.value * 2), 0),
                end: Alignment(1.0 + (_goldShimmerController.value * 2), 0),
                colors: [
                  Colors.white,
                  Colors.yellow.shade200,
                  Colors.white,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds);
            },
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_offer,
                    size: fontSize * 0.85,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(precio),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animación de entrada escalonada para cada tarjeta del grid (fade + slide).
class _CardEntrance extends StatefulWidget {
  final int delay;
  final Widget child;

  const _CardEntrance({required this.delay, required this.child});

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ✅ NUEVO: CustomPainter para efecto dorado animado
class GoldShimmerPainter extends CustomPainter {
  final double animationValue;

  GoldShimmerPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Crear gradiente dorado que se mueve
    final gradient = LinearGradient(
      begin: Alignment(-1.0 + (animationValue * 2), 0),
      end: Alignment(1.0 + (animationValue * 2), 0),
      colors: [
        Colors.transparent,
        Colors.amber.withValues(alpha: 0.3),
        Colors.yellow.withValues(alpha: 0.4),
        Colors.amber.withValues(alpha: 0.3),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    paint.shader = gradient;
    
    // Dibujar múltiples líneas de brillo
    for (int i = 0; i < 3; i++) {
      final y = (size.height / 4) * (i + 1);
      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y);
      
      paint.strokeWidth = 2 - (i * 0.5);
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
    
    // Partículas doradas flotantes
    for (int i = 0; i < 5; i++) {
      final x = (size.width / 6) * (i + 1);
      final y = size.height * (0.2 + (i % 3) * 0.3);
      final offset = (animationValue * 2 * math.pi) + (i * 0.5);
      
      final particleY = y + math.sin(offset) * 5;
      final opacity = 0.4 + (math.sin(offset) * 0.3);
      
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.amber.withValues(alpha: opacity)
        ..shader = null;
      
      canvas.drawCircle(
        Offset(x, particleY),
        2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GoldShimmerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}