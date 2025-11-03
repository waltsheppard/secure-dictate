import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_session/audio_session.dart';
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
  JustAudioDictationPlayer([AudioPlayer? player]) : _player = player ?? AudioPlayer() {
    _initSession();
  }

  final AudioPlayer _player;
  Future<void>? _sessionInit;

  void _initSession() {
    _sessionInit ??= () async {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: {
            AVAudioSessionCategoryOptions.defaultToSpeaker,
            AVAudioSessionCategoryOptions.mixWithOthers,
            AVAudioSessionCategoryOptions.allowBluetooth,
          },
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: true,
        ),
      );
    }();
  }

  @override
  Future<void> load(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Dictation audio file missing', filePath);
    }
    if (_sessionInit != null) {
      await _sessionInit;
    }
    final session = await AudioSession.instance;
    if (!session.isActive) {
      await session.setActive(true);
    }
    await _player.stop();
    final source = AudioSource.file(file.path);
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
