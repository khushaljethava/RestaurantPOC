import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/ros_theme.dart';

/// The aurora backdrop every glass surface sits on.
/// Installed once in `MaterialApp.builder`, so screens never add it.
class GlassBackground extends StatelessWidget {
  const GlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            RosColors.auroraTop,
            RosColors.auroraMid,
            RosColors.auroraBottom,
          ],
        ),
      ),
      child: Stack(
        children: [
          // ponytail: static blobs, not animated — cheap and stable under
          // scroll. Animate only if the brand asks for it.
          const Positioned(
            top: -120,
            left: -80,
            child: _Blob(color: RosColors.auroraBlobA, size: 320),
          ),
          const Positioned(
            top: 180,
            right: -110,
            child: _Blob(color: RosColors.auroraBlobB, size: 280),
          ),
          const Positioned(
            bottom: -140,
            left: -60,
            child: _Blob(color: RosColors.auroraBlobC, size: 340),
          ),
          child,
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// Frosted panel: blurs whatever is behind it, hairline highlight, soft shadow.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = RosGlass.radius,
    this.color = RosColors.glass,
    this.blur = RosGlass.blur,
    this.onTap,
    this.shadow = true,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final double blur;
  final VoidCallback? onTap;
  final bool shadow;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow ? RosGlass.shadow : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: r,
              border: border
                  ? Border.all(color: RosColors.glassBorder, width: 1)
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: r,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edge-to-edge frosted bar (nav bars, sticky footers) — square corners,
/// blur only, no shadow.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.top = false});

  final Widget child;
  final bool top;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RosColors.glassStrong,
            border: Border(
              top: top ? BorderSide.none : RosGlass.border,
              bottom: top ? RosGlass.border : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
