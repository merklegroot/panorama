import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';
import 'explorer_service.dart';
import 'theme.dart';
import 'widgets/about_dialog.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: const Size(1240, 780),
      minimumSize: const Size(850, 520),
      center: true,
      backgroundColor: const Color(0xFFF6F7F9),
      skipTaskbar: false,
      // macOS uses a hidden title bar with native traffic lights; Linux/Windows
      // need a normal title bar for minimize / maximize / close.
      titleBarStyle:
          Platform.isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
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
      home: Builder(
        builder: (context) {
          final shell = Scaffold(
            body: AppShell(controller: controller),
          );
          if (!isDesktop) return shell;
          return AboutMenuListener(
            onAbout: () => showPanoramaAbout(context),
            child: shell,
          );
        },
      ),
    );
  }
}
