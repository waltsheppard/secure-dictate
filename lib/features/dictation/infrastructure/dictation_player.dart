import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

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
  JustAudioDictationPlayer([AudioPlayer? player])
    : _player = player ?? AudioPlayer() {
    _initSession();
  }

  final AudioPlayer _player;
  Future<void>? _sessionInit;
  File? _playbackCopy;
  bool _sessionActivated = false;

  void _initSession() {
    _sessionInit ??= () async {
      final session = await AudioSession.instance;
      final config = AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: true,
      );
      await session.configure(config);
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
    await session.setActive(
      true,
      avAudioSessionSetActiveOptions:
          AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
    );
    _sessionActivated = true;
    await _player.stop();
    await _deletePlaybackCopy();
    File playbackTarget;
    try {
      playbackTarget = await _preparePlaybackCopy(file);
    } on FileSystemException catch (error) {
      throw FileSystemException(
        'Unable to stage dictation for playback: ${error.message}',
        error.path,
      );
    }
    try {
      await _player.setFilePath(playbackTarget.path);
      _playbackCopy = playbackTarget;
    } on PlayerException catch (error) {
      final stat = await playbackTarget.stat();
      throw FileSystemException(
        'Unable to load dictation audio (${error.code}): ${error.message} (size=${stat.size})',
        playbackTarget.path,
      );
    } on PlayerInterruptedException catch (error) {
      throw FileSystemException(
        'Playback interrupted: ${error.message ?? 'unknown reason'}',
        playbackTarget.path,
      );
    }
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> stop() async {
    await _player.stop();
    final session = await AudioSession.instance;
    if (_sessionActivated) {
      try {
        await session.setActive(false);
      } on PlatformException catch (error) {
        debugPrint('Failed to deactivate audio session: ${error.message}');
      } finally {
        _sessionActivated = false;
      }
    }
    await _deletePlaybackCopy();
  }

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
  Future<void> dispose() async {
    await _player.dispose();
    await _deletePlaybackCopy();
    if (_sessionActivated) {
      final session = await AudioSession.instance;
      try {
        await session.setActive(false);
      } on PlatformException catch (error) {
        debugPrint(
          'Failed to deactivate audio session on dispose: ${error.message}',
        );
      } finally {
        _sessionActivated = false;
      }
    }
  }

  Future<File> _preparePlaybackCopy(File source) async {
    final directory = source.parent;
    final baseName = p.basenameWithoutExtension(source.path);
    final extension = p.extension(source.path);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final copyPath = p.join(
      directory.path,
      '${baseName}_playback_$timestamp$extension',
    );
    final copyFile = File(copyPath);
    if (await copyFile.exists()) {
      await copyFile.delete();
    }
    final bytes = await source.readAsBytes();
    if (bytes.isEmpty) {
      throw const FileSystemException('Dictation audio file is empty');
    }
    if (bytes.length >= 44) {
      final byteData = ByteData.sublistView(bytes);
      final dataSize = bytes.length - 44;
      final chunkSize = dataSize + 36;
      byteData.setUint32(4, chunkSize, Endian.little);
      byteData.setUint32(40, dataSize, Endian.little);
    }
    await copyFile.writeAsBytes(bytes, flush: true);
    return copyFile;
  }

  Future<void> _deletePlaybackCopy() async {
    final file = _playbackCopy;
    if (file != null) {
      _playbackCopy = null;
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // best effort cleanup
        }
      }
    }
  }
}

final dictationPlayerProvider = Provider<DictationPlayer>((ref) {
  final player = JustAudioDictationPlayer();
  ref.onDispose(player.dispose);
  return player;
});
