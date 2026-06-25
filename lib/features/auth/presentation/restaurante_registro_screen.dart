import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/core/rutas/redireccion_staff.dart';
import 'package:reserva_canchas/features/auth/data/auth_repository.dart';
import 'package:reserva_canchas/features/auth/domain/google_oauth_staff_service.dart';
import 'package:reserva_canchas/features/ciudades/data/ciudades_repository.dart';
import 'package:reserva_canchas/features/ciudades/domain/ciudad_model.dart';
import 'package:reserva_canchas/services/app_backend.dart';

/// Registro self-service: crea restaurante + dueño (admin) con plan gratis.
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

    setState(() => _procesandoGoogle = true);
    try {
      final datos = await GoogleOAuthStaffService.procesarRetornoEnRegistro(
        context,
        _repo,
        yaTieneToken: _supabaseAccessToken != null,
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
            backgroundColor: ColoresFoody.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _procesandoGoogle = false);
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
          SnackBar(content: Text(mensajeErrorHttp(e, contexto: 'cargar ciudades'))),
        );
      }
    }
  }

  Future<void> _registrar() async {
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
            backgroundColor: ColoresFoody.error,
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
        title: const Text('Correo ya registrado'),
        content: const Text(
          'Este correo ya tiene una cuenta en Foody. Inicia sesión con Google o con tu contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/admin/login');
            },
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
    return Material(
      color: ColoresFoody.secundario.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user, color: ColoresFoody.secundario, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cuenta Google conectada',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Completa los datos de tu restaurante. No necesitas contraseña.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _cargando || _procesandoGoogle;

    return Scaffold(
      backgroundColor: ColoresFoody.fondo,
      appBar: AppBar(
        title: const Text('Crear restaurante'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: ocupado ? null : () => context.go('/admin/login'),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront, size: 56, color: ColoresFoody.primario),
                          const SizedBox(height: 8),
                          Text(
                            'Empieza gratis con Foody',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Menú, pedidos y caja básica — sin tarjeta',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          if (_esGoogle) ...[
                            _chipGoogleConectado(),
                            const SizedBox(height: 16),
                          ],
                          if (!_esGoogle && AppBackend.supabaseReady) ...[
                            OutlinedButton.icon(
                              onPressed: ocupado ? null : _iniciarGoogle,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Continuar con Google'),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('o con correo'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                            ),
                          ],
                          TextFormField(
                            controller: _nombreRestaurante,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del restaurante',
                              prefixIcon: Icon(Icons.restaurant),
                            ),
                            validator: (v) =>
                                v == null || v.trim().length < 2 ? 'Mínimo 2 caracteres' : null,
                          ),
                          const SizedBox(height: 12),
                          if (_cargandoCiudades)
                            const LinearProgressIndicator()
                          else
                            DropdownButtonFormField<String>(
                              value: _ciudadId,
                              decoration: const InputDecoration(
                                labelText: 'Ciudad',
                                prefixIcon: Icon(Icons.location_city_outlined),
                              ),
                              items: _ciudades
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c.id,
                                      child: Text(c.nombre),
                                    ),
                                  )
                                  .toList(),
                              onChanged: ocupado ? null : (v) => setState(() => _ciudadId = v),
                              validator: (v) => v == null ? 'Selecciona ciudad' : null,
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nombreSucursal,
                            decoration: const InputDecoration(
                              labelText: 'Nombre de la sede',
                              prefixIcon: Icon(Icons.store),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _direccion,
                            decoration: const InputDecoration(
                              labelText: 'Dirección (opcional)',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _adminNombre,
                            decoration: const InputDecoration(
                              labelText: 'Tu nombre',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) =>
                                v == null || v.trim().length < 2 ? 'Mínimo 2 caracteres' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            readOnly: _esGoogle,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: _esGoogle,
                              fillColor: _esGoogle ? Colors.grey.shade100 : null,
                            ),
                            validator: (v) =>
                                v == null || !v.contains('@') ? 'Correo inválido' : null,
                          ),
                          if (!_esGoogle) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contrasena,
                              obscureText: _ocultar,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _ocultar ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () => setState(() => _ocultar = !_ocultar),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: ocupado || _cargandoCiudades ? null : _registrar,
                            child: _cargando
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Crear mi restaurante'),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: ocupado ? null : () => context.go('/admin/login'),
                            child: const Text('Ya tengo cuenta — iniciar sesión'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_procesandoGoogle)
            const ColoredBox(
              color: Color(0x88FFFFFF),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Verificando cuenta Google...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
