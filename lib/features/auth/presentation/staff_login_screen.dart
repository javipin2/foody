import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/config/app_flavor.dart';
import 'package:reserva_canchas/core/navegacion/abrir_app_cliente.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/core/sesion/sesion_staff_service.dart';
import 'package:reserva_canchas/features/analitica/presentation/widgets/analitica_tokens.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_deep_link_service.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_staff_service.dart';
import 'package:reserva_canchas/features/auth/presentation/widgets/auth_form_estilo.dart';
import 'package:reserva_canchas/services/app_backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Login staff Foody — shell Analítica (ink); auth/OAuth intactos.
class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _contrasena = TextEditingController();
  final _repo = AuthRepository();
  bool _cargando = false;
  bool _procesandoGoogle = false;
  bool _ocultar = true;
  bool _demoExpandido = false;

  late AnimationController _anim;
  late Animation<double> _fade;
  late AnimationController _shake;
  late Animation<double> _shakeAnim;
  StreamSubscription<void>? _subOAuthRetorno;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = CurvedAnimation(parent: _shake, curve: Curves.elasticInOut);
    _anim.forward();
    _subOAuthRetorno = GoogleOAuthDeepLinkService.onRetorno.listen((_) {
      if (mounted) _procesarRetornoGoogle();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializarPantalla());
  }

  /// JWT existente → dashboard; si no, solo OAuth recién iniciado (no sesión Supabase vieja).
  Future<void> _inicializarPantalla() async {
    final errorOAuth = GoogleOAuthStaffService.errorOAuthEnUrl();
    if (errorOAuth != null) {
      await GoogleOAuthStaffService.limpiarMarcadoresOAuth();
      if (!mounted) return;
      GoogleOAuthStaffService.limpiarQueryOAuthEnRuta(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mensajeErrorHttp(AuthException(errorOAuth), contexto: 'Google'),
          ),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
    }

    final sesion = await SesionStaffService.cargar();
    if (!mounted) return;
    if (sesion != null) {
      irDashboardStaff(context, sesion.dashboard);
      return;
    }
    await _procesarRetornoGoogle();
  }

  Future<void> _procesarRetornoGoogle() async {
    if (!AppBackend.supabaseReady || _cargando || _procesandoGoogle) return;
    if (!await GoogleOAuthStaffService.hayRetornoOAuthPendiente()) return;
    if (!mounted) return;

    setState(() => _procesandoGoogle = true);
    try {
      await GoogleOAuthStaffService.procesarRetornoEnLogin(context, _repo);
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

  Future<void> _googleOAuth() async {
    if (!AppBackend.supabaseReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google no disponible en este entorno')),
      );
      return;
    }
    setState(() => _cargando = true);
    try {
      await GoogleOAuthStaffService.iniciarOAuth(OAuthDestinoStaff.login);
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

  @override
  void dispose() {
    _subOAuthRetorno?.cancel();
    _anim.dispose();
    _shake.dispose();
    _email.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (!_formKey.currentState!.validate()) {
      _shake.forward(from: 0).then((_) => _shake.reset());
      return;
    }
    setState(() => _cargando = true);
    try {
      final r = await _repo.login(
        email: _email.text.trim(),
        contrasena: _contrasena.text,
      );
      if (!mounted) return;
      irDashboardStaff(context, r.dashboard);
    } catch (e) {
      if (!mounted) return;
      _shake.forward(from: 0).then((_) => _shake.reset());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeErrorHttp(e, contexto: 'iniciar sesión')),
          backgroundColor: AnaliticaTokens.alertas,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _procesandoGoogle;
    final desdeCliente = AppFlavor.actual.esCliente;

    return Scaffold(
      backgroundColor: AnaliticaTokens.canvas,
      body: Stack(
        children: [
          // Ambiente sutil (no flat).
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
          if (desdeCliente)
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
                      ocupado ? null : () => AbrirAppCliente.ejecutar(context),
                ),
              ),
            ),
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final offset = _shakeAnim.value *
                        8 *
                        (_shake.status.isAnimating ? 1 : 0);
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      decoration: BoxDecoration(
                        color: AnaliticaTokens.surface,
                        borderRadius:
                            BorderRadius.circular(AnaliticaTokens.r16),
                        border: Border.all(color: AnaliticaTokens.border),
                        boxShadow: AnaliticaTokens.shadowLift,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  Icons.restaurant_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Foody',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                                color: AnaliticaTokens.ink,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Acceso staff',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AnaliticaTokens.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AnaliticaTokens.ink,
                              ),
                              decoration: AuthFormEstilo.campo(
                                label: 'Correo',
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: (v) => v == null || !v.contains('@')
                                  ? 'Correo inválido'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contrasena,
                              obscureText: _ocultar,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AnaliticaTokens.ink,
                              ),
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
                              validator: (v) => v == null || v.length < 4
                                  ? 'Mínimo 4 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            if (AppBackend.supabaseReady) ...[
                              OutlinedButton.icon(
                                onPressed: ocupado ? null : _googleOAuth,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AnaliticaTokens.ink,
                                  side: const BorderSide(
                                    color: AnaliticaTokens.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
                                      child: Divider(
                                        color: AnaliticaTokens.border,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'o',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AnaliticaTokens.inkSoft,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: AnaliticaTokens.border,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton(
                                onPressed: ocupado ? null : _ingresar,
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
                                    : const Text(
                                        'Ingresar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (kDebugMode) ...[
                              Material(
                                color: AnaliticaTokens.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () => setState(
                                    () => _demoExpandido = !_demoExpandido,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: AnaliticaTokens.inkSoft,
                                        ),
                                        const SizedBox(width: 8),
                                        const Expanded(
                                          child: Text(
                                            'Cuentas demo',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AnaliticaTokens.inkMuted,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          _demoExpandido
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          size: 18,
                                          color: AnaliticaTokens.inkSoft,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (_demoExpandido) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AnaliticaTokens.border,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'admin@foody.demo · super@foody.demo · cocina@foody.demo\n'
                                    'Empleado: tu correo Foody (ej. domi@foody.demo)\n'
                                    'Cajero/mesero: Foody Control → Usuarios\n'
                                    'Contraseña demo: 123456\n'
                                    'Independiente: botón abajo → repartidor@foody.demo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.45,
                                      color: AnaliticaTokens.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: ocupado
                                  ? null
                                  : () => context.go('/admin/registro'),
                              style: TextButton.styleFrom(
                                foregroundColor: AnaliticaTokens.ink,
                              ),
                              child: const Text(
                                'Crear restaurante gratis',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            TextButton(
                              onPressed: ocupado
                                  ? null
                                  : () => context.go('/domiciliario/login'),
                              style: TextButton.styleFrom(
                                foregroundColor: AnaliticaTokens.inkMuted,
                              ),
                              child: const Text(
                                'Soy repartidor independiente',
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      'Conectando con Google…',
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
