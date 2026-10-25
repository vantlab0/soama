import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/soama_button.dart';

class HeroBanner extends StatelessWidget {
  final VoidCallback onExploreTap;

  const HeroBanner({
    super.key,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: SoamaRadii.radiusXxl,
        child: Stack(
          children: [
            // Photographic Background
            Positioned.fill(
              child: Image.network(
                'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE8E5DD),
                ),
              ),
            ),

            // Layered Gradient Overlay for text contrast & luxury depth
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.78),
                    ],
                  ),
                ),
              ),
            ),

            // Glass Content Container
            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subtle top badge
                  GlassContainer(
                    borderRadius: SoamaRadii.radiusPill,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    backgroundColor: Colors.white.withOpacity(0.15),
                    borderColor: Colors.white.withOpacity(0.25),
                    blurSigma: SoamaGlass.blurSubtle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Verified Nigerian Artisans',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: SoamaSpacing.md),

                  // Headline
                  const Text(
                    'Precision service for your home & office.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.0,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    'From certified generator technicians to luxury deep cleaning. Transparent pricing with escrow guarantee.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13.0,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: SoamaSpacing.lg),

                  // Call to Action
                  Row(
                    children: [
                      SoamaButton(
                        label: 'Discover Pros',
                        icon: Icons.explore_rounded,
                        size: SoamaButtonSize.small,
                        onPressed: onExploreTap,
                      ),
                      const SizedBox(width: SoamaSpacing.sm),
                      SoamaButton.glass(
                        label: 'How it Works',
                        size: SoamaButtonSize.small,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
