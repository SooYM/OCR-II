import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A glowing gradient primary button with optional icon.
class GradientButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isSmall;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isSmall = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: _isHovered ? AppTheme.primaryShadow(context) : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isSmall ? 16 : 24,
                vertical: widget.isSmall ? 10 : 14,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    )
                  else ...[
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: widget.isSmall ? 16 : 20, color: Colors.white),
                      SizedBox(width: widget.isSmall ? 6 : 10),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: widget.isSmall ? 13 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
