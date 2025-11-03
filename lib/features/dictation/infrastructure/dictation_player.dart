import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

abstract class DictationPlayer {
  Future<void> load(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Stream<Duration> positionStream();
  Stream<Duration?> durationStream();
  Stream<PlayerState> stateStream();
  Future<Duration?> position();
  Future<void> dispose();
}

class JustAudioDictationPlayer implements DictationPlayer {
  JustAudioDictationPlayer([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Dictation audio file missing', filePath);
    }
    await _player.stop();
    final source = AudioSource.uri(Uri.file(file.path));
    await _player.setAudioSource(source);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> positionStream() => _player.positionStream;

  @override
  Stream<Duration?> durationStream() => _player.durationStream;

  @override
  Stream<PlayerState> stateStream() => _player.playerStateStream;

  @override
  Future<Duration?> position() async => _player.position;

  @override
  Future<void> dispose() => _player.dispose();
}

final dictationPlayerProvider = Provider<DictationPlayer>((ref) {
  final player = JustAudioDictationPlayer();
  ref.onDispose(player.dispose);
  return player;
});
