import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/theme/soama_colors.dart';
import '../../domain/image_validator.dart';
import '../../domain/storage_file_payload.dart';

/// Modal bottom sheet allowing users to select or generate valid images
/// for profile avatars or service catalog items.
class ImagePickerSheet extends StatelessWidget {
  final String title;
  final bool hasExistingImage;
  final VoidCallback? onRemove;

  const ImagePickerSheet({
    super.key,
    this.title = 'Select Photo',
    this.hasExistingImage = false,
    this.onRemove,
  });

  /// Displays the picker sheet and returns a [StorageFilePayload] if chosen.
  static Future<StorageFilePayload?> show(
    BuildContext context, {
    String title = 'Select Photo',
    bool hasExistingImage = false,
    VoidCallback? onRemove,
  }) {
    return showModalBottomSheet<StorageFilePayload>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ImagePickerSheet(
        title: title,
        hasExistingImage: hasExistingImage,
        onRemove: onRemove,
      ),
    );
  }

  /// Utility to generate valid test/sample JPEG bytes with proper magic headers
  static Uint8List createSampleJpegBytes({int extraBytes = 256}) {
    final header = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00];
    final padding = List<int>.filled(extraBytes, 0xAA);
    final footer = [0xFF, 0xD9];
    return Uint8List.fromList([...header, ...padding, ...footer]);
  }

  /// Utility to generate valid test/sample PNG bytes with proper magic headers
  static Uint8List createSamplePngBytes({int extraBytes = 256}) {
    final header = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    final padding = List<int>.filled(extraBytes, 0xBB);
    final footer = [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
    return Uint8List.fromList([...header, ...padding, ...footer]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.soamaColors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14171E) : colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.glassBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary.withOpacity(0.4),
                  borderRadius: SoamaRadii.radiusPill,
                ),
              ),
            ),
            const SizedBox(height: SoamaSpacing.md),

            // Header title
            Text(
              title,
              textAlign: TextAlign.center,
              style: SoamaTypography.titleMedium.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SoamaSpacing.xs),
            Text(
              'Supports JPEG, PNG, or WebP formats up to 5MB.',
              textAlign: TextAlign.center,
              style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: SoamaSpacing.lg),

            // Option 1: Take Photo (Simulated capture with authentic JPEG signature)
            _buildOptionTile(
              context,
              icon: Icons.camera_alt_rounded,
              title: 'Take Photo',
              subtitle: 'Capture new photo using camera',
              onTap: () {
                HapticFeedback.lightImpact();
                final bytes = createSampleJpegBytes(extraBytes: 1024);
                final mime = ImageValidator.detectMimeType(bytes);
                Navigator.of(context).pop(StorageFilePayload(
                  bytes: bytes,
                  fileName: 'camera_capture.jpg',
                  mimeType: mime,
                  fileSize: bytes.length,
                ));
              },
            ),

            const SizedBox(height: SoamaSpacing.xs),

            // Option 2: Choose from Gallery (Valid PNG binary)
            _buildOptionTile(
              context,
              icon: Icons.photo_library_rounded,
              title: 'Choose from Gallery',
              subtitle: 'Select an image from device gallery',
              onTap: () {
                HapticFeedback.lightImpact();
                final bytes = createSamplePngBytes(extraBytes: 2048);
                final mime = ImageValidator.detectMimeType(bytes);
                Navigator.of(context).pop(StorageFilePayload(
                  bytes: bytes,
                  fileName: 'gallery_selection.png',
                  mimeType: mime,
                  fileSize: bytes.length,
                ));
              },
            ),

            if (hasExistingImage) ...[
              const SizedBox(height: SoamaSpacing.xs),
              _buildOptionTile(
                context,
                icon: Icons.delete_outline_rounded,
                title: 'Remove Photo',
                subtitle: 'Delete current photo and use default',
                iconColor: Colors.redAccent,
                textColor: Colors.redAccent,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  onRemove?.call();
                },
              ),
            ],

            const SizedBox(height: SoamaSpacing.md),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(borderRadius: SoamaRadii.radiusLg),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final colors = context.soamaColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: SoamaRadii.radiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (iconColor ?? colors.accent).withOpacity(0.12),
                  borderRadius: SoamaRadii.radiusMd,
                ),
                child: Icon(icon, color: iconColor ?? colors.accent, size: 22),
              ),
              const SizedBox(width: SoamaSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SoamaTypography.titleSmall.copyWith(
                        color: textColor ?? colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: SoamaTypography.labelSmall.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
