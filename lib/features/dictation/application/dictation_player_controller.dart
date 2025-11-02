import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod/riverpod.dart' show StateNotifier, StateNotifierProvider;

import '../infrastructure/dictation_player.dart';

class DictationPlayerState {
  const DictationPlayerState({
    required this.filePath,
    required this.isLoading,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.errorMessage,
  });

  final String? filePath;
  final bool isLoading;
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final String? errorMessage;

  factory DictationPlayerState.initial() => const DictationPlayerState(
        filePath: null,
        isLoading: false,
        isPlaying: false,
        position: Duration.zero,
        duration: null,
        errorMessage: null,
      );

  DictationPlayerState copyWith({
    String? filePath,
    bool? isLoading,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DictationPlayerState(
      filePath: filePath ?? this.filePath,
      isLoading: isLoading ?? this.isLoading,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  bool get canPlay => filePath != null && !isLoading;
}

class DictationPlayerController extends StateNotifier<DictationPlayerState> {
  DictationPlayerController(this._ref) : super(DictationPlayerState.initial());

  final Ref _ref;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;

  DictationPlayer get _player => _ref.read(dictationPlayerProvider);

  Future<void> load(String filePath) async {
    if (state.filePath == filePath) return;
    state = state.copyWith(
      filePath: filePath,
      isLoading: true,
      clearError: true,
      position: Duration.zero,
      duration: null,
    );
    try {
      await _player.load(filePath);
      _bindStreams();
      state = state.copyWith(isLoading: false, position: Duration.zero);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> play() async {
    if (!state.canPlay) return;
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    state = state.copyWith(isPlaying: false, position: Duration.zero);
  }

  Future<void> seek(Duration position) async {
    if (state.filePath == null) return;
    await _player.seek(position);
  }

  void _bindStreams() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();

    _positionSub = _player.positionStream().listen((position) {
      state = state.copyWith(position: position);
    });
    _durationSub = _player.durationStream().listen((duration) {
      state = state.copyWith(duration: duration);
    });
    _stateSub = _player.stateStream().listen((playerState) {
      state = state.copyWith(isPlaying: playerState.playing);
      if (playerState.processingState == ProcessingState.completed) {
        state = state.copyWith(isPlaying: false, position: Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }
}

final dictationPlayerControllerProvider =
    StateNotifierProvider<DictationPlayerController, DictationPlayerState>(
  (ref) => DictationPlayerController(ref),
);
