import 'package:flutter/material.dart';
import '../../core/design_system/design_system.dart';
import '../../core/theme/soama_colors.dart';
import 'glass_surface.dart';
import 'soama_buttons.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onActionPressed,
    this.padding = const EdgeInsets.all(32.0),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GlassSurface(
              borderRadius: BorderRadius.circular(9999),
              blurIntensity: GlassBlurIntensity.subtle,
              padding: const EdgeInsets.all(22.0),
              child: Icon(
                icon,
                size: 38,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: SoamaSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SoamaTypography.headlineSmall.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SoamaSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: SoamaTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: SoamaSpacing.xl),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onActionPressed,
                size: ButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
