# flutter_opencv_ffi

Dart FFI bindings to OpenCV for image processing. Provides a high-level `CvImage`
class for common operations: load/save, color conversion, blur, edge detection,
and resize.

Uses Dart [build hooks](https://dart.dev/tools/hooks) to compile a thin C++
wrapper at build time — no manual native setup required.

## Platform Support

| Platform | Status | OpenCV Source |
|----------|--------|---------------|
| macOS    | Supported | Homebrew (`brew install opencv`) |
| iOS      | Supported | Auto-downloaded pre-built framework |
| Android  | Supported | Auto-downloaded pre-built SDK |
| Windows  | Not yet | — |
| Linux    | Not yet | — |

## Requirements

- **Dart SDK** >= 3.11.0
- **macOS**: OpenCV installed via Homebrew (`brew install opencv`)
- **iOS / Android**: No extra setup — the build hook downloads pre-built OpenCV
  SDKs automatically.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_opencv_ffi:
    git:
      url: https://github.com/enspyrco/flutter_opencv_ffi.git
```

## Usage

```dart
import 'package:flutter_opencv_ffi/flutter_opencv_ffi.dart';

// Check OpenCV version.
print(opencvVersion()); // e.g. "4.13.0"

// Load an image.
final image = CvImage.imread('photo.jpg');

// Convert to grayscale.
final gray = image.cvtColor(ColorConversion.bgrToGray);

// Apply Gaussian blur.
final blurred = gray.gaussianBlur(ksize: 5, sigmaX: 1.5);

// Detect edges.
final edges = blurred.canny(threshold1: 50, threshold2: 150);

// Resize.
final thumbnail = image.resize(width: 100, height: 100);

// Encode to PNG bytes.
final pngBytes = edges.imencode('.png');

// Save to disk.
edges.imwrite('edges.png');

// Clean up native memory.
edges.dispose();
blurred.dispose();
gray.dispose();
thumbnail.dispose();
image.dispose();
```

### In-memory round-trip

```dart
import 'dart:typed_data';

// Decode from bytes (e.g. from network or assets).
final Uint8List jpegData = fetchImageBytes();
final image = CvImage.imdecode(jpegData);

// Process and re-encode.
final processed = image.gaussianBlur(ksize: 3, sigmaX: 0);
final outputBytes = processed.imencode('.jpg');

processed.dispose();
image.dispose();
```

## API Reference

### Top-level

| Function | Description |
|----------|-------------|
| `opencvVersion()` | Returns the OpenCV version string |

### CvImage

| Constructor / Factory | Description |
|-----------------------|-------------|
| `CvImage.imread(path, {flags})` | Load image from file |
| `CvImage.imdecode(data, {flags})` | Decode image from byte buffer |

| Property | Description |
|----------|-------------|
| `rows` | Image height |
| `cols` | Image width |
| `channels` | Number of channels (e.g. 3 for BGR) |
| `type` | OpenCV Mat type code |
| `isEmpty` | Whether the Mat has no data |

| Method | Description |
|--------|-------------|
| `clone()` | Deep copy |
| `imwrite(path)` | Save to file |
| `imencode(ext)` | Encode to byte buffer |
| `cvtColor(conversion)` | Color space conversion |
| `gaussianBlur(ksize:, sigmaX:, sigmaY:)` | Gaussian blur |
| `canny(threshold1:, threshold2:)` | Canny edge detection |
| `resize(width:, height:, interpolation:)` | Resize image |
| `dispose()` | Release native memory |

### Enums

- **`ColorConversion`** — `bgrToGray`, `grayToBgr`, `bgrToRgb`, `rgbToBgr`,
  `bgrToRgba`, `rgbaToBgr`
- **`Interpolation`** — `nearest`, `linear`, `cubic`, `area`, `lanczos4`

## Architecture

```
Dart (CvImage)  -->  @Native bindings (ffigen)  -->  C wrapper (extern "C")  -->  OpenCV C++
```

The C wrapper (`src/opencv_wrapper.h` / `.cpp`) provides a flat C API using
opaque `CvMat*` handles. `ffigen` generates `@Native` annotated Dart bindings.
The build hook (`hook/build.dart`) compiles the C++ wrapper and links it against
OpenCV at build time.

## Development

```bash
# Install OpenCV (macOS)
brew install opencv

# Get dependencies
dart pub get

# Regenerate FFI bindings after modifying src/opencv_wrapper.h
dart run ffigen --config ffigen.yaml

# Run tests
dart test

# Run the example app
cd example && flutter run
```

## License

See [LICENSE](LICENSE) for details.
