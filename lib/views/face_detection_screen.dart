import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../widgets/face_painter.dart';
import '../utils/brightness_estimator.dart';
import '../widgets/ui_overlays.dart';

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
  String _emotionLabel = 'Detecting Emotion...';
  int _frameSkip = 0;

  final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(enableContours: true, enableClassification: true),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.cameras[_cameraIndex]);
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller.initialize();

    try {
      await _controller.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('Exposure mode not supported: $e');
    }

    await _controller.startImageStream(_processCameraImage);

    if (mounted) setState(() {});
  }

  void _switchCamera() {
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    _controller.stopImageStream();
    _initializeCamera(widget.cameras[_cameraIndex]);
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _frameSkip++ % 2 != 0) return;
    _isDetecting = true;

    try {
      final brightness = estimateBrightness(image);
      double exposureCompensation = 0.0;

      if (brightness < 40) {
        setState(() {
          _lightingWarning = 'Very Dark - Adjusting Exposure';
          _faces = [];
          _emotionLabel = 'Too dark to detect';
        });
        try {
          await _controller.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        return;
      } else if (brightness > 240) {
        setState(() {
          _lightingWarning = 'Too Bright - Adjusting Exposure';
          _faces = [];
          _emotionLabel = 'Too bright to detect';
        });
        try {
          await _controller.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        return;
      } else if (brightness < 80 || brightness > 200) {
        setState(() {
          _lightingWarning = 'Low Visibility ⚠️';
        });
        try {
          exposureCompensation = brightness < 100 ? 0.5 : -0.5;
          await _controller.setExposureOffset(exposureCompensation);
        } catch (_) {}
      } else {
        setState(() => _lightingWarning = '');
      }

      if (brightness >= 40 && brightness <= 240) {
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
            InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

        final metadata = InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes.first.bytesPerRow,
        );

        final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
        final faces = await faceDetector.processImage(inputImage);

        if (mounted) {
          String emotion = 'No Face Detected';
          if (faces.isNotEmpty) {
            final face = faces.first;
            final smile = face.smilingProbability ?? -1;
            final leftEye = face.leftEyeOpenProbability ?? -1;
            final rightEye = face.rightEyeOpenProbability ?? -1;

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
          }
          setState(() {
            _faces = faces;
            _emotionLabel = emotion;
          });
        }
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
      body: Stack(
        children: [
        Column(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  CameraPreview(_controller),
                  CustomPaint(painter: FacePainter(faces: _faces)),
                  Positioned(
                    top: 40,
                    left: 20,
                    child: buildLabel('Faces Detected: ${_faces.length}', color: Colors.black),
                  ),
                  if (_lightingWarning.isNotEmpty)
                    Positioned(
                      top: 90,
                      left: 20,
                      child: buildLabel(_lightingWarning, color: Colors.redAccent),
                    ),
                ],
              ),
            ),
            // 👇 New section using Spacer
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Text(
                    _emotionLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(flex: 10), // Pushes text upward
                ],
              ),
            ),
          ],
        ),

          Positioned(
            bottom: 350,
            right: 20,
            child: FloatingActionButton(
              onPressed: _switchCamera,
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
