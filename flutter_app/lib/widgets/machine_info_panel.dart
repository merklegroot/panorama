import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../models.dart';
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
                                const SizedBox(height: 8),
                                const Text(
                                  'Disks',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: PanoramaColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (info.disks.isEmpty)
                                  const Text(
                                    'No disks reported.',
                                    style: TextStyle(fontSize: 13, color: PanoramaColors.muted),
                                  )
                                else ...[
                                  for (final disk in info.disks.where((d) => d.isPrimary))
                                    _DiskCard(disk: disk),
                                  if (info.disks.any((d) => !d.isPrimary))
                                    _OtherVolumesSection(
                                      disks: info.disks.where((d) => !d.isPrimary).toList(),
                                    ),
                                ],
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

class _OtherVolumesSection extends StatelessWidget {
  const _OtherVolumesSection({required this.disks});

  final List<DiskVolume> disks;

  @override
  Widget build(BuildContext context) {
    final label = disks.length == 1
        ? '1 other volume'
        : '${disks.length} other volumes';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4),
        title: Text(
          label,
          style: const TextStyle(fontSize: 13, color: PanoramaColors.muted),
        ),
        children: [
          for (final disk in disks) _DiskCard(disk: disk),
        ],
      ),
    );
  }
}

class _DiskCard extends StatelessWidget {
  const _DiskCard({required this.disk});

  final DiskVolume disk;

  @override
  Widget build(BuildContext context) {
    final used = disk.usedFraction;
    final barColor = used >= 0.9
        ? PanoramaColors.danger
        : used >= 0.75
            ? const Color(0xFFC47F17)
            : PanoramaColors.blue;
    final isExternal = !disk.isPrimary ||
        disk.mountPoint.startsWith('/Volumes/') ||
        disk.mountPoint.toLowerCase().startsWith('/media/') ||
        disk.mountPoint.toLowerCase().startsWith('/run/media/') ||
        disk.mountPoint.toLowerCase().startsWith('/mnt/');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExternal ? Icons.usb_outlined : Icons.storage_outlined,
                size: 16,
                color: PanoramaColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  disk.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            disk.mountPoint == '/System/Volumes/Data' ? '/' : disk.mountPoint,
            style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: used,
              minHeight: 6,
              backgroundColor: PanoramaColors.line,
              color: barColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatSize(disk.freeBytes, false)} free of ${formatSize(disk.totalBytes, false)}',
            style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
          ),
        ],
      ),
    );
  }
}
