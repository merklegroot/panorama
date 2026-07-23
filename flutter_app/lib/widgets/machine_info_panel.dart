import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../theme.dart';

class MachineInfoPanel extends StatelessWidget {
  const MachineInfoPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final info = controller.machineInfo;

    return Positioned.fill(
      child: GestureDetector(
        onTap: controller.closeMachineInfo,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Material(
                elevation: 12,
                color: const Color(0xFFF7F8FA),
                child: SizedBox(
                  width: 360,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'System',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Basic info about this machine.',
                                      style: TextStyle(fontSize: 13, color: PanoramaColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: controller.closeMachineInfo,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        if (controller.machineInfoLoading)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (controller.machineInfoError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              controller.machineInfoError,
                              style: const TextStyle(color: PanoramaColors.danger, fontSize: 13),
                            ),
                          )
                        else if (info != null)
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              children: [
                                _row('Name', info.hostname),
                                _row('User', info.username.isEmpty ? '—' : info.username),
                                _row('OS', '${info.osName} ${info.osVersion}'.trim()),
                                _row('Processor', info.cpu),
                                _row('Architecture', info.arch),
                                _row(
                                  'Memory',
                                  info.memoryBytes > 0
                                      ? formatSize(info.memoryBytes, false)
                                      : '—',
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PanoramaColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: PanoramaColors.ink),
          ),
        ],
      ),
    );
  }
}
