import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/theme.dart';

/// Mapa a pantalla completa + overlays + sheet (como Gowayki GO).
class MapLayout extends StatelessWidget {
  const MapLayout({
    super.key,
    required this.map,
    this.overlays = const [],
    this.sheet,
  });

  final Widget map;
  final List<Widget> overlays;
  final Widget? sheet;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        resizeToAvoidBottomInset: false,
        body: Stack(fit: StackFit.expand, children: [map, ...overlays, ?sheet]),
      ),
    );
  }
}

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    this.topLeft,
    this.topRight,
    this.bottomLeft,
    this.bottomRight,
    this.centerRight,
    this.bottomInset = 0,
  });

  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottomLeft;
  final Widget? bottomRight;
  final Widget? centerRight;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + AppSpacing.sm;
    final bottom = bottomInset + AppSpacing.sm;
    return Stack(
      children: [
        if (topLeft != null)
          Positioned(top: top, left: AppSpacing.md, child: topLeft!),
        if (topRight != null)
          Positioned(top: top, right: AppSpacing.md, child: topRight!),
        if (bottomLeft != null)
          Positioned(bottom: bottom, left: AppSpacing.md, child: bottomLeft!),
        if (bottomRight != null)
          Positioned(bottom: bottom, right: AppSpacing.md, child: bottomRight!),
        if (centerRight != null)
          Positioned(
            top: 0,
            bottom: bottomInset,
            right: AppSpacing.md,
            child: Center(child: centerRight),
          ),
      ],
    );
  }
}

class MapRoundButton extends StatelessWidget {
  const MapRoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary
          : Theme.of(context).colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: selected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }
}
