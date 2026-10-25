import 'dart:typed_data';

/// Encapsulates binary file data and metadata for storage uploads.
class StorageFilePayload {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int fileSize;

  const StorageFilePayload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });

  /// Approximate readable file size in KB or MB.
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
