import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraFailureKind { permissionDenied, unavailable, unknown }

class CameraFailure implements Exception {
  const CameraFailure(this.kind, this.message);

  final CameraFailureKind kind;
  final String message;
}

abstract interface class CameraGateway {
  Future<void> initialize();
  Widget buildPreview();
  bool get canUseFlash;
  bool get flashEnabled;
  Future<void> toggleFlash();
  Future<String> capture();
  Future<String?> pickFromGallery();
  Future<List<int>> bytesFor(String imagePath);
  Future<List<String>> labelsFor(String imagePath);
  Future<void> openSettings();
  Future<void> dispose();
}

class PluginCameraGateway implements CameraGateway {
  CameraController? _controller;
  final ImagePicker _picker = ImagePicker();
  bool _flashEnabled = false;

  @override
  bool get canUseFlash => _controller?.value.isInitialized == true;

  @override
  bool get flashEnabled => _flashEnabled;

  @override
  Future<void> initialize() async {
    await _controller?.dispose();
    _controller = null;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw const CameraFailure(
          CameraFailureKind.unavailable,
          'No camera was found on this device.',
        );
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controller = controller;
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      _flashEnabled = false;
    } on CameraException catch (error) {
      if (error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted') {
        throw CameraFailure(
          CameraFailureKind.permissionDenied,
          error.description ?? 'Camera permission is required.',
        );
      }
      throw CameraFailure(
        CameraFailureKind.unknown,
        error.description ?? 'The camera could not start.',
      );
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    _flashEnabled = !_flashEnabled;
    await controller.setFlashMode(
      _flashEnabled ? FlashMode.torch : FlashMode.off,
    );
  }

  @override
  Future<String> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw const CameraFailure(
        CameraFailureKind.unavailable,
        'The camera is not ready yet.',
      );
    }
    return (await controller.takePicture()).path;
  }

  @override
  Future<String?> pickFromGallery() async {
    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    return result?.path;
  }

  @override
  Future<List<int>> bytesFor(String imagePath) =>
      XFile(imagePath).readAsBytes();

  @override
  Future<List<String>> labelsFor(String imagePath) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    try {
      final labels = await labeler.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return labels
          .map((label) => label.label.toLowerCase())
          .take(8)
          .toList(growable: false);
    } catch (_) {
      return const [];
    } finally {
      await labeler.close();
    }
  }

  @override
  Future<void> openSettings() => openAppSettings();

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    _flashEnabled = false;
    await controller?.dispose();
  }
}
