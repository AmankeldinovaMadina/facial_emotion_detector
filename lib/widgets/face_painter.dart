import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

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
      textPainter.paint(canvas, Offset(face.boundingBox.left, face.boundingBox.top - 20));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
