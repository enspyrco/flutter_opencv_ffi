import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'flutter_opencv_ffi_bindings_generated.dart' as bindings;
import 'opencv_exception.dart';

/// OpenCV color conversion codes (subset of cv::ColorConversionCodes).
enum ColorConversion {
  /// BGR to grayscale.
  bgrToGray(6),

  /// Grayscale to BGR.
  grayToBgr(8),

  /// BGR to RGB.
  bgrToRgb(4),

  /// RGB to BGR.
  rgbToBgr(4),

  /// BGR to RGBA.
  bgrToRgba(2),

  /// RGBA to BGR.
  rgbaToBgr(3);

  const ColorConversion(this.code);

  /// The OpenCV integer code for this conversion.
  final int code;
}

/// OpenCV interpolation flags (subset of cv::InterpolationFlags).
enum Interpolation {
  /// Nearest-neighbor interpolation.
  nearest(0),

  /// Bilinear interpolation.
  linear(1),

  /// Bicubic interpolation.
  cubic(2),

  /// Resampling using pixel area relation.
  area(3),

  /// Lanczos interpolation over 8x8 neighborhood.
  lanczos4(4);

  const Interpolation(this.code);

  /// The OpenCV integer code for this interpolation mode.
  final int code;
}

// NativeFinalizer that calls opencv_mat_destroy to prevent leaks.
final _pointerFinalizer = NativeFinalizer(
  Native.addressOf<NativeFunction<Void Function(Pointer<bindings.CvMat>)>>(
    bindings.opencv_mat_destroy,
  ).cast(),
);

/// A high-level wrapper around an OpenCV `cv::Mat` image.
///
/// Instances hold native memory via an opaque [Pointer]. Call [dispose] when
/// done, or rely on the [NativeFinalizer] for automatic cleanup.
class CvImage implements Finalizable {
  CvImage._(this._ptr) {
    if (_ptr == nullptr) {
      throw const OpenCvException('failed to create CvImage (null pointer)');
    }
    _pointerFinalizer.attach(this, _ptr.cast(), detach: _pointerRef);
  }

  final Pointer<bindings.CvMat> _ptr;

  // Token for detaching the NativeFinalizer on manual [dispose].
  final Object _pointerRef = Object();

  bool _disposed = false;

  /// Throws [StateError] if this image has been disposed.
  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('Cannot use a disposed CvImage');
    }
  }

  // ---------------------------------------------------------------------------
  // Constructors / factories
  // ---------------------------------------------------------------------------

  /// Reads an image from [path]. Throws [OpenCvException] on failure.
  ///
  /// [flags] defaults to `cv::IMREAD_COLOR` (1).
  factory CvImage.imread(String path, {int flags = 1}) {
    final pathPtr = path.toNativeUtf8(allocator: calloc).cast<Char>();
    final ptr = bindings.opencv_imread(pathPtr, flags);
    calloc.free(pathPtr);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'imread failed: $path');
    }
    return CvImage._(ptr);
  }

  /// Decodes an image from an in-memory buffer.
  ///
  /// [flags] defaults to `cv::IMREAD_COLOR` (1).
  factory CvImage.imdecode(Uint8List data, {int flags = 1}) {
    final bufPtr = calloc<Uint8>(data.length);
    bufPtr.asTypedList(data.length).setAll(0, data);
    final ptr = bindings.opencv_imdecode(bufPtr, data.length, flags);
    calloc.free(bufPtr);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'imdecode failed');
    }
    return CvImage._(ptr);
  }

  // ---------------------------------------------------------------------------
  // Properties
  // ---------------------------------------------------------------------------

  /// Number of rows (height) in the image.
  int get rows {
    _ensureNotDisposed();
    return bindings.opencv_mat_rows(_ptr);
  }

  /// Number of columns (width) in the image.
  int get cols {
    _ensureNotDisposed();
    return bindings.opencv_mat_cols(_ptr);
  }

  /// OpenCV type code (e.g. CV_8UC3).
  int get type {
    _ensureNotDisposed();
    return bindings.opencv_mat_type(_ptr);
  }

  /// Number of channels (e.g. 3 for BGR, 1 for grayscale).
  int get channels {
    _ensureNotDisposed();
    return bindings.opencv_mat_channels(_ptr);
  }

  /// Whether the underlying Mat has no data.
  bool get isEmpty {
    _ensureNotDisposed();
    return bindings.opencv_mat_empty(_ptr) != 0;
  }

  // ---------------------------------------------------------------------------
  // Operations
  // ---------------------------------------------------------------------------

  /// Creates a deep copy of this image.
  CvImage clone() {
    _ensureNotDisposed();
    final ptr = bindings.opencv_mat_clone(_ptr);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'clone failed');
    }
    return CvImage._(ptr);
  }

  /// Writes this image to [path]. Throws [OpenCvException] on failure.
  void imwrite(String path) {
    _ensureNotDisposed();
    final pathPtr = path.toNativeUtf8(allocator: calloc).cast<Char>();
    final result = bindings.opencv_imwrite(pathPtr, _ptr);
    calloc.free(pathPtr);
    if (result == 0) {
      throw OpenCvException(_lastError() ?? 'imwrite failed: $path');
    }
  }

  /// Encodes this image to the format specified by [ext] (e.g. `.png`, `.jpg`).
  Uint8List imencode(String ext) {
    _ensureNotDisposed();
    final extPtr = ext.toNativeUtf8(allocator: calloc).cast<Char>();
    final lenPtr = calloc<Int>();
    final bufPtr = bindings.opencv_imencode(extPtr, _ptr, lenPtr);
    calloc.free(extPtr);
    if (bufPtr == nullptr) {
      calloc.free(lenPtr);
      throw OpenCvException(_lastError() ?? 'imencode failed');
    }
    final len = lenPtr.value;
    calloc.free(lenPtr);

    // Copy to Dart-managed memory, then free the native buffer.
    final result = Uint8List.fromList(bufPtr.asTypedList(len));
    bindings.opencv_free_buffer(bufPtr);
    return result;
  }

  /// Converts the color space of this image. Returns a new [CvImage].
  CvImage cvtColor(ColorConversion conversion) {
    _ensureNotDisposed();
    final ptr = bindings.opencv_cvt_color(_ptr, conversion.code);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'cvtColor failed');
    }
    return CvImage._(ptr);
  }

  /// Applies Gaussian blur. [ksize] must be odd and positive. Returns a
  /// new [CvImage].
  CvImage gaussianBlur({
    required int ksize,
    double sigmaX = 0,
    double sigmaY = 0,
  }) {
    _ensureNotDisposed();
    final ptr = bindings.opencv_gaussian_blur(_ptr, ksize, sigmaX, sigmaY);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'gaussianBlur failed');
    }
    return CvImage._(ptr);
  }

  /// Applies Canny edge detection. Returns a new [CvImage].
  CvImage canny({
    required double threshold1,
    required double threshold2,
  }) {
    _ensureNotDisposed();
    final ptr = bindings.opencv_canny(_ptr, threshold1, threshold2);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'canny failed');
    }
    return CvImage._(ptr);
  }

  /// Resizes this image. Returns a new [CvImage].
  CvImage resize({
    required int width,
    required int height,
    Interpolation interpolation = Interpolation.linear,
  }) {
    _ensureNotDisposed();
    final ptr = bindings.opencv_resize(_ptr, width, height, interpolation.code);
    if (ptr == nullptr) {
      throw OpenCvException(_lastError() ?? 'resize failed');
    }
    return CvImage._(ptr);
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases the underlying native memory. Safe to call multiple times.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _pointerFinalizer.detach(_pointerRef);
    bindings.opencv_mat_destroy(_ptr);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String? _lastError() {
    final ptr = bindings.opencv_get_last_error();
    if (ptr == nullptr) return null;
    return ptr.cast<Utf8>().toDartString();
  }
}
