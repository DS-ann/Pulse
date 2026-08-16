import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_overlay_provider.dart';

/// Wraps a screen to prevent it from popping when the sliding player is open.
/// Instead, it closes the player.
class PlayerAwarePopScope extends ConsumerWidget {
  final Widget child;
  
  const PlayerAwarePopScope({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showPlayer = ref.watch(playerOverlayProvider);
    return PopScope(
      canPop: !showPlayer,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && showPlayer) {
          ref.read(playerOverlayProvider.notifier).state = false;
        }
      },
      child: child,
    );
  }
}
