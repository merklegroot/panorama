import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../folder_pane_controller.dart';
import '../models.dart';
import '../theme.dart';
import 'address_path_field.dart';
import 'marquee_select.dart';

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
  Set<String> _marqueeBase = const {};
  bool _skipClearOnTap = false;

  AppController get app => widget.controller;
  FolderPaneController get pane => widget.pane;

  void _onMarqueeStarted() {
    app.setActivePane(widget.paneId);
    _marqueeBase = Set<String>.from(pane.selected);
    _skipClearOnTap = true;
  }

  void _onMarqueeSelection(Set<String> paths, {required bool additive}) {
    if (additive) {
      pane.setSelected({..._marqueeBase, ...paths});
    } else {
      pane.setSelected(paths);
    }
  }

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
    final size = grid ? app.iconSize.iconPixels : 20.0;
    if (grid && !entry.isDirectory && imageExtensions.contains(entry.extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(entry.path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
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
    return ListenableBuilder(
      listenable: pane,
      builder: (context, _) {
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
      },
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
                ? AddressPathField(
                    controller: _addressController,
                    height: 30,
                    onSubmit: (value) {
                      setState(() => _editingAddress = false);
                      pane.navigate(value);
                    },
                    onCancel: () => setState(() => _editingAddress = false),
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
        if (_skipClearOnTap) {
          _skipClearOnTap = false;
          return;
        }
        pane.setSelected({});
      },
      child: app.view == ViewMode.list ? _buildList() : _buildGrid(),
    );
  }

  Widget _buildList() {
    final entries = pane.visibleEntries;
    return Column(
      children: [
        _ColumnHeaderBar(pane: pane),
        Expanded(
          child: MarqueeSelectArea(
            entries: entries,
            layout: const ListMarqueeLayout(),
            onMarqueeStarted: _onMarqueeStarted,
            onMarqueeSelection: _onMarqueeSelection,
            child: (scrollController, marqueeActive) {
              return ListView.builder(
                controller: scrollController,
                physics: marqueeActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                itemExtent: 32,
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _FileRow(
                    key: ValueKey(entry.path),
                    entry: entry,
                    pane: pane,
                    renaming: app.renaming == entry.path,
                    leading: _leadingIcon(entry, grid: false),
                    onSelect: () {
                      app.setActivePane(widget.paneId);
                      final shift = HardwareKeyboard.instance.isShiftPressed;
                      final meta = HardwareKeyboard.instance.isMetaPressed ||
                          HardwareKeyboard.instance.isControlPressed;
                      pane.chooseEntry(
                        entry,
                        additive: meta && !shift,
                        range: shift,
                      );
                    },
                    onOpen: () => app.openEntryIn(pane, entry),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final entries = pane.visibleEntries;
    final iconSize = app.iconSize;
    return MarqueeSelectArea(
      entries: entries,
      layout: GridMarqueeLayout(
        maxCrossAxisExtent: iconSize.cellExtent,
        childAspectRatio: iconSize.aspectRatio,
      ),
      onMarqueeStarted: _onMarqueeStarted,
      onMarqueeSelection: _onMarqueeSelection,
      child: (scrollController, marqueeActive) {
        return GridView.builder(
          controller: scrollController,
          physics: marqueeActive ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: iconSize.cellExtent,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: iconSize.aspectRatio,
          ),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _GridTile(
              key: ValueKey('${entry.path}:${iconSize.name}'),
              entry: entry,
              pane: pane,
              nameFontSize: iconSize.nameFontSize,
              leading: _leadingIcon(entry, grid: true),
              onSelect: () {
                app.setActivePane(widget.paneId);
                final shift = HardwareKeyboard.instance.isShiftPressed;
                final meta = HardwareKeyboard.instance.isMetaPressed ||
                    HardwareKeyboard.instance.isControlPressed;
                pane.chooseEntry(
                  entry,
                  additive: meta && !shift,
                  range: shift,
                );
              },
              onOpen: () => app.openEntryIn(pane, entry),
              onSecondaryTap: (pos) {
                app.showContextMenu(
                  position: pos,
                  paneId: widget.paneId,
                  entry: entry,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Pixel widths for list columns from the pane's stored sizes.
Map<SortKey, double> _resolvedColumnWidths(FolderPaneController pane) {
  return {
    for (final key in pane.columnOrder) key: pane.widthForColumn(key),
  };
}

class _ColumnHeaderBar extends StatefulWidget {
  const _ColumnHeaderBar({required this.pane});

  final FolderPaneController pane;

  @override
  State<_ColumnHeaderBar> createState() => _ColumnHeaderBarState();
}

class _ColumnHeaderBarState extends State<_ColumnHeaderBar> {
  SortKey? _dragging;
  SortKey? _hoverTarget;
  bool _hoverBefore = true;

  FolderPaneController get pane => widget.pane;

  void _onReorderDrop(SortKey from, SortKey to, {required bool before}) {
    final order = pane.columnOrder;
    final oldIndex = order.indexOf(from);
    var newIndex = order.indexOf(to);
    if (oldIndex < 0 || newIndex < 0 || from == to) return;
    if (!before) newIndex += 1;
    pane.reorderColumn(oldIndex, newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pane,
      builder: (context, _) {
        return Container(
          height: 28,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: PanoramaColors.line)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final order = pane.columnOrder;
              final widths = _resolvedColumnWidths(pane);
              // Stretch the final column so the header fills the pane width.
              final used =
                  widths.values.fold<double>(0, (sum, w) => sum + w);
              if (order.isNotEmpty && constraints.maxWidth > used) {
                final last = order.last;
                widths[last] =
                    widths[last]! + (constraints.maxWidth - used);
              }
              return Row(
                children: [
                  for (var i = 0; i < order.length; i++)
                    _HeaderCell(
                      columnKey: order[i],
                      width: widths[order[i]]!,
                      pane: pane,
                      dragging: _dragging,
                      hoverTarget: _hoverTarget,
                      hoverBefore: _hoverBefore,
                      onDragStarted: () => setState(() => _dragging = order[i]),
                      onDragEnded: () => setState(() {
                        _dragging = null;
                        _hoverTarget = null;
                      }),
                      onHover: (target, before) {
                        if (_hoverTarget == target && _hoverBefore == before) {
                          return;
                        }
                        setState(() {
                          _hoverTarget = target;
                          _hoverBefore = before;
                        });
                      },
                      onLeave: (target) {
                        if (_hoverTarget == target) {
                          setState(() => _hoverTarget = null);
                        }
                      },
                      onAccept: (from, to, before) {
                        _onReorderDrop(from, to, before: before);
                        setState(() {
                          _dragging = null;
                          _hoverTarget = null;
                        });
                      },
                      onResize: i == order.length - 1
                          ? null
                          : (delta) {
                              pane.resizeColumnEdge(
                                order[i],
                                order[i + 1],
                                delta,
                              );
                            },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.columnKey,
    required this.width,
    required this.pane,
    required this.dragging,
    required this.hoverTarget,
    required this.hoverBefore,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHover,
    required this.onLeave,
    required this.onAccept,
    required this.onResize,
  });

  final SortKey columnKey;
  final double width;
  final FolderPaneController pane;
  final SortKey? dragging;
  final SortKey? hoverTarget;
  final bool hoverBefore;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final void Function(SortKey target, bool before) onHover;
  final void Function(SortKey target) onLeave;
  final void Function(SortKey from, SortKey to, bool before) onAccept;
  final void Function(double delta)? onResize;

  @override
  Widget build(BuildContext context) {
    final active = pane.sortKey == columnKey;
    final label = FolderPaneController.columnLabels[columnKey]!;
    final showInsert =
        dragging != null && dragging != columnKey && hoverTarget == columnKey;

    return SizedBox(
      width: width,
      child: DragTarget<SortKey>(
        onWillAcceptWithDetails: (details) => details.data != columnKey,
        onMove: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null || !box.hasSize) return;
          final local = box.globalToLocal(details.offset);
          onHover(columnKey, local.dx < box.size.width / 2);
        },
        onLeave: (_) => onLeave(columnKey),
        onAcceptWithDetails: (details) {
          onAccept(details.data, columnKey, hoverBefore);
        },
        builder: (context, candidate, rejected) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (showInsert && hoverBefore)
                const Positioned(
                  left: 0,
                  top: 2,
                  bottom: 2,
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: PanoramaColors.blue,
                  ),
                ),
              if (showInsert && !hoverBefore)
                const Positioned(
                  right: 0,
                  top: 2,
                  bottom: 2,
                  child: VerticalDivider(
                    width: 2,
                    thickness: 2,
                    color: PanoramaColors.blue,
                  ),
                ),
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Draggable<SortKey>(
                    data: columnKey,
                    onDragStarted: onDragStarted,
                    onDragEnd: (_) => onDragEnded(),
                    onDraggableCanceled: (_, _) => onDragEnded(),
                    feedback: Material(
                      elevation: 3,
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PanoramaColors.ink,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _label(label, active),
                    ),
                    child: InkWell(
                      onTap: () => pane.setSortKey(columnKey),
                      child: _label(label, active),
                    ),
                  ),
                ),
              ),
              if (onResize != null)
                Positioned(
                  right: -3,
                  top: 0,
                  bottom: 0,
                  width: 6,
                  child: _ColumnResizeHandle(onDrag: onResize!),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _label(String label, bool active) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PanoramaColors.muted,
              ),
            ),
          ),
          if (active)
            Icon(
              pane.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: PanoramaColors.muted,
            ),
        ],
      ),
    );
  }
}

class _ColumnResizeHandle extends StatelessWidget {
  const _ColumnResizeHandle({required this.onDrag});

  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(width: 6, height: double.infinity),
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    super.key,
    required this.entry,
    required this.pane,
    required this.renaming,
    required this.leading,
    required this.onSelect,
    required this.onOpen,
    required this.onSecondaryTap,
    required this.onRenameSubmit,
    required this.onRenameCancel,
  });

  final FileEntry entry;
  final FolderPaneController pane;
  final bool renaming;
  final Widget leading;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final void Function(Offset) onSecondaryTap;
  final void Function(String) onRenameSubmit;
  final VoidCallback onRenameCancel;

  ValueNotifier<Set<String>> get selection => pane.selection;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selection.value.contains(widget.entry.path);
    widget.pane.addSelectionListener(widget.entry.path, _onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _FileRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path || oldWidget.pane != widget.pane) {
      oldWidget.pane.removeSelectionListener(oldWidget.entry.path, _onSelectionChanged);
      widget.pane.addSelectionListener(widget.entry.path, _onSelectionChanged);
      _selected = widget.selection.value.contains(widget.entry.path);
    }
  }

  @override
  void dispose() {
    widget.pane.removeSelectionListener(widget.entry.path, _onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final next = widget.selection.value.contains(widget.entry.path);
    if (next == _selected || !mounted) return;
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _selected ? PanoramaColors.selected : Colors.transparent,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons & kPrimaryButton != 0) {
            widget.onSelect();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Claim the tap so the parent "clear selection" handler doesn't run.
          onTap: () {},
          onDoubleTap: widget.onOpen,
          onSecondaryTapUp: (details) => widget.onSecondaryTap(details.globalPosition),
          child: SizedBox(
            height: 32,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final order = widget.pane.columnOrder;
                final widths = _resolvedColumnWidths(widget.pane);
                final used =
                    widths.values.fold<double>(0, (sum, w) => sum + w);
                if (order.isNotEmpty && constraints.maxWidth > used) {
                  final last = order.last;
                  widths[last] =
                      widths[last]! + (constraints.maxWidth - used);
                }
                return Row(
                  children: [
                    for (final key in order)
                      SizedBox(
                        width: widths[key],
                        child: _cellFor(key),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellFor(SortKey key) {
    switch (key) {
      case SortKey.name:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              widget.leading,
              const SizedBox(width: 8),
              Expanded(
                child: widget.renaming
                    ? _RenameField(
                        initial: widget.entry.name,
                        onSubmit: widget.onRenameSubmit,
                        onCancel: widget.onRenameCancel,
                      )
                    : Text(
                        widget.entry.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
              ),
            ],
          ),
        );
      case SortKey.modified:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            formatModified(widget.entry.modified),
            style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        );
      case SortKey.type:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            widget.entry.fileType,
            style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        );
      case SortKey.size:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            formatSize(widget.entry.size, widget.entry.isDirectory),
            style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        );
    }
  }
}

class _GridTile extends StatefulWidget {
  const _GridTile({
    super.key,
    required this.entry,
    required this.pane,
    required this.leading,
    required this.nameFontSize,
    required this.onSelect,
    required this.onOpen,
    required this.onSecondaryTap,
  });

  final FileEntry entry;
  final FolderPaneController pane;
  final Widget leading;
  final double nameFontSize;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final void Function(Offset) onSecondaryTap;

  ValueNotifier<Set<String>> get selection => pane.selection;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selection.value.contains(widget.entry.path);
    widget.pane.addSelectionListener(widget.entry.path, _onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _GridTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.path != widget.entry.path || oldWidget.pane != widget.pane) {
      oldWidget.pane.removeSelectionListener(oldWidget.entry.path, _onSelectionChanged);
      widget.pane.addSelectionListener(widget.entry.path, _onSelectionChanged);
      _selected = widget.selection.value.contains(widget.entry.path);
    }
  }

  @override
  void dispose() {
    widget.pane.removeSelectionListener(widget.entry.path, _onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final next = widget.selection.value.contains(widget.entry.path);
    if (next == _selected || !mounted) return;
    setState(() => _selected = next);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _selected ? PanoramaColors.selected : Colors.transparent,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (event.buttons & kPrimaryButton != 0) {
            widget.onSelect();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Claim the tap so the parent "clear selection" handler doesn't run.
          onTap: () {},
          onDoubleTap: widget.onOpen,
          onSecondaryTapUp: (details) => widget.onSecondaryTap(details.globalPosition),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Expanded(child: Center(child: widget.leading)),
                Text(
                  widget.entry.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: widget.nameFontSize),
                ),
              ],
            ),
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
