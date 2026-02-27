import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = const <CameraDescription>[];
  String? startupError;

  try {
    cameras = await availableCameras();
  } catch (e) {
    startupError = e.toString();
  }

  runApp(FrameMobileApp(cameras: cameras, startupError: startupError));
}

class FrameMobileApp extends StatelessWidget {
  const FrameMobileApp({
    super.key,
    required this.cameras,
    this.startupError,
  });

  final List<CameraDescription> cameras;
  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras, startupError: startupError),
    );
  }
}
