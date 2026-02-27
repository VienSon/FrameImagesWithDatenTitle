import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras, this.startupError});

  final List<CameraDescription> cameras;
  final String? startupError;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isTakingPhoto = false;
  String? _cameraError;

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 72),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _cameraError = widget.startupError ?? 'No camera found on this device.';
      });
      return;
    }

    final selected = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );

    final controller = CameraController(
      selected,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _cameraError = null;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera initialization failed: $e';
      });
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isTakingPhoto) {
      return;
    }

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PreviewScreen(imagePath: file.path),
        ),
      );
    } catch (e) {
      _showMessage('Failed to capture photo: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_cameraError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Frame Camera')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _setupCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Frame Camera')),
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CameraPreview(controller),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isTakingPhoto ? null : _takePhoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text(_isTakingPhoto ? 'Capturing...' : 'Take Photo'),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
