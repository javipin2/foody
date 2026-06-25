import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Música ambiental al entrar en Lugares: sigue sonando al navegar a otras pantallas
/// hasta que el usuario cierre la app (o silencie desde el botón).
///
/// **Interruptor global:** con [ambientMusicEnabled] en `false` no se reproduce nada, no se muestra
/// el botón de volumen en Lugares y el resto de llamadas no hacen efecto. Pon `true` para reactivar
/// sin reescribir la integración.
///
/// La pista **solo se reinicia desde el principio** al entrar a Lugares con
/// [ensurePlayingFromLugaresEntry] y `fromCiudadFlow: true` (sesión Ciudades → Lugares).
/// Si vuelves a Lugares desde sede/canchas/etc., no se llama a resume/seek: la música sigue igual.
/// Con [ReleaseMode.loop] la canción vuelve a sonar al terminar; al silenciar y activar, se reanuda
/// desde donde quedó (salvo un nuevo entrada desde Ciudades, que vuelve al inicio).
class LugarAmbientMusicService extends ChangeNotifier {
  LugarAmbientMusicService._();
  static final LugarAmbientMusicService instance = LugarAmbientMusicService._();

  /// `false` = música y UI desactivadas temporalmente. `true` = comportamiento completo.
  static const bool ambientMusicEnabled = false;

  static const String _assetRelative =
      'Michel Teló - Ai Se Eu Te Pego (LetraLyrics).mp3';
  static const double _volumeMedio = 0.1;

  AudioPlayer? _player;
  bool _initialized = false;
  bool _muted = false;
  bool _starting = false;

  bool get isMuted => _muted;

  /// [fromCiudadFlow]: `true` solo al abrir Lugares desde la pantalla de **Ciudades** (o splash
  /// equivalente). Reinicia la pista desde el inicio. Con `false`, si el audio ya está iniciado,
  /// no se modifica (evita repetir al volver desde sede, canchas, etc.).
  Future<void> ensurePlayingFromLugaresEntry({required bool fromCiudadFlow}) async {
    if (!ambientMusicEnabled) return;
    if (_starting) return;
    _starting = true;
    try {
      if (_initialized && _player != null) {
        if (fromCiudadFlow) {
          await _player!.seek(Duration.zero);
          if (!_muted) {
            await _player!.resume();
          }
        }
        return;
      }

      final player = AudioPlayer();
      _player = player;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_muted ? 0.0 : _volumeMedio);
      await player.play(AssetSource(_assetRelative));
      _initialized = true;
      if (_muted) {
        await player.pause();
      }
    } catch (e, st) {
      debugPrint('LugarAmbientMusicService: error al iniciar audio: $e\n$st');
    } finally {
      _starting = false;
    }
  }

  /// Detiene la música al entrar en pantallas administrativas (p. ej. acceso admin desde Lugares).
  /// Deja el estado como silenciado para que el icono coincida; el usuario puede reactivarla al volver.
  Future<void> stopForAdministrativeSession() async {
    if (!ambientMusicEnabled) return;
    final p = _player;
    if (p == null) {
      _muted = true;
      notifyListeners();
      return;
    }
    try {
      await p.pause();
      _muted = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('LugarAmbientMusicService: error al detener por admin: $e\n$st');
    }
  }

  Future<void> toggleMuted() async {
    if (!ambientMusicEnabled) return;
    _muted = !_muted;
    notifyListeners();

    final p = _player;
    if (p == null) {
      return;
    }
    try {
      if (_muted) {
        await p.pause();
      } else {
        await p.setVolume(_volumeMedio);
        await p.resume();
      }
    } catch (e, st) {
      debugPrint('LugarAmbientMusicService: error al alternar silencio: $e\n$st');
    }
  }
}
