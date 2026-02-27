import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(FrameMobileApp(cameras: cameras));
}

class FrameMobileApp extends StatelessWidget {
  const FrameMobileApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frame Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}
