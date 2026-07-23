import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../folder_pane_controller.dart';
import '../theme.dart';
import 'address_path_field.dart';

class CommandBar extends StatelessWidget {
  const CommandBar({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pane = controller.activePane;
    final hasSelection = pane.selected.isNotEmpty;
    final singleSelection = pane.selected.length == 1;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PanoramaColors.line)),
      ),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: controller.createFolder,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New folder'),
            style: FilledButton.styleFrom(
              backgroundColor: PanoramaColors.blue,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),
          const _VSep(),
          _Tb(icon: Icons.content_cut, tip: 'Cut', enabled: hasSelection, onPressed: () => controller.copySelected(true)),
          _Tb(icon: Icons.copy, tip: 'Copy', enabled: hasSelection, onPressed: () => controller.copySelected(false)),
          _Tb(icon: Icons.content_paste, tip: 'Paste', onPressed: controller.paste),
          _Tb(
            icon: Icons.edit,
            tip: 'Rename',
            enabled: singleSelection,
            onPressed: () {
              final entry = controller.selectedEntries.firstOrNull;
              if (entry != null) controller.startRename(entry.path);
            },
          ),
          _Tb(icon: Icons.delete_outline, tip: 'Move to Trash', enabled: hasSelection, onPressed: controller.removeSelected),
          const Spacer(),
          _Tb(
            icon: Icons.sticky_note_2_outlined,
            tip: 'Notes',
            toggled: controller.notesOpen,
            onPressed: () {
              if (controller.notesOpen) {
                controller.closeNotesPanel();
              } else {
                controller.openNotesPanel();
              }
            },
          ),
          _Tb(
            icon: Icons.visibility_outlined,
            tip: controller.showHidden ? 'Hide hidden files' : 'Show hidden files',
            toggled: controller.showHidden,
            onPressed: controller.toggleShowHidden,
          ),
          _Tb(
            icon: Icons.view_column_outlined,
            tip: controller.dualPane ? 'Single pane' : 'Two panes',
            toggled: controller.dualPane,
            onPressed: controller.toggleDualPane,
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _Tb(
                  icon: Icons.view_list,
                  tip: 'Details view',
                  toggled: controller.view == ViewMode.list,
                  onPressed: () => controller.setView(ViewMode.list),
                ),
                _Tb(
                  icon: Icons.grid_view,
                  tip: 'Icon view',
                  toggled: controller.view == ViewMode.grid,
                  onPressed: () => controller.setView(ViewMode.grid),
                ),
              ],
            ),
          ),
          _Tb(
            icon: Icons.more_horiz,
            tip: 'More options',
            onPressed: () {
              final size = MediaQuery.sizeOf(context);
              controller.showContextMenu(
                position: Offset(size.width - 225, 96),
                paneId: controller.activePaneId,
              );
            },
          ),
        ],
      ),
    );
  }
}

class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.controller});

  final AppController controller;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  bool _editingAddress = false;
  late final TextEditingController _address;
  late final TextEditingController _search;
  int _lastEditRequest = 0;

  AppController get app => widget.controller;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: app.activePane.path);
    _search = TextEditingController(text: app.activePane.search);
  }

  @override
  void didUpdateWidget(covariant TitleBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (app.editAddressRequest != _lastEditRequest && !app.dualPane) {
      _lastEditRequest = app.editAddressRequest;
      setState(() {
        _address.text = app.activePane.path;
        _editingAddress = true;
      });
    }
    if (_search.text != app.activePane.search && !_search.selection.isValid) {
      _search.text = app.activePane.search;
    }
  }

  @override
  void dispose() {
    _address.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (app.dualPane) {
      return const SizedBox(height: 38);
    }

    final pane = app.activePane;
    final pathParts = pane.path.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 48,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _Tb(icon: Icons.arrow_back, tip: 'Back', enabled: pane.historyIndex > 0, onPressed: pane.goBack),
          _Tb(icon: Icons.arrow_forward, tip: 'Forward', enabled: pane.historyIndex < pane.history.length - 1, onPressed: pane.goForward),
          _Tb(icon: Icons.arrow_upward, tip: 'Up one level', enabled: pane.path != '/', onPressed: pane.goUp),
          _Tb(icon: Icons.refresh, tip: 'Refresh', spinning: pane.loading, onPressed: app.refreshActive),
          const SizedBox(width: 8),
          Expanded(
            child: _editingAddress
                ? AddressPathField(
                    controller: _address,
                    height: 32,
                    onSubmit: (value) {
                      setState(() => _editingAddress = false);
                      pane.navigate(value);
                    },
                    onCancel: () => setState(() => _editingAddress = false),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _address.text = pane.path;
                        _editingAddress = true;
                      });
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PanoramaColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.computer_outlined, size: 15, color: PanoramaColors.muted),
                          for (final part in pathParts) ...[
                            const Icon(Icons.chevron_right, size: 14, color: PanoramaColors.muted),
                            Flexible(
                              child: Text(part, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _search,
              onChanged: pane.setSearch,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search this folder',
                prefixIcon: const Icon(Icons.search, size: 15),
                suffixIcon: pane.search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () {
                          _search.clear();
                          pane.setSearch('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pane = controller.activePane;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PanoramaColors.line)),
      ),
      child: Row(
        children: [
          Text(
            '${pane.visibleEntries.length} ${pane.visibleEntries.length == 1 ? 'item' : 'items'}',
            style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
          ),
          if (pane.selected.isNotEmpty) ...[
            const Text('  •  ', style: TextStyle(fontSize: 11, color: PanoramaColors.muted)),
            Text(
              '${pane.selected.length} selected',
              style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
            ),
          ],
          if (controller.dualPane) ...[
            const Text('  •  ', style: TextStyle(fontSize: 11, color: PanoramaColors.muted)),
            Text(
              '${controller.activePaneId == PaneId.left ? 'Left' : 'Right'} pane',
              style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
            ),
          ],
          const Spacer(),
          Flexible(
            child: Text(
              pane.path,
              style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _VSep extends StatelessWidget {
  const _VSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: PanoramaColors.line,
    );
  }
}

class _Tb extends StatelessWidget {
  const _Tb({
    required this.icon,
    required this.tip,
    required this.onPressed,
    this.enabled = true,
    this.toggled = false,
    this.spinning = false,
  });

  final IconData icon;
  final String tip;
  final VoidCallback onPressed;
  final bool enabled;
  final bool toggled;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: toggled ? PanoramaColors.blueSoft : null,
          foregroundColor: toggled ? PanoramaColors.blue : null,
        ),
        icon: spinning
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 18),
      ),
    );
  }
}
