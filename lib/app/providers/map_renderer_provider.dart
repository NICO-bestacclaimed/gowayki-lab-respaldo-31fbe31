import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/explorer/presentation/widgets/explorer_map.dart';

/// Boundary for testing app UI without an Android/iOS rendering surface.
final explorerMapRendererProvider = Provider<Widget Function(ExplorerMap)>(
  (ref) =>
      (map) => map,
);
