// import 'package:flutter/services.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:camera/camera.dart';

// class TFLiteService {
//   late Interpreter _interpreter;
//   late List<String> _labels;

//   Future<void> loadModel() async {
//     _interpreter = await Interpreter.fromAsset('model.tflite');
//     final labelData = await rootBundle.loadString('assets/labels.txt');
//     _labels = labelData.split('\n').map((label) => label.trim()).toList();
//   }

//   Future<String?> runEmotionModel(CameraImage image) async {
//     final input = _preprocessPlaceholder(image); // mock input for now

//     // Correct output shape: [1, labels.length] and cast
//     var output = List.generate(1, (_) => List.filled(_labels.length, 0)).cast<List<int>>();

//     _interpreter.run(input, output);

//     return _postprocessOutput(output);
//   }

//   Future<void> dispose() async {
//     _interpreter.close();
//   }

//   /// MOCK: Replace this when real preprocessing is implemented
//   List<List<List<double>>> _preprocessPlaceholder(CameraImage image) {
//     // For now we return dummy input shaped as [1, 48, 48] for grayscale
//     return List.generate(
//       48,
//       (_) => List.generate(
//         48,
//         (_) => [0.0],
//       ),
//     );
//   }

//   String? _postprocessOutput(List<List<int>> output) {
//     final scores = output[0];
//     final maxIndex = scores.indexWhere((score) => score == scores.reduce((a, b) => a > b ? a : b));
//     return _labels[maxIndex];
//   }
// }
