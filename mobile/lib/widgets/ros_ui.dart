import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/ros_theme.dart';
import 'glass.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

String formatInr(num amount) => _inr.format(amount);

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style, this.color});

  final num amount;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.titleMedium;
    return Text(
      formatInr(amount),
      textAlign: TextAlign.right,
      style: (base ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? base?.color,
      ),
    );
  }
}

enum StatusKind { paid, ready, pending, held, cancelled }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.kind});

  final String label;
  final StatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      StatusKind.paid ||
      StatusKind.ready => (RosColors.paid, RosColors.onPrimary),
      StatusKind.pending ||
      StatusKind.held => (RosColors.pendingContainer, RosColors.pending),
      StatusKind.cancelled => (RosColors.errorContainer, RosColors.error),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RosColors.glassBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: fg,
        ),
      ),
    );
  }
}

class RosSurfaceCard extends StatelessWidget {
  const RosSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = RosGlass.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: borderRadius,
      padding: padding,
      onTap: onTap,
      child: child,
    );
  }
}

class RosBottomCta extends StatelessWidget {
  const RosBottomCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassBar(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: FilledButton(
            onPressed: (!enabled || busy) ? null : onPressed,
            child: busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RosColors.onPrimary,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}

class RosNavTile extends StatelessWidget {
  const RosNavTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.showDivider = false,
    this.leadingBg,
    this.leadingFg,
    this.accentRail,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  final Color? leadingBg;
  final Color? leadingFg;
  final Color? accentRail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (accentRail != null)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: accentRail,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  accentRail != null ? 14 : 16,
                  16,
                  16,
                  16,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: leadingBg ?? RosColors.surfaceDim,
                      child: Icon(
                        icon,
                        color: leadingFg ?? RosColors.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: RosColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: RosColors.outlineVariant),
      ],
    );
  }
}

class RosLoading extends StatelessWidget {
  const RosLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class RosEmpty extends StatelessWidget {
  const RosEmpty({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class RosErrorText extends StatelessWidget {
  const RosErrorText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: RosColors.error, fontSize: 14),
    );
  }
}
