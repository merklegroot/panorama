import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../theme.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.controller});

  final AppController controller;

  IconData _iconFor(String key) {
    return switch (key) {
      'home' => Icons.home_outlined,
      'monitor' => Icons.desktop_windows_outlined,
      'file' => Icons.description_outlined,
      'download' => Icons.download_outlined,
      'image' => Icons.image_outlined,
      'music' => Icons.music_note_outlined,
      'video' => Icons.movie_outlined,
      'trash' => Icons.delete_outline,
      _ => Icons.folder_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pane = controller.activePane;
    return Container(
      width: controller.sidebarWidth,
      decoration: const BoxDecoration(
        color: PanoramaColors.sidebar,
        border: Border(right: BorderSide(color: PanoramaColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 47),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4C92F1), Color(0xFF2164C6)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x402669CA),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.folder_open, size: 17, color: Colors.white),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Panorama',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              children: [
                const _NavLabel('Quick access'),
                for (final location in controller.locations)
                  _NavItem(
                    icon: _iconFor(location.icon),
                    label: location.name,
                    active: pane.path == location.path,
                    onTap: () => pane.navigate(location.path),
                  ),
                const SizedBox(height: 14),
                const _NavLabel('Locations'),
                _NavItem(
                  icon: Icons.computer_outlined,
                  label: 'Macintosh HD',
                  active: pane.path == '/',
                  onTap: () => pane.navigate('/'),
                ),
                _NavItem(
                  icon: Icons.add,
                  label: 'Open folder…',
                  active: false,
                  onTap: () async {
                    final folder = await controller.api.chooseFolder();
                    if (folder != null) pane.navigate(folder);
                  },
                ),
              ],
            ),
          ),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PanoramaColors.line)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: PanoramaColors.muted),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    pane.selected.isNotEmpty
                        ? '${pane.selected.length} selected'
                        : '${pane.entries.length} items',
                    style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF7D8692),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? const Color(0xD6FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        elevation: active ? 0.5 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: active ? const Color(0xFF2B72D3) : const Color(0xFF55738F),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? PanoramaColors.navActive : PanoramaColors.ink,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SidebarResizeHandle extends StatelessWidget {
  const SidebarResizeHandle({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          controller.setSidebarWidth(controller.sidebarWidth + details.delta.dx);
        },
        child: const SizedBox(width: 6, height: double.infinity),
      ),
    );
  }
}
