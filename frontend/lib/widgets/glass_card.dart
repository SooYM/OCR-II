import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glassmorphism-style section card container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.8 : 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: Theme.of(context).dividerTheme.color?.withOpacity(0.5) ?? AppTheme.surfaceBorder.withOpacity(0.5),
        ),
        boxShadow: isDark ? AppTheme.cardShadow : AppTheme.cardShadowLight,
      ),
      child: child,
    );
  }
}
