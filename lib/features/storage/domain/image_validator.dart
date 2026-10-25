import 'dart:math';
import 'dart:typed_data';

/// Exception thrown when client-side image validation fails.
class ImageValidationException implements Exception {
  final String message;
  const ImageValidationException(this.message);

  @override
  String toString() => message;
}

/// Robust image validation enforcing file size, MIME signatures (magic bytes),
/// and collision-resistant storage path naming.
class ImageValidator {
  ImageValidator._();

  /// Default file size limit for avatars: 5 MB
  static const int maxAvatarSizeBytes = 5 * 1024 * 1024;

  /// Default file size limit for portfolio images: 10 MB
  static const int maxPortfolioSizeBytes = 10 * 1024 * 1024;

  /// Supported MIME types for images
  static const Set<String> supportedMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  /// Supported file extensions
  static const Set<String> supportedExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  /// Inspects binary data headers (magic bytes) to accurately verify image format
  /// rather than blindly trusting filename extensions.
  static String detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) {
      throw const ImageValidationException('File is too small to be a valid image.');
    }

    // JPEG: FF D8 FF
    if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG: 89 50 4E 47 (0x89 'PNG')
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // PDF: 25 50 44 46 (%PDF)
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'application/pdf';
    }

    // WEBP: 'RIFF' (0..3) ... 'WEBP' (8..11)
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }

    throw const ImageValidationException(
      'Unsupported image format. Please select a JPEG, PNG, or WebP photo.',
    );
  }

  /// Maps detected MIME type to preferred file extension.
  static String extensionFromMime(String mimeType) {
    switch (mimeType) {
      case 'application/pdf':
        return 'pdf';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/jpeg':
      default:
        return 'jpg';
    }
  }

  /// Validates both images and documents (PDFs) for attachments and verification.
  static String validateAttachment({
    required Uint8List bytes,
    required String fileName,
    int maxSizeBytes = 10 * 1024 * 1024,
  }) {
    if (bytes.isEmpty) {
      throw const ImageValidationException('Selected file is empty.');
    }

    if (bytes.length > maxSizeBytes) {
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      final currentMb = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      throw ImageValidationException(
        'File size (${currentMb}MB) exceeds the maximum allowed limit of ${maxMb}MB.',
      );
    }

    return detectMimeType(bytes);
  }

  /// Validates both size and binary signature of an image file.
  /// Throws [ImageValidationException] if invalid.
  static String validateImage({
    required Uint8List bytes,
    required String fileName,
    int maxSizeBytes = maxAvatarSizeBytes,
  }) {
    if (bytes.isEmpty) {
      throw const ImageValidationException('Selected file is empty.');
    }

    if (bytes.length > maxSizeBytes) {
      final maxMb = (maxSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      final currentMb = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      throw ImageValidationException(
        'File size (${currentMb}MB) exceeds the maximum allowed limit of ${maxMb}MB.',
      );
    }

    final mime = detectMimeType(bytes);
    if (!supportedMimeTypes.contains(mime)) {
      throw ImageValidationException('MIME type $mime is not supported.');
    }

    return mime;
  }

  /// Generates a collision-resistant, tenant-isolated object path.
  /// Format: `{userId}/{prefix}_{timestamp}_{randomHex}.{ext}`
  static String generateObjectPath({
    required String userId,
    required String prefix,
    required String mimeType,
  }) {
    final cleanUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomHex = _randomString(8);
    final ext = extensionFromMime(mimeType);

    return '$cleanUserId/${prefix}_${timestamp}_$randomHex.$ext';
  }

  static String _randomString(int length) {
    const chars = 'abcdef0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
