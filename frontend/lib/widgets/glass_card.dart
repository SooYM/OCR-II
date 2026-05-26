import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glassmorphism-style section card container.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.backgroundColor,
    this.showBorder = true,
  });

  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    
    return Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface.withOpacity(isDark ? 0.8 : 0.95),
        borderRadius: radius,
        border: showBorder ? Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        ) : null,
        boxShadow: AppTheme.cardShadow(context),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
