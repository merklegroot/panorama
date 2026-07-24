import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme.dart';

const aboutChannelName = 'com.panorama.fileexplorer/about';

Future<void> showPanoramaAbout(BuildContext context) async {
  final info = await PackageInfo.fromPlatform();
  DateTime? buildTime;
  try {
    buildTime = await File(Platform.resolvedExecutable).lastModified();
  } catch (_) {}

  if (!context.mounted) return;

  final versionLabel = info.version.isEmpty
      ? null
      : info.buildNumber.isEmpty
          ? info.version
          : '${info.version} (${info.buildNumber})';

  final buildLabel = buildTime == null ? null : _formatBuildTime(buildTime.toLocal());

  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('About Panorama'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Panorama',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'A desktop file manager.',
                style: TextStyle(fontSize: 13, color: PanoramaColors.muted),
              ),
              const SizedBox(height: 16),
              if (versionLabel != null) _AboutRow(label: 'Version', value: versionLabel),
              if (buildLabel != null) _AboutRow(label: 'Built', value: buildLabel),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

String _formatBuildTime(DateTime local) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour:$minute $period';
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PanoramaColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Listens for Help → About from the native menu bar.
class AboutMenuListener extends StatefulWidget {
  const AboutMenuListener({
    super.key,
    required this.child,
    required this.onAbout,
  });

  final Widget child;
  final VoidCallback onAbout;

  @override
  State<AboutMenuListener> createState() => _AboutMenuListenerState();
}

class _AboutMenuListenerState extends State<AboutMenuListener> {
  static const _channel = MethodChannel(aboutChannelName);

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'showAbout') {
        widget.onAbout();
      }
    });
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
