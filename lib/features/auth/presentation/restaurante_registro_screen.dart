import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_staff_service.dart';
import 'package:reserva_canchas/features/auth/presentation/widgets/auth_form_estilo.dart';
import 'package:reserva_canchas/features/ciudades/data/ciudades_repository.dart';
import 'package:reserva_canchas/features/ciudades/domain/ciudad_model.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registro self-service — shell Analítica; lógica OAuth/API intacta.
class RestauranteRegistroScreen extends StatefulWidget {
  const RestauranteRegistroScreen({
    super.key,
    this.emailPrecargado,
    this.nombrePrecargado,
    this.supabaseAccessToken,
  });

  final String? emailPrecargado;
  final String? nombrePrecargado;
  final String? supabaseAccessToken;

  @override
  State<RestauranteRegistroScreen> createState() =>
      _RestauranteRegistroScreenState();
}

class _RestauranteRegistroScreenState extends State<RestauranteRegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreRestaurante = TextEditingController();
  final _nombreSucursal = TextEditingController(text: 'Sede principal');
  final _direccion = TextEditingController();
  final _adminNombre = TextEditingController();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _repo = AuthRepository();
  final _ciudadesRepo = CiudadesRepository();

  List<CiudadModel> _ciudades = [];
  String? _ciudadId;
  String? _supabaseAccessToken;
  bool _cargando = false;
  bool _cargandoCiudades = true;
  bool _procesandoGoogle = false;
  bool _ocultar = true;
  bool _registroAbierto = true;
  String _mensajeRegistro = '';

  bool get _esGoogle => _supabaseAccessToken != null;

  @override
  void initState() {
    super.initState();
    _supabaseAccessToken = widget.supabaseAccessToken;
    if (widget.emailPrecargado != null) {
      _email.text = widget.emailPrecargado!;
    }
    if (widget.nombrePrecargado != null) {
      _adminNombre.text = widget.nombrePrecargado!;
    }
    _cargarCiudades();
    _cargarEstadoRegistro();
    WidgetsBinding.instance.addPostFrameCallback((_) => _procesarSesionGoogle());
  }

  @override
  void dispose() {
    _nombreRestaurante.dispose();
    _nombreSucursal.dispose();
    _direccion.dispose();
    _adminNombre.dispose();
    _email.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _procesarSesionGoogle() async {
    if (!AppBackend.supabaseReady || _procesandoGoogle) return;

    final errorOAuth = GoogleOAuthStaffService.errorOAuthEnUrl();
    if (errorOAuth != null && mounted) {
      await GoogleOAuthStaffService.limpiarMarcadoresOAuth();
      GoogleOAuthStaffService.limpiarQueryOAuthEnRuta(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeErrorHttp(AuthException(errorOAuth), contexto: 'Google'),
          ),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
      return;
    }

    if (widget.supabaseAccessToken != null &&
        !await GoogleOAuthStaffService.hayRetornoOAuthPendiente()) {
      return;
    }

    setState(() => _procesandoGoogle = true);
    try {
      final datos = await GoogleOAuthStaffService.procesarRetornoEnRegistro(
        context,
        _repo,
      );
      if (datos != null && mounted) {
        setState(() {
          _supabaseAccessToken = datos.accessToken;
          _email.text = datos.email;
          if (datos.nombre != null && datos.nombre!.trim().isNotEmpty) {
            _adminNombre.text = datos.nombre!.trim();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'Google')),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoGoogle = false);
    }
  }

  Future<void> _cargarEstadoRegistro() async {
    try {
      final e = await _repo.estadoRegistroRestaurante();
      if (!mounted) return;
      setState(() {
        _registroAbierto = e.abierto;
        _mensajeRegistro = e.mensaje;
      });
    } catch (_) {
      // ponytail: si falla el probe, no bloqueamos el formulario
    }
  }

  Future<void> _cargarCiudades() async {
    try {
      final lista = await _ciudadesRepo.listarActivas();
      if (!mounted) return;
      setState(() {
        _ciudades = lista;
        _cargandoCiudades = false;
        if (lista.isNotEmpty && _ciudadId == null) {
          _ciudadId = lista.first.id;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoCiudades = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeErrorHttp(e, contexto: 'cargar ciudades')),
          ),
        );
      }
    }
  }

  Future<void> _registrar() async {
    if (!_registroAbierto) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mensajeRegistro.isEmpty
                ? 'Registro temporalmente cerrado'
                : _mensajeRegistro,
          ),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_ciudadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ciudad')),
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      final r = await _repo.registroRestaurante(
        ciudadId: _ciudadId!,
        nombreRestaurante: _nombreRestaurante.text.trim(),
        adminNombre: _adminNombre.text.trim(),
        adminEmail: _email.text.trim(),
        contrasena: _esGoogle ? null : _contrasena.text,
        nombreSucursal: _nombreSucursal.text.trim(),
        direccionSucursal:
            _direccion.text.trim().isEmpty ? null : _direccion.text.trim(),
        supabaseAccessToken: _supabaseAccessToken,
        proveedorAuth: _esGoogle ? 'google' : 'correo',
      );
      if (!mounted) return;
      irDashboardStaff(context, r.dashboard);
    } catch (e) {
      if (!mounted) return;
      final msg = mensajeErrorHttp(e, contexto: 'registro');
      if (msg.contains('ya está registrado')) {
        _mostrarDialogoYaRegistrado();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AnaliticaTokens.alertas,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDialogoYaRegistrado() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AnaliticaTokens.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Correo ya registrado',
          style: TextStyle(color: AnaliticaTokens.ink),
        ),
        content: const Text(
          'Este correo ya tiene una cuenta en Foody. Inicia sesión con Google o con tu contraseña.',
          style: TextStyle(color: AnaliticaTokens.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AnaliticaTokens.inkMuted),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/admin/login');
            },
            style: FilledButton.styleFrom(backgroundColor: AnaliticaTokens.ink),
            child: const Text('Ir a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _iniciarGoogle() async {
    if (!AppBackend.supabaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google no disponible: Supabase no está configurado'),
        ),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await GoogleOAuthStaffService.iniciarOAuth(OAuthDestinoStaff.registro);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'Google'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _chipGoogleConectado() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AnaliticaTokens.inventario.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AnaliticaTokens.inventario.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user, color: AnaliticaTokens.inventario, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta Google conectada',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AnaliticaTokens.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Completa los datos de tu restaurante. No necesitas contraseña.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AnaliticaTokens.inkMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _procesandoGoogle;
    const estiloCampo = TextStyle(fontSize: 14, color: AnaliticaTokens.ink);

    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AnaliticaTokens.surface,
                    AnaliticaTokens.canvas,
                    AnaliticaTokens.surfaceMuted.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: 'Volver',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AnaliticaTokens.ink,
                ),
                onPressed:
                    ocupado ? null : () => context.go('/admin/login'),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                  decoration: BoxDecoration(
                    color: AnaliticaTokens.surface,
                    borderRadius: BorderRadius.circular(AnaliticaTokens.r16),
                    border: Border.all(color: AnaliticaTokens.border),
                    boxShadow: AnaliticaTokens.shadowLift,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AnaliticaTokens.ink,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Empieza gratis con Foody',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: AnaliticaTokens.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Menú, pedidos y caja básica — sin tarjeta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AnaliticaTokens.inkMuted,
                          ),
                        ),
                        if (!_registroAbierto && _mensajeRegistro.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AnaliticaTokens.alertas.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AnaliticaTokens.alertas.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              _mensajeRegistro,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: AnaliticaTokens.ink,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        if (_esGoogle) ...[
                          _chipGoogleConectado(),
                          const SizedBox(height: 16),
                        ],
                        if (!_esGoogle && AppBackend.supabaseReady) ...[
                          OutlinedButton.icon(
                            onPressed: ocupado ? null : _iniciarGoogle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AnaliticaTokens.ink,
                              side: const BorderSide(
                                color: AnaliticaTokens.border,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.g_mobiledata, size: 26),
                            label: const Text(
                              'Continuar con Google',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Divider(color: AnaliticaTokens.border),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: Text(
                                    'o con correo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AnaliticaTokens.inkSoft,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: AnaliticaTokens.border),
                                ),
                              ],
                            ),
                          ),
                        ],
                        TextFormField(
                          controller: _nombreRestaurante,
                          style: estiloCampo,
                          decoration: AuthFormEstilo.campo(
                            label: 'Nombre del restaurante',
                            prefixIcon: const Icon(Icons.restaurant),
                          ),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Mínimo 2 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (_cargandoCiudades)
                          const LinearProgressIndicator(
                            color: AnaliticaTokens.ink,
                            backgroundColor: AnaliticaTokens.surfaceMuted,
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: _ciudadId,
                            style: estiloCampo,
                            dropdownColor: AnaliticaTokens.surface,
                            decoration: AuthFormEstilo.campo(
                              label: 'Ciudad',
                              prefixIcon:
                                  const Icon(Icons.location_city_outlined),
                            ),
                            items: _ciudades
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.nombre),
                                  ),
                                )
                                .toList(),
                            onChanged: ocupado
                                ? null
                                : (v) => setState(() => _ciudadId = v),
                            validator: (v) =>
                                v == null ? 'Selecciona ciudad' : null,
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nombreSucursal,
                          style: estiloCampo,
                          decoration: AuthFormEstilo.campo(
                            label: 'Nombre de la sede',
                            prefixIcon: const Icon(Icons.store_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _direccion,
                          style: estiloCampo,
                          decoration: AuthFormEstilo.campo(
                            label: 'Dirección (opcional)',
                            prefixIcon: const Icon(Icons.place_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _adminNombre,
                          style: estiloCampo,
                          decoration: AuthFormEstilo.campo(
                            label: 'Tu nombre',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.trim().length < 2
                              ? 'Mínimo 2 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _email,
                          readOnly: _esGoogle,
                          keyboardType: TextInputType.emailAddress,
                          style: estiloCampo,
                          decoration: AuthFormEstilo.campo(
                            label: 'Correo',
                            prefixIcon: const Icon(Icons.email_outlined),
                            filledMuted: true,
                          ),
                          validator: (v) => v == null || !v.contains('@')
                              ? 'Correo inválido'
                              : null,
                        ),
                        if (!_esGoogle) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _contrasena,
                            obscureText: _ocultar,
                            style: estiloCampo,
                            decoration: AuthFormEstilo.campo(
                              label: 'Contraseña',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultar
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AnaliticaTokens.inkSoft,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _ocultar = !_ocultar),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6
                                ? 'Mínimo 6 caracteres'
                                : null,
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: ocupado ||
                                    _cargandoCiudades ||
                                    !_registroAbierto
                                ? null
                                : _registrar,
                            style: FilledButton.styleFrom(
                              backgroundColor: AnaliticaTokens.ink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AnaliticaTokens.r12,
                                ),
                              ),
                            ),
                            child: _cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _registroAbierto
                                        ? 'Crear mi restaurante'
                                        : 'Registro cerrado',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed:
                              ocupado ? null : () => context.go('/admin/login'),
                          style: TextButton.styleFrom(
                            foregroundColor: AnaliticaTokens.inkMuted,
                          ),
                          child: const Text(
                            'Ya tengo cuenta — iniciar sesión',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_procesandoGoogle)
            ColoredBox(
              color: AnaliticaTokens.surface.withValues(alpha: 0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AnaliticaTokens.ink),
                    SizedBox(height: 12),
                    Text(
                      'Verificando cuenta Google…',
                      style: TextStyle(
                        fontSize: 13,
                        color: AnaliticaTokens.inkMuted,
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
