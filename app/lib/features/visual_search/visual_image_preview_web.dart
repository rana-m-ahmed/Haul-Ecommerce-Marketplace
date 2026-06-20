import 'package:flutter/widgets.dart';

Widget buildVisualImagePreview(String path) {
  return Image.network(path, fit: BoxFit.cover);
}
