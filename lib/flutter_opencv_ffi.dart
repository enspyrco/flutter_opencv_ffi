/// Dart FFI bindings to OpenCV for image processing.
library;

import 'package:ffi/ffi.dart';

import 'src/flutter_opencv_ffi_bindings_generated.dart' as bindings;

export 'src/opencv_exception.dart';
export 'src/opencv_image.dart';

/// Returns the OpenCV version string (e.g. "4.13.0").
String opencvVersion() {
  final ptr = bindings.opencv_version();
  return ptr.cast<Utf8>().toDartString();
}
