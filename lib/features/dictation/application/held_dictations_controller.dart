import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../domain/held_dictation.dart';
import '../infrastructure/dictation_local_store.dart';

class HeldDictationsController
    extends StateNotifier<AsyncValue<List<HeldDictation>>> {
  HeldDictationsController(this._ref) : super(const AsyncLoading()) {
    refresh();
  }

  final Ref _ref;

  DictationLocalStore get _store => _ref.read(dictationLocalStoreProvider);

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final held = await _store.loadHeld();
      state = AsyncData(held);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> delete(String dictationId) async {
    final removed = await _store.removeHeld(dictationId);
    if (removed != null) {
      final file = File(removed.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      for (final segment in removed.segments) {
        final segmentFile = File(segment);
        if (await segmentFile.exists()) {
          await segmentFile.delete();
        }
      }
    }
    await refresh();
  }

  Future<void> resume(String dictationId) async {
    await _store.removeHeld(dictationId);
    await refresh();
  }
}

final heldDictationsProvider = StateNotifierProvider<
  HeldDictationsController,
  AsyncValue<List<HeldDictation>>
>((ref) => HeldDictationsController(ref));
