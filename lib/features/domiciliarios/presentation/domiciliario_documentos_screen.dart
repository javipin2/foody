import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:reserva_canchas/core/constantes/colores_foody.dart';
import 'package:reserva_canchas/core/red/mensaje_error_http.dart';
import 'package:reserva_canchas/features/domiciliarios/data/domiciliarios_independientes_repository.dart';

/// Tipos obligatorios de documentación del repartidor independiente.
const tiposDocumentoDomiciliario = {
  'cedula_frente': 'Cédula (frente)',
  'cedula_reverso': 'Cédula (reverso)',
  'foto_vehiculo': 'Foto del vehículo',
};

/// Subida de documentos tras registro (cuenta pendiente_verificacion).
class DomiciliarioDocumentosScreen extends StatefulWidget {
  const DomiciliarioDocumentosScreen({super.key});

  @override
  State<DomiciliarioDocumentosScreen> createState() =>
      _DomiciliarioDocumentosScreenState();
}

class _DomiciliarioDocumentosScreenState extends State<DomiciliarioDocumentosScreen> {
  final _repo = DomiciliariosIndependientesRepository();
  final _picker = ImagePicker();

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _resumen;
  String? _subiendoTipo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resumen = await _repo.resumenDocumentos();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeErrorHttp(e);
        _cargando = false;
      });
    }
  }

  Map<String, dynamic>? _docPorTipo(String tipo) {
    final docs = _resumen?['documentos'] as List<dynamic>? ?? [];
    for (final raw in docs) {
      if (raw is! Map) continue;
      final doc = Map<String, dynamic>.from(raw);
      if (doc['tipo'] == tipo) return doc;
    }
    return null;
  }

  Future<void> _subir(String tipo) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _subiendoTipo = tipo);
    try {
      final bytes = await picked.readAsBytes();
      await _repo.subirDocumento(tipo, bytes, picked.name);
      if (!mounted) return;
      await _cargar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${tiposDocumentoDomiciliario[tipo]} enviado'),
          backgroundColor: ColoresFoody.exito,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensajeErrorHttp(e))),
      );
    } finally {
      if (mounted) setState(() => _subiendoTipo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completo = _resumen?['completo'] == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Documentos de verificación')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Sube estos documentos para activar tu cuenta',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un administrador Foody los revisará. Te notificaremos cuando puedas trabajar.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: ColoresFoody.error)),
                  ],
                  const SizedBox(height: 16),
                  ...tiposDocumentoDomiciliario.entries.map((e) {
                    final doc = _docPorTipo(e.key);
                    return _tarjetaDocumento(e.key, e.value, doc);
                  }),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: completo ? () => context.go('/domiciliario/espera') : null,
                    child: Text(
                      completo
                          ? 'Continuar — esperar aprobación'
                          : 'Sube los 3 documentos para continuar',
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaDocumento(
    String tipo,
    String etiqueta,
    Map<String, dynamic>? doc,
  ) {
    final estado = doc?['estado'] as String?;
    final url = doc?['url'] as String?;
    final motivo = doc?['motivo_rechazo'] as String?;
    final subiendo = _subiendoTipo == tipo;

    Color chipColor;
    String chipText;
    switch (estado) {
      case 'aprobado':
        chipColor = ColoresFoody.exito;
        chipText = 'Aprobado';
        break;
      case 'rechazado':
        chipColor = ColoresFoody.error;
        chipText = 'Rechazado';
        break;
      case 'pendiente':
        chipColor = ColoresFoody.acento;
        chipText = 'En revisión';
        break;
      default:
        chipColor = Colors.grey;
        chipText = 'Falta';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      etiqueta,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      chipText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: chipColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (motivo != null && estado == 'rechazado') ...[
                const SizedBox(height: 6),
                Text(
                  motivo,
                  style: const TextStyle(fontSize: 12, color: ColoresFoody.error),
                ),
              ],
              if (url != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 48,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: subiendo || estado == 'aprobado'
                      ? null
                      : () => _subir(tipo),
                  icon: subiendo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    estado == 'rechazado'
                        ? 'Volver a subir'
                        : estado == null
                            ? 'Subir foto'
                            : 'Reemplazar foto',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
