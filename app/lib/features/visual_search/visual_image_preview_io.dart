import 'dart:io';

import 'package:flutter/widgets.dart';

Widget buildVisualImagePreview(String path) {
  final file = File(path);
  if (!file.existsSync()) return const SizedBox.expand();
  return Image.file(file, fit: BoxFit.cover);
}
