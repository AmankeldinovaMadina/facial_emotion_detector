import 'package:camera/camera.dart';

double estimateBrightness(CameraImage image) {
  final plane = image.planes.first;
  final bytes = plane.bytes;
  final total = bytes.fold<int>(0, (sum, byte) => sum + byte);
  return total / bytes.length;
}
