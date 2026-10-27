import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameras, this.startupError});

  final List<CameraDescription> cameras;
  final String? startupError;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  static const _preferredLensKey = 'preferred_camera_lens';

  CameraController? _controller;
  bool _isTakingPhoto = false;
  String? _cameraError;
  CameraLensDirection _activeLens = CameraLensDirection.back;
  bool _isSwitchingCamera = false;

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
    _initializeCameraPreference();
  }

  Future<void> _initializeCameraPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_preferredLensKey);
    final preferredLens = stored == CameraLensDirection.front.name
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    if (!mounted) return;
    await _setupCamera(preferredLens);
  }

  Future<void> _savePreferredLens(CameraLensDirection lens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredLensKey, lens.name);
  }

  int _cameraPriority(CameraDescription camera, CameraLensDirection lensDirection) {
    if (camera.lensDirection != lensDirection) {
      return 1000;
    }

    if (lensDirection != CameraLensDirection.back) {
      return 0;
    }

    final name = camera.name.toLowerCase();
    // Prefer the main 1x camera and avoid ultra-wide/macro lenses.
    if (name.contains('ultra') || name.contains('0.5') || name.contains('macro')) {
      return 100;
    }
    if (name.contains('tele')) {
      return 50;
    }
    return 0;
  }

  Future<void> _setupCamera([CameraLensDirection? preferredLens]) async {
    if (widget.cameras.isEmpty) {
      setState(() {
        _cameraError = widget.startupError ?? 'No camera found on this device.';
      });
      return;
    }

    final requestedLens = preferredLens ?? _activeLens;
    final hasRequestedLens = widget.cameras.any((camera) => camera.lensDirection == requestedLens);
    final selectedLens = hasRequestedLens ? requestedLens : CameraLensDirection.back;

    final sorted = [...widget.cameras]
      ..sort((a, b) => _cameraPriority(a, selectedLens).compareTo(_cameraPriority(b, selectedLens)));
    final selected = sorted.first;

    final previousController = _controller;
    if (mounted) {
      setState(() {
        _controller = null;
      });
    }
    await previousController?.dispose();

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
        _activeLens = selected.lensDirection;
      });
      await _savePreferredLens(selected.lensDirection);
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera initialization failed: $e';
      });
    }
  }

  bool get _canSwitchCamera {
    final hasFront = widget.cameras.any((camera) => camera.lensDirection == CameraLensDirection.front);
    final hasBack = widget.cameras.any((camera) => camera.lensDirection == CameraLensDirection.back);
    return hasFront && hasBack;
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera || _isTakingPhoto || !_canSwitchCamera) {
      return;
    }

    final nextLens = _activeLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      await _setupCamera(nextLens);
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
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
      appBar: AppBar(
        title: const Text('Frame Camera'),
        actions: [
          if (_canSwitchCamera)
            IconButton(
              onPressed: _isSwitchingCamera ? null : _switchCamera,
              icon: const Icon(Icons.cameraswitch_rounded),
              tooltip: 'Switch camera',
            ),
        ],
      ),
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
