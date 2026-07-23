import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../folder_pane_controller.dart';
import '../models.dart';
import '../theme.dart';

class FolderPaneView extends StatefulWidget {
  const FolderPaneView({
    super.key,
    required this.controller,
    required this.pane,
    required this.paneId,
    required this.showChrome,
  });

  final AppController controller;
  final FolderPaneController pane;
  final PaneId paneId;
  final bool showChrome;

  @override
  State<FolderPaneView> createState() => _FolderPaneViewState();
}

class _FolderPaneViewState extends State<FolderPaneView> {
  bool _dragOver = false;
  bool _editingAddress = false;
  late TextEditingController _addressController;
  final Map<String, TextEditingController> _renameControllers = {};
  int _lastEditRequest = 0;

  AppController get app => widget.controller;
  FolderPaneController get pane => widget.pane;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: pane.path);
  }

  @override
  void didUpdateWidget(covariant FolderPaneView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (app.editAddressRequest != _lastEditRequest &&
        widget.showChrome &&
        app.activePaneId == widget.paneId) {
      _lastEditRequest = app.editAddressRequest;
      setState(() {
        _addressController.text = pane.path;
        _editingAddress = true;
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    for (final c in _renameControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  IconData _fileIcon(FileEntry entry) {
    if (entry.isDirectory) return Icons.folder;
    if (imageExtensions.contains(entry.extension)) return Icons.image_outlined;
    if (const {'js', 'jsx', 'ts', 'tsx', 'css', 'html', 'py', 'rs', 'go', 'json'}
        .contains(entry.extension)) {
      return Icons.code;
    }
    if (const {'zip', 'rar', '7z', 'tar', 'gz', 'dmg'}.contains(entry.extension)) {
      return Icons.archive_outlined;
    }
    if (const {'txt', 'md', 'pdf', 'doc', 'docx', 'rtf'}.contains(entry.extension)) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Widget _leadingIcon(FileEntry entry, {required bool grid}) {
    final size = grid ? 48.0 : 20.0;
    if (grid &&
        !entry.isDirectory &&
        imageExtensions.contains(entry.extension) &&
        File(entry.path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(entry.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => Icon(
            _fileIcon(entry),
            size: size,
            color: const Color(0xFF55738F),
          ),
        ),
      );
    }
    return Icon(
      _fileIcon(entry),
      size: size,
      color: entry.isDirectory ? const Color(0xFFF0C040) : const Color(0xFF55738F),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = app.activePaneId == widget.paneId;
    final pathParts = pane.path.split('/').where((p) => p.isNotEmpty).toList();

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: (detail) {
        setState(() => _dragOver = false);
        app.setActivePane(widget.paneId);
        final paths = detail.files.map((f) => f.path).where((p) => p.isNotEmpty).toList();
        app.importExternalFiles(pane, paths);
      },
      child: GestureDetector(
        onTap: () => app.setActivePane(widget.paneId),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            border: Border.all(
              color: _dragOver
                  ? PanoramaColors.blue
                  : (active ? PanoramaColors.blue.withValues(alpha: 0.35) : PanoramaColors.line),
              width: _dragOver || active ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              if (widget.showChrome) _buildChrome(pathParts),
              Expanded(child: _buildFileArea()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChrome(List<String> pathParts) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PanoramaColors.line)),
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.arrow_back,
            tooltip: 'Back',
            enabled: pane.historyIndex > 0,
            onPressed: pane.goBack,
          ),
          _IconBtn(
            icon: Icons.arrow_forward,
            tooltip: 'Forward',
            enabled: pane.historyIndex < pane.history.length - 1,
            onPressed: pane.goForward,
          ),
          _IconBtn(
            icon: Icons.arrow_upward,
            tooltip: 'Up one level',
            enabled: pane.path != '/',
            onPressed: pane.goUp,
          ),
          _IconBtn(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            spinning: pane.loading,
            onPressed: pane.refresh,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _editingAddress
                ? TextField(
                    controller: _addressController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      prefixIcon: const Icon(Icons.folder_outlined, size: 15),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onSubmitted: (value) {
                      setState(() => _editingAddress = false);
                      pane.navigate(value);
                    },
                    onTapOutside: (_) => setState(() => _editingAddress = false),
                  )
                : GestureDetector(
                    onTap: () {
                      setState(() {
                        _addressController.text = pane.path;
                        _editingAddress = true;
                      });
                    },
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PanoramaColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.computer_outlined, size: 15, color: PanoramaColors.muted),
                          for (var i = 0; i < pathParts.length; i++) ...[
                            const Icon(Icons.chevron_right, size: 14, color: PanoramaColors.muted),
                            Flexible(
                              child: Text(
                                pathParts[i],
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 140,
            child: _PaneSearchField(pane: pane),
          ),
        ],
      ),
    );
  }

  Widget _buildFileArea() {
    if (pane.loading && pane.entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text('Loading folder…', style: TextStyle(color: PanoramaColors.muted)),
          ],
        ),
      );
    }
    if (pane.error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 40, color: PanoramaColors.muted),
              const SizedBox(height: 12),
              const Text('Can’t open this location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(pane.error, textAlign: TextAlign.center, style: const TextStyle(color: PanoramaColors.muted)),
            ],
          ),
        ),
      );
    }
    if (pane.visibleEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 40, color: PanoramaColors.muted),
            const SizedBox(height: 12),
            Text(
              pane.search.isNotEmpty ? 'No matching files' : 'This folder is empty',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              pane.search.isNotEmpty
                  ? 'Nothing here matches “${pane.search}”.'
                  : 'Files you add will appear here.',
              style: const TextStyle(color: PanoramaColors.muted),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (details) {
        app.showContextMenu(
          position: details.globalPosition,
          paneId: widget.paneId,
        );
      },
      onTap: () {
        app.setActivePane(widget.paneId);
        pane.setSelected({});
      },
      child: app.view == ViewMode.list ? _buildList() : _buildGrid(),
    );
  }

  Widget _buildList() {
    return Column(
      children: [
        Container(
          height: 28,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PanoramaColors.line)),
          ),
          child: Row(
            children: [
              _sortHeader('Name', SortKey.name, flex: 4),
              _sortHeader('Date modified', SortKey.modified, flex: 3),
              _sortHeader('Type', SortKey.type, flex: 2),
              _sortHeader('Size', SortKey.size, flex: 1),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pane.visibleEntries.length,
            itemBuilder: (context, index) {
              final entry = pane.visibleEntries[index];
              final selected = pane.selected.contains(entry.path);
              return _FileRow(
                entry: entry,
                selected: selected,
                renaming: app.renaming == entry.path,
                leading: _leadingIcon(entry, grid: false),
                onTap: (event) {
                  app.setActivePane(widget.paneId);
                  pane.chooseEntry(
                    entry,
                    additive: HardwareKeyboard.instance.isMetaPressed ||
                        HardwareKeyboard.instance.isControlPressed,
                  );
                },
                onDoubleTap: () => app.openEntryIn(pane, entry),
                onSecondaryTap: (pos) {
                  app.showContextMenu(
                    position: pos,
                    paneId: widget.paneId,
                    entry: entry,
                  );
                },
                onRenameSubmit: (name) => app.submitRename(entry, name),
                onRenameCancel: app.cancelRename,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sortHeader(String label, SortKey key, {required int flex}) {
    final active = pane.sortKey == key;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => pane.setSortKey(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: PanoramaColors.muted)),
              if (active)
                Icon(
                  pane.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 12,
                  color: PanoramaColors.muted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: pane.visibleEntries.length,
      itemBuilder: (context, index) {
        final entry = pane.visibleEntries[index];
        final selected = pane.selected.contains(entry.path);
        return Material(
          color: selected ? PanoramaColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              app.setActivePane(widget.paneId);
              pane.chooseEntry(
                entry,
                additive: HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed,
              );
            },
            onDoubleTap: () => app.openEntryIn(pane, entry),
            onSecondaryTapDown: (d) {
              app.showContextMenu(
                position: d.globalPosition,
                paneId: widget.paneId,
                entry: entry,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Expanded(child: Center(child: _leadingIcon(entry, grid: true))),
                  Text(
                    entry.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.selected,
    required this.renaming,
    required this.leading,
    required this.onTap,
    required this.onDoubleTap,
    required this.onSecondaryTap,
    required this.onRenameSubmit,
    required this.onRenameCancel,
  });

  final FileEntry entry;
  final bool selected;
  final bool renaming;
  final Widget leading;
  final void Function(PointerDownEvent?) onTap;
  final VoidCallback onDoubleTap;
  final void Function(Offset) onSecondaryTap;
  final void Function(String) onRenameSubmit;
  final VoidCallback onRenameCancel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? PanoramaColors.selected : Colors.transparent,
      child: InkWell(
        onTap: () => onTap(null),
        onDoubleTap: onDoubleTap,
        onSecondaryTapDown: (d) => onSecondaryTap(d.globalPosition),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      leading,
                      const SizedBox(width: 8),
                      Expanded(
                        child: renaming
                            ? _RenameField(
                                initial: entry.name,
                                onSubmit: onRenameSubmit,
                                onCancel: onRenameCancel,
                              )
                            : Text(entry.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  formatModified(entry.modified),
                  style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  entry.fileType,
                  style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  formatSize(entry.size, entry.isDirectory),
                  style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RenameField extends StatefulWidget {
  const _RenameField({
    required this.initial,
    required this.onSubmit,
    required this.onCancel,
  });

  final String initial;
  final void Function(String) onSubmit;
  final VoidCallback onCancel;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onCancel();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          border: OutlineInputBorder(),
        ),
        onSubmitted: widget.onSubmit,
        onTapOutside: (_) => widget.onSubmit(_controller.text),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
    this.spinning = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled;
  final bool spinning;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: spinning
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: enabled ? PanoramaColors.ink : PanoramaColors.muted),
              )
            : Icon(icon, size: 16),
        onPressed: enabled ? onPressed : null,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      ),
    );
  }
}

class _PaneSearchField extends StatefulWidget {
  const _PaneSearchField({required this.pane});

  final FolderPaneController pane;

  @override
  State<_PaneSearchField> createState() => _PaneSearchFieldState();
}

class _PaneSearchFieldState extends State<_PaneSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.pane.search);
  }

  @override
  void didUpdateWidget(covariant _PaneSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.pane.search && !_controller.value.composing.isValid) {
      _controller.text = widget.pane.search;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.pane.setSearch,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search, size: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
