import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_opencv_ffi/flutter_opencv_ffi.dart';

void main() {
  runApp(const OpenCvExampleApp());
}

class OpenCvExampleApp extends StatelessWidget {
  const OpenCvExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenCV FFI Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _version = '';
  Uint8List? _assetBytes;
  Uint8List? _originalBytes;
  Uint8List? _processedBytes;
  String _status = 'Loading sample image...';

  @override
  void initState() {
    super.initState();
    _version = opencvVersion();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    final data = await rootBundle.load('assets/sample.png');
    setState(() {
      _assetBytes = data.buffer.asUint8List();
      _originalBytes = _assetBytes;
      _status = 'Tap a button to process the image.';
    });
  }

  /// Decodes the asset into a [CvImage] for processing.
  CvImage _loadSourceImage() {
    if (_assetBytes == null) {
      throw const OpenCvException('Asset not loaded yet');
    }
    return CvImage.imdecode(_assetBytes!);
  }

  void _doGrayscale() {
    try {
      final src = _loadSourceImage();
      _originalBytes = _assetBytes;
      final gray = src.cvtColor(ColorConversion.bgrToGray);
      _processedBytes = gray.imencode('.png');
      setState(() => _status = 'Grayscale: ${gray.cols}x${gray.rows}, '
          '${gray.channels} channel(s)');
      gray.dispose();
      src.dispose();
    } on OpenCvException catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _doBlur() {
    try {
      final src = _loadSourceImage();
      _originalBytes = _assetBytes;
      final blurred = src.gaussianBlur(ksize: 15, sigmaX: 5);
      _processedBytes = blurred.imencode('.png');
      setState(() => _status = 'Gaussian blur: ksize=15, sigma=5');
      blurred.dispose();
      src.dispose();
    } on OpenCvException catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _doCanny() {
    try {
      final src = _loadSourceImage();
      _originalBytes = _assetBytes;
      final gray = src.cvtColor(ColorConversion.bgrToGray);
      final edges = gray.canny(threshold1: 50, threshold2: 150);
      _processedBytes = edges.imencode('.png');
      setState(() => _status = 'Canny edges: thresh=[50, 150]');
      edges.dispose();
      gray.dispose();
      src.dispose();
    } on OpenCvException catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  void _doResize() {
    try {
      final src = _loadSourceImage();
      _originalBytes = _assetBytes;
      final resized = src.resize(
        width: 32,
        height: 32,
        interpolation: Interpolation.cubic,
      );
      _processedBytes = resized.imencode('.png');
      setState(() => _status = 'Resized: ${resized.cols}x${resized.rows}');
      resized.dispose();
      src.dispose();
    } on OpenCvException catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _assetBytes != null;

    return Scaffold(
      appBar: AppBar(title: Text('OpenCV $_version')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (_originalBytes != null || _processedBytes != null)
              Expanded(
                child: Row(
                  children: [
                    if (_originalBytes != null)
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Original'),
                            Expanded(
                              child: Image.memory(
                                _originalBytes!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (_processedBytes != null)
                      Expanded(
                        child: Column(
                          children: [
                            const Text('Processed'),
                            Expanded(
                              child: Image.memory(
                                _processedBytes!,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const Spacer(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: loaded ? _doGrayscale : null,
                  child: const Text('Grayscale'),
                ),
                ElevatedButton(
                  onPressed: loaded ? _doBlur : null,
                  child: const Text('Blur'),
                ),
                ElevatedButton(
                  onPressed: loaded ? _doCanny : null,
                  child: const Text('Canny'),
                ),
                ElevatedButton(
                  onPressed: loaded ? _doResize : null,
                  child: const Text('Resize'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
