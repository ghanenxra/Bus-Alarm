import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';

enum BadgeVariant {
  online,
  waking,
  offline,
  active,
  idle,
  expired,
  error,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;

  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case BadgeVariant.online:
      case BadgeVariant.active:
        bg = AppTokens.success.withValues(alpha: 0.15);
        fg = AppTokens.success;
        border = AppTokens.success.withValues(alpha: 0.4);
        break;
      case BadgeVariant.waking:
      case BadgeVariant.idle:
        bg = AppTokens.warning.withValues(alpha: 0.15);
        fg = AppTokens.warning;
        border = AppTokens.warning.withValues(alpha: 0.4);
        break;
      case BadgeVariant.offline:
      case BadgeVariant.expired:
      case BadgeVariant.error:
        bg = AppTokens.error.withValues(alpha: 0.15);
        fg = AppTokens.error;
        border = AppTokens.error.withValues(alpha: 0.4);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 11.0,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

