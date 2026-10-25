import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';

class HeroHeading extends StatelessWidget {
  const HeroHeading({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Who do you need\ntoday?',
            style: SoamaTypography.displayLarge.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 32.0,
              height: 1.14,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: SoamaSpacing.xs),
          Text(
            'Find trusted professionals for life\'s everyday jobs.',
            style: SoamaTypography.bodyLarge.copyWith(
              color: colors.textSecondary,
              fontSize: 15.0,
              height: 1.35,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }
}
