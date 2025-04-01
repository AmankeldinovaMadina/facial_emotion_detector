import 'package:flutter/material.dart';

Widget buildLabel(String text, {Color color = Colors.black}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.6),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
  );
}
