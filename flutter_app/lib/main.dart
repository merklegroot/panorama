import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'explorer_service.dart';
import 'theme.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1240, 780),
      minimumSize: Size(850, 520),
      center: true,
      backgroundColor: Color(0xFFF6F7F9),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Panorama',
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final api = ExplorerService();
  final controller = AppController(api);
  await controller.init();

  runApp(PanoramaApp(controller: controller));
}

class PanoramaApp extends StatelessWidget {
  const PanoramaApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panorama',
      debugShowCheckedModeBanner: false,
      theme: buildPanoramaTheme(),
      home: Scaffold(
        body: AppShell(controller: controller),
      ),
    );
  }
}
