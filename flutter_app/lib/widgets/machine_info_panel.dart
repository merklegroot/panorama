import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../models.dart';
import '../theme.dart';
import 'system_icons.dart';

class MachineInfoPanel extends StatelessWidget {
  const MachineInfoPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final onProcessor = controller.machineInfoPage == MachineInfoPage.processor;
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
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                          child: Row(
                            children: [
                              if (onProcessor)
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: controller.showMachineInfoOverview,
                                  icon: const Icon(Icons.arrow_back),
                                )
                              else
                                const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      onProcessor ? 'Processor' : 'System',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      onProcessor
                                          ? 'Details about this CPU.'
                                          : 'Basic info about this machine.',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: PanoramaColors.muted,
                                      ),
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
                        if (!onProcessor && controller.machineInfoLoading)
                          const Expanded(
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (!onProcessor && controller.machineInfoError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              controller.machineInfoError,
                              style: const TextStyle(color: PanoramaColors.danger, fontSize: 13),
                            ),
                          )
                        else if (onProcessor)
                          Expanded(child: _ProcessorDetail(controller: controller))
                        else if (info != null)
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                              children: [
                                _row(
                                  'Name',
                                  info.hostname,
                                  icon: SystemIcons.hostname(),
                                ),
                                _row(
                                  'User',
                                  info.username.isEmpty ? '—' : info.username,
                                  icon: SystemIcons.user(),
                                ),
                                _row(
                                  'OS',
                                  '${info.osName} ${info.osVersion}'.trim(),
                                  icon: SystemIcons.os(info.osName),
                                ),
                                _ProcessorRow(
                                  cpu: info.cpu,
                                  arch: info.arch,
                                  onTap: controller.showProcessorInfo,
                                ),
                                _row(
                                  'Memory',
                                  info.memoryBytes > 0
                                      ? formatSize(info.memoryBytes, false)
                                      : '—',
                                  icon: SystemIcons.memory(),
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

  Widget _row(String label, String value, {Widget? icon}) {
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
          SystemValueLine(value: value, icon: icon),
        ],
      ),
    );
  }
}

class _ProcessorRow extends StatelessWidget {
  const _ProcessorRow({
    required this.cpu,
    required this.arch,
    required this.onTap,
  });

  final String cpu;
  final String arch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = cpu.trim().isEmpty ? '—' : cpu.trim();
    final architecture = arch.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Processor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PanoramaColors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SystemIcons.cpu(name, arch: architecture),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: PanoramaColors.ink,
                                ),
                              ),
                              if (architecture.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  architecture,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PanoramaColors.muted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: PanoramaColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProcessorDetail extends StatelessWidget {
  const _ProcessorDetail({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.processorInfoLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (controller.processorInfoError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          controller.processorInfoError,
          style: const TextStyle(color: PanoramaColors.danger, fontSize: 13),
        ),
      );
    }
    final info = controller.processorInfo;
    if (info == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SystemIcons.cpu(info.name, arch: info.arch, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (info.arch.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      info.arch,
                      style: const TextStyle(fontSize: 13, color: PanoramaColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        for (final attr in info.attributes)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attr.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PanoramaColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attr.value,
                  style: const TextStyle(fontSize: 14, color: PanoramaColors.ink),
                ),
              ],
            ),
          ),
        if (info.attributes.isEmpty)
          const Text(
            'No additional details available.',
            style: TextStyle(fontSize: 13, color: PanoramaColors.muted),
          ),
      ],
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
