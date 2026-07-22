import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether the full-screen player overlay is visible.
/// This lives completely outside GoRouter to avoid corrupting navigation state.
final playerOverlayProvider = StateProvider<bool>((ref) => false);
