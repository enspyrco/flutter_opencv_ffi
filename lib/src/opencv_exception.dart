/// Exception thrown when an OpenCV operation fails.
class OpenCvException implements Exception {
  /// Creates an [OpenCvException] with the given [message].
  const OpenCvException(this.message);

  /// The error message from OpenCV.
  final String message;

  @override
  String toString() => 'OpenCvException: $message';
}
