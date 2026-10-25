import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/glass_surface.dart';

class FeaturedServiceBanner extends StatelessWidget {
  final VoidCallback? onTap;

  const FeaturedServiceBanner({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GlassCard(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: SoamaRadii.radiusXxl,
        padding: EdgeInsets.zero,
        enableBlur: false, // Performance optimization
        child: ClipRRect(
          borderRadius: SoamaRadii.radiusXxl,
          child: Stack(
            children: [
              // Memory-optimized photography with ResizeImage
              Positioned.fill(
                child: Image(
                  image: const ResizeImage(
                    NetworkImage(
                      'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=900&q=80',
                    ),
                    width: 720,
                    height: 360,
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? const Color(0xFF1E2129) : const Color(0xFFE8E5DD),
                  ),
                ),
              ),

              // Restrained, tasteful gradient overlay for depth & readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withOpacity(0.72),
                        Colors.black.withOpacity(0.40),
                        Colors.black.withOpacity(0.80),
                      ],
                    ),
                  ),
                ),
              ),

              // Content overlay
              Container(
                constraints: const BoxConstraints(minHeight: 180),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subdued badge
                    GlassSurface(
                      borderRadius: SoamaRadii.radiusPill,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      backgroundColor: Colors.white.withOpacity(0.16),
                      borderColor: Colors.white.withOpacity(0.24),
                      blurIntensity: GlassBlurIntensity.subtle,
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
                          const Flexible(
                            child: Text(
                              'Verified Artisan Guarantee',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Text and CTA
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Your next job, handled.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Find the right professional, without the stress.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12.0,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 6.0,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: SoamaRadii.radiusPill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Explore guarantee',
                                    style: TextStyle(
                                      color: colors.onAccent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: colors.onAccent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
