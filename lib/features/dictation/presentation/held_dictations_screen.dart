import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/held_dictations_controller.dart';
import '../application/dictation_controller.dart';
import '../domain/held_dictation.dart';

class HeldDictationsScreen extends ConsumerWidget {
  const HeldDictationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heldState = ref.watch(heldDictationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Held Dictations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed:
                () => ref.read(heldDictationsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: heldState.when(
        data: (List<HeldDictation> held) {
          if (held.isEmpty) {
            return const Center(
              child: Text(
                'No held dictations. Hold a recording to see it here.',
              ),
            );
          }
          return ListView.builder(
            itemCount: held.length,
            itemBuilder: (context, index) {
              final upload = held[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    '#${upload.sequenceNumber.toString().padLeft(6, '0')} • ${upload.tag}',
                  ),
                  subtitle: Text(
                    '${_formatDuration(upload.duration)} • ${_formatSize(upload.fileSizeBytes)}\nLast updated ${upload.updatedAt.toLocal()}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<_HeldAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _HeldAction.resume:
                          unawaited(_resumeHeld(context, ref, upload));
                          break;
                        case _HeldAction.delete:
                          ref
                              .read(heldDictationsProvider.notifier)
                              .delete(upload.id);
                          break;
                      }
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: _HeldAction.resume,
                            child: Text('Resume recording'),
                          ),
                          PopupMenuItem(
                            value: _HeldAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                  onTap: () => unawaited(_resumeHeld(context, ref, upload)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(error.toString()),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed:
                          () =>
                              ref
                                  .read(heldDictationsProvider.notifier)
                                  .refresh(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _resumeHeld(
    BuildContext context,
    WidgetRef ref,
    HeldDictation held,
  ) async {
    final controller = ref.read(dictationControllerProvider.notifier);
    try {
      await controller.resumeHeldFromStore(held.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resume dictation: $error')),
      );
    }
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
  }
}

enum _HeldAction { resume, delete }
