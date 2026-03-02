import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// OpenCV version to download for iOS/Android.
const _opencvVersion = '4.13.0';

/// Download URLs for pre-built OpenCV SDKs.
const _iosUrl =
    'https://github.com/opencv/opencv/releases/download/$_opencvVersion/'
    'opencv-$_opencvVersion-ios-framework.zip';
const _androidUrl =
    'https://github.com/opencv/opencv/releases/download/$_opencvVersion/'
    'opencv-$_opencvVersion-android-sdk.zip';

/// Expected file sizes for integrity verification (from GitHub release assets).
/// Update these when changing [_opencvVersion].
const _iosExpectedSize = 93058287;
const _androidExpectedSize = 318235406;

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final targetOS = input.config.code.targetOS;
    final log = Logger('')
      ..level = Level.ALL
      ..onRecord.listen((record) => print(record.message));

    final opencvFlags = await _opencvFlags(input, log);

    final cbuilder = CBuilder.library(
      name: input.packageName,
      assetName: '${input.packageName}.dart',
      sources: ['src/opencv_wrapper.cpp'],
      language: Language.cpp,
      std: 'c++17',
      flags: opencvFlags,
      // On iOS, we need to link system frameworks. The `frameworks` param
      // only works for Objective-C in CBuilder, so we pass them via flags.
      // On macOS and Android, system frameworks aren't needed this way.
      linkModePreference: targetOS == OS.iOS
          ? LinkModePreference.static
          : LinkModePreference.dynamic,
    );

    await cbuilder.run(
      input: input,
      output: output,
      logger: log,
    );
  });
}

/// Returns compiler/linker flags for OpenCV based on target platform.
Future<List<String>> _opencvFlags(BuildInput input, Logger log) async {
  final targetOS = input.config.code.targetOS;

  if (targetOS == OS.macOS) {
    return _macosFlags();
  } else if (targetOS == OS.iOS) {
    return await _iosFlags(input, log);
  } else if (targetOS == OS.android) {
    return await _androidFlags(input, log);
  }

  log.warning('Unsupported target OS: $targetOS — building without OpenCV');
  return [];
}

// ---------------------------------------------------------------------------
// macOS — use Homebrew OpenCV
// ---------------------------------------------------------------------------

List<String> _macosFlags() {
  final prefix = _findBrewOpencv();
  if (prefix == null) {
    throw StateError(
      'OpenCV not found. Install it with: brew install opencv',
    );
  }
  return [
    '-I$prefix/include/opencv4',
    '-L$prefix/lib',
    '-lopencv_core',
    '-lopencv_imgproc',
    '-lopencv_imgcodecs',
  ];
}

String? _findBrewOpencv() {
  final result = Process.runSync('brew', ['--prefix', 'opencv']);
  if (result.exitCode == 0) {
    final prefix = (result.stdout as String).trim();
    if (Directory('$prefix/include/opencv4').existsSync()) return prefix;
  }
  for (final candidate in [
    '/opt/homebrew/opt/opencv',
    '/usr/local/opt/opencv',
  ]) {
    if (Directory('$candidate/include/opencv4').existsSync()) return candidate;
  }
  return null;
}

// ---------------------------------------------------------------------------
// iOS — download pre-built framework, link statically
// ---------------------------------------------------------------------------

Future<List<String>> _iosFlags(BuildInput input, Logger log) async {
  final sdkDir = await _downloadAndExtract(
    input: input,
    url: _iosUrl,
    dirName: 'opencv-ios-$_opencvVersion',
    expectedSize: _iosExpectedSize,
    log: log,
  );

  // The extracted framework lives at opencv2.framework/ inside the zip.
  final frameworkDir = Directory('${sdkDir.path}/opencv2.framework');
  if (!frameworkDir.existsSync()) {
    throw StateError(
      'opencv2.framework not found in ${sdkDir.path}. '
      'Contents: ${sdkDir.listSync().map((e) => e.path).toList()}',
    );
  }

  final headersDir = '${frameworkDir.path}/Headers';
  final libPath = '${frameworkDir.path}/opencv2'; // Static library binary

  return [
    // Include path — headers are at opencv2.framework/Headers/opencv2/
    '-I$headersDir',
    // Link the static library directly
    libPath,
    // System frameworks required by OpenCV on iOS
    '-framework', 'Accelerate',
    '-framework', 'AssetsLibrary',
    '-framework', 'AVFoundation',
    '-framework', 'CoreGraphics',
    '-framework', 'CoreImage',
    '-framework', 'CoreMedia',
    '-framework', 'CoreVideo',
    '-framework', 'Foundation',
    '-framework', 'QuartzCore',
    '-framework', 'UIKit',
    // System libraries
    '-lz', // zlib, needed by image codecs
  ];
}

// ---------------------------------------------------------------------------
// Android — download pre-built SDK, link shared lib per ABI
// ---------------------------------------------------------------------------

Future<List<String>> _androidFlags(BuildInput input, Logger log) async {
  final sdkDir = await _downloadAndExtract(
    input: input,
    url: _androidUrl,
    dirName: 'opencv-android-$_opencvVersion',
    expectedSize: _androidExpectedSize,
    log: log,
  );

  final arch = input.config.code.targetArchitecture;
  final abi = _androidAbi(arch);
  if (abi == null) {
    throw StateError('Unsupported Android architecture: $arch');
  }

  final nativeDir = '${sdkDir.path}/OpenCV-android-sdk/sdk/native';
  final includeDir = '$nativeDir/jni/include';
  final libDir = '$nativeDir/libs/$abi';
  final staticLibDir = '$nativeDir/staticlibs/$abi';
  final thirdPartyDir = '$nativeDir/3rdparty/libs/$abi';

  // Prefer static linking for a self-contained build.
  if (Directory(staticLibDir).existsSync()) {
    return [
      '-I$includeDir',
      '-L$staticLibDir',
      '-L$thirdPartyDir',
      '-lopencv_imgcodecs',
      '-lopencv_imgproc',
      '-lopencv_core',
      // 3rd-party deps needed by imgcodecs
      '-llibjpeg-turbo',
      '-llibpng',
      '-llibtiff',
      '-llibwebp',
      '-lIlmImf',
      '-llibopenjp2',
      '-lcpufeatures',
      '-ltegra_hal',
      '-ltbb',
      '-lz', // system zlib
      '-llog', // Android logging
    ];
  }

  // Fallback to the monolithic shared library.
  return [
    '-I$includeDir',
    '-L$libDir',
    '-lopencv_java4',
  ];
}

/// Maps Dart Architecture to Android ABI string.
String? _androidAbi(Architecture? arch) {
  if (arch == Architecture.arm64) return 'arm64-v8a';
  if (arch == Architecture.arm) return 'armeabi-v7a';
  if (arch == Architecture.x64) return 'x86_64';
  if (arch == Architecture.ia32) return 'x86';
  return null;
}

// ---------------------------------------------------------------------------
// Download + extract helper
// ---------------------------------------------------------------------------

/// Downloads a zip from [url] into the shared output directory and extracts it.
/// Returns the extraction directory. Skips download if already cached.
///
/// If [expectedSize] is provided, the downloaded file's size is verified to
/// catch corruption or tampering.
Future<Directory> _downloadAndExtract({
  required BuildInput input,
  required String url,
  required String dirName,
  int? expectedSize,
  required Logger log,
}) async {
  final cacheDir = Directory.fromUri(
    input.outputDirectoryShared.resolve(dirName),
  );

  if (cacheDir.existsSync()) {
    log.info('Using cached OpenCV SDK at ${cacheDir.path}');
    return cacheDir;
  }

  log.info('Downloading OpenCV SDK from $url ...');
  cacheDir.createSync(recursive: true);

  final zipFile = File('${cacheDir.path}/opencv.zip');

  // Download using curl (available on macOS, Linux, and most CI).
  final downloadResult = Process.runSync('curl', [
    '-L', // Follow redirects
    '-o', zipFile.path,
    '--fail', // Fail on HTTP errors
    '--silent',
    '--show-error',
    url,
  ]);

  if (downloadResult.exitCode != 0) {
    // Clean up on failure so next build retries.
    cacheDir.deleteSync(recursive: true);
    throw StateError(
      'Failed to download OpenCV SDK: ${downloadResult.stderr}',
    );
  }

  // Verify file size to catch corruption or tampering.
  if (expectedSize != null) {
    final actualSize = zipFile.lengthSync();
    if (actualSize != expectedSize) {
      cacheDir.deleteSync(recursive: true);
      throw StateError(
        'OpenCV SDK size mismatch: expected $expectedSize bytes, '
        'got $actualSize bytes. The download may be corrupt or tampered.',
      );
    }
    log.info('Download integrity verified ($actualSize bytes).');
  }

  log.info('Extracting OpenCV SDK...');
  final extractResult = Process.runSync('unzip', [
    '-q', // Quiet
    '-o', // Overwrite
    zipFile.path,
    '-d', cacheDir.path,
  ]);

  if (extractResult.exitCode != 0) {
    cacheDir.deleteSync(recursive: true);
    throw StateError(
      'Failed to extract OpenCV SDK: ${extractResult.stderr}',
    );
  }

  // Remove the zip to save space.
  zipFile.deleteSync();

  log.info('OpenCV SDK ready at ${cacheDir.path}');
  return cacheDir;
}
