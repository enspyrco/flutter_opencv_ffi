import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_opencv_ffi/flutter_opencv_ffi.dart';
import 'package:test/test.dart';

void main() {
  group('opencvVersion', () {
    test('returns a semantic version string', () {
      final version = opencvVersion();
      expect(version, matches(RegExp(r'^\d+\.\d+\.\d+')));
    });
  });

  group('CvImage', () {
    late String fixturePath;

    setUpAll(() {
      fixturePath = '${Directory.current.path}/test/fixtures/test.png';
      expect(File(fixturePath).existsSync(), isTrue,
          reason: 'test fixture test.png must exist');
    });

    test('imread loads an image from disk', () {
      final image = CvImage.imread(fixturePath);
      expect(image.isEmpty, isFalse);
      expect(image.rows, greaterThan(0));
      expect(image.cols, greaterThan(0));
      expect(image.channels, equals(3)); // BGR by default
      image.dispose();
    });

    test('imread throws on missing file', () {
      expect(
        () => CvImage.imread('/nonexistent/path.png'),
        throwsA(isA<OpenCvException>()),
      );
    });

    test('imwrite saves an image to disk', () {
      final image = CvImage.imread(fixturePath);
      final outPath =
          '${Directory.systemTemp.path}/flutter_opencv_ffi_test_out.png';
      image.imwrite(outPath);
      expect(File(outPath).existsSync(), isTrue);
      expect(File(outPath).lengthSync(), greaterThan(0));

      // Clean up.
      File(outPath).deleteSync();
      image.dispose();
    });

    test('clone creates an independent copy', () {
      final original = CvImage.imread(fixturePath);
      final copy = original.clone();
      expect(copy.rows, equals(original.rows));
      expect(copy.cols, equals(original.cols));

      // Disposing one should not affect the other.
      original.dispose();
      expect(copy.isEmpty, isFalse);
      copy.dispose();
    });

    test('cvtColor converts BGR to grayscale', () {
      final image = CvImage.imread(fixturePath);
      final gray = image.cvtColor(ColorConversion.bgrToGray);
      expect(gray.channels, equals(1));
      expect(gray.rows, equals(image.rows));
      expect(gray.cols, equals(image.cols));
      gray.dispose();
      image.dispose();
    });

    test('gaussianBlur applies blur', () {
      final image = CvImage.imread(fixturePath);
      final blurred = image.gaussianBlur(ksize: 5, sigmaX: 1.5);
      expect(blurred.rows, equals(image.rows));
      expect(blurred.cols, equals(image.cols));
      expect(blurred.channels, equals(image.channels));
      blurred.dispose();
      image.dispose();
    });

    test('canny detects edges', () {
      final image = CvImage.imread(fixturePath);
      final gray = image.cvtColor(ColorConversion.bgrToGray);
      final edges = gray.canny(threshold1: 50, threshold2: 150);
      expect(edges.rows, equals(image.rows));
      expect(edges.cols, equals(image.cols));
      expect(edges.channels, equals(1));
      edges.dispose();
      gray.dispose();
      image.dispose();
    });

    test('resize changes dimensions', () {
      final image = CvImage.imread(fixturePath);
      final resized = image.resize(width: 50, height: 40);
      expect(resized.cols, equals(50));
      expect(resized.rows, equals(40));
      resized.dispose();
      image.dispose();
    });

    test('resize with interpolation flag', () {
      final image = CvImage.imread(fixturePath);
      final resized = image.resize(
        width: 200,
        height: 200,
        interpolation: Interpolation.cubic,
      );
      expect(resized.cols, equals(200));
      expect(resized.rows, equals(200));
      resized.dispose();
      image.dispose();
    });

    test('encode/decode PNG roundtrip', () {
      final image = CvImage.imread(fixturePath);
      final encoded = image.imencode('.png');
      expect(encoded, isA<Uint8List>());
      expect(encoded.length, greaterThan(0));

      final decoded = CvImage.imdecode(encoded);
      expect(decoded.rows, equals(image.rows));
      expect(decoded.cols, equals(image.cols));
      decoded.dispose();
      image.dispose();
    });

    test('encode/decode JPEG roundtrip', () {
      final image = CvImage.imread(fixturePath);
      final encoded = image.imencode('.jpg');
      expect(encoded, isA<Uint8List>());
      expect(encoded.length, greaterThan(0));

      final decoded = CvImage.imdecode(encoded);
      expect(decoded.rows, equals(image.rows));
      expect(decoded.cols, equals(image.cols));
      // JPEG is lossy, so pixel values may differ, but dimensions should match.
      decoded.dispose();
      image.dispose();
    });
  });
}
