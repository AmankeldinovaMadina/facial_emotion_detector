import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

class FaceDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const FaceDetectionScreen({super.key, required this.cameras});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> {
  late CameraController _controller;
  int _cameraIndex = 0;
  List<Face> _faces = [];
  bool _isDetecting = false;
  String _lightingWarning = '';

  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(enableContours: true, enableClassification: true),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.cameras[_cameraIndex]);
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(cameraDescription, ResolutionPreset.medium);
    await _controller.initialize();
    await _controller.startImageStream(_processCameraImage);
    if (mounted) setState(() {});
  }

  void _switchCamera() {
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    _controller.stopImageStream();
    _initializeCamera(widget.cameras[_cameraIndex]);
  }

  double _estimateBrightness(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final total = bytes.fold<int>(0, (sum, byte) => sum + byte);
    return total / bytes.length;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting) return;
    _isDetecting = true;

    try {
      final brightness = _estimateBrightness(image);

      if (brightness < 80) {
        setState(() {
          _lightingWarning = 'Too Dark 🔦';
          _faces = [];
        });
        return;
      } else if (brightness > 200) {
        setState(() {
          _lightingWarning = 'Too Bright ☀️';
          _faces = [];
        });
        return;
      } else {
        setState(() => _lightingWarning = '');
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

      final InputImageRotation imageRotation =
          InputImageRotationValue.fromRawValue(widget.cameras[_cameraIndex].sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
              InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      final faces = await faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() => _faces = faces);
      }
    } catch (e) {
      debugPrint("Face detection error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller.value.isInitialized
          ? Stack(
              children: [
                CameraPreview(_controller),
                CustomPaint(painter: FacePainter(faces: _faces)),

                // Face count overlay
                Positioned(
                  top: 40,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Faces Detected: ${_faces.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

                // Brightness warning overlay
                if (_lightingWarning.isNotEmpty)
                  Positioned(
                    top: 90,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _lightingWarning,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),

                // Switch camera button
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: _switchCamera,
                    backgroundColor: Colors.blueAccent,
                    child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;

  FacePainter({required this.faces});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var face in faces) {
      canvas.drawRect(face.boundingBox, paint);

      final smile = face.smilingProbability ?? -1;
      final leftEye = face.leftEyeOpenProbability ?? -1;
      final rightEye = face.rightEyeOpenProbability ?? -1;

      String emotion = "Neutral";

      if (smile > 0.8 && leftEye > 0.8 && rightEye > 0.8) {
        emotion = "Surprised 😮";
      } else if (leftEye < 0.2 && rightEye < 0.2) {
        emotion = "Sleepy 😴";
      } else if (smile > 0.8) {
        emotion = "Happy 😊";
      } else if (smile > 0.5) {
        emotion = "Slight Smile 🙂";
      } else {
        emotion = "Serious 😐";
      }

      final textSpan = TextSpan(
        text: emotion,
        style: const TextStyle(color: Colors.yellow, fontSize: 16),
      );
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(face.boundingBox.left, face.boundingBox.top - 20),
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
