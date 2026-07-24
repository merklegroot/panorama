import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../folder_pane_controller.dart';
import '../models.dart';
import '../theme.dart';

class NotesPanel extends StatefulWidget {
  const NotesPanel({super.key, required this.controller});

  final AppController controller;

  @override
  State<NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<NotesPanel> {
  late final TextEditingController _draft;
  late final FocusNode _draftFocus;
  final Map<String, TextEditingController> _editControllers = {};

  AppController get app => widget.controller;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: app.noteDraft);
    _draftFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _draftFocus.requestFocus());
  }

  @override
  void dispose() {
    _draft.dispose();
    _draftFocus.dispose();
    for (final c in _editControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: app.closeNotesPanel,
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
                                    Text('Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                    SizedBox(height: 4),
                                    Text(
                                      'Jot things down while you browse.',
                                      style: TextStyle(fontSize: 13, color: PanoramaColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close notes',
                                onPressed: app.closeNotesPanel,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CallbackShortcuts(
                                bindings: {
                                  const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
                                    app.submitNote();
                                    _draft.clear();
                                  },
                                  const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
                                    app.submitNote();
                                    _draft.clear();
                                  },
                                },
                                child: TextField(
                                  controller: _draft,
                                  focusNode: _draftFocus,
                                  minLines: 3,
                                  maxLines: 5,
                                  onChanged: app.setNoteDraft,
                                  decoration: InputDecoration(
                                    hintText: 'Write a note…',
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: app.noteDraft.trim().isEmpty || app.savingNote
                                      ? null
                                      : () async {
                                          await app.submitNote();
                                          _draft.clear();
                                        },
                                  style: FilledButton.styleFrom(backgroundColor: PanoramaColors.blue),
                                  child: Text(app.savingNote ? 'Saving…' : 'Add note'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (app.notesError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(app.notesError, style: const TextStyle(color: PanoramaColors.danger, fontSize: 12)),
                          ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            children: [
                              Text(
                                'Open (${app.openNotes.length})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (app.openNotes.isEmpty)
                                const Text('No open notes.', style: TextStyle(color: PanoramaColors.muted, fontSize: 13))
                              else
                                for (final note in app.openNotes) _noteTile(note),
                              if (app.doneNotes.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                InkWell(
                                  onTap: app.toggleDoneNotes,
                                  child: Row(
                                    children: [
                                      Icon(
                                        app.doneNotesExpanded ? Icons.expand_more : Icons.chevron_right,
                                        size: 18,
                                        color: PanoramaColors.muted,
                                      ),
                                      Text(
                                        'Done (${app.doneNotes.length})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                if (app.doneNotesExpanded) ...[
                                  const SizedBox(height: 8),
                                  for (final note in app.doneNotes) _noteTile(note, done: true),
                                ],
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

  Widget _noteTile(ImprovementNote note, {bool done = false}) {
    final editing = app.editingNoteId == note.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            tooltip: done ? 'Reopen' : 'Mark done',
            onPressed: () => app.toggleNoteStatus(note),
            icon: Icon(
              done ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: done ? PanoramaColors.blue : PanoramaColors.muted,
            ),
          ),
          Expanded(
            child: editing
                ? _editForm(note)
                : InkWell(
                    onTap: () => app.startEditNote(note),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.body,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? PanoramaColors.muted : PanoramaColors.ink,
                            ),
                          ),
                          if (note.folderPath != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                note.folderPath!,
                                style: const TextStyle(fontSize: 11, color: PanoramaColors.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          IconButton(
            tooltip: 'Delete note',
            onPressed: () => _confirmDeleteNote(note),
            icon: const Icon(Icons.delete_outline, size: 18, color: PanoramaColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNote(ImprovementNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete note?'),
          content: Text(
            note.body.trim().isEmpty
                ? 'This note will be permanently deleted.'
                : 'Delete this note?\n\n“${note.body.trim()}”',
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: PanoramaColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await app.deleteNote(note);
    }
  }

  Widget _editForm(ImprovementNote note) {
    final controller = _editControllers.putIfAbsent(
      note.id,
      () => TextEditingController(text: app.editingNoteBody),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): app.cancelEditNote,
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): app.saveEditNote,
            const SingleActivator(LogicalKeyboardKey.enter, control: true): app.saveEditNote,
          },
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: app.setEditingNoteBody,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilledButton(
              onPressed: app.editingNoteBody.trim().isEmpty || app.savingNoteEdit
                  ? null
                  : app.saveEditNote,
              style: FilledButton.styleFrom(backgroundColor: PanoramaColors.blue),
              child: Text(app.savingNoteEdit ? 'Saving…' : 'Save'),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: app.cancelEditNote, child: const Text('Cancel')),
          ],
        ),
      ],
    );
  }
}

class ExplorerContextMenu extends StatelessWidget {
  const ExplorerContextMenu({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pos = controller.contextMenuPosition;
    if (pos == null) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final left = pos.dx.clamp(8.0, size.width - 220);
    final top = pos.dy.clamp(8.0, size.height - 300);
    final entry = controller.contextMenuEntry;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: controller.hideContextMenu,
        onSecondaryTap: controller.hideContextMenu,
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xF2FFFFFF),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
                  child: IntrinsicWidth(
                    child: entry != null ? _entryMenu(entry) : _emptyMenu(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryMenu(FileEntry entry) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _item(Icons.folder_open, 'Open', () {
          final pane = controller.contextMenuPane == PaneId.left
              ? controller.left
              : controller.right;
          controller.openEntryIn(pane, entry);
          controller.hideContextMenu();
        }),
        if (entry.isDirectory)
          _item(Icons.terminal, 'Open Terminal Here', () {
            controller.openTerminalHere();
          }),
        if (!entry.isDirectory) ...[
          _submenuOpenWith(entry),
          _item(Icons.search, 'Show in Finder', () {
            controller.api.reveal(entry.path);
            controller.hideContextMenu();
          }),
          const Divider(height: 1),
        ],
        _item(Icons.copy, 'Copy', () {
          controller.copySelected(false);
          controller.hideContextMenu();
        }),
        _item(Icons.content_cut, 'Cut', () {
          controller.copySelected(true);
          controller.hideContextMenu();
        }),
        _item(Icons.edit, 'Rename', () {
          controller.startRename(entry.path);
          controller.hideContextMenu();
        }),
        const Divider(height: 1),
        _item(Icons.delete_outline, 'Move to Trash', () {
          controller.removeSelected();
          controller.hideContextMenu();
        }, danger: true),
      ],
    );
  }

  Widget _submenuOpenWith(FileEntry entry) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(200, 0),
      onSelected: (value) {
        if (value == '__choose__') {
          controller.chooseAnotherApp(entry.path);
        } else {
          controller.openFileWithApp(entry.path, value);
        }
      },
      itemBuilder: (context) {
        if (controller.openWithLoading && controller.openWithApps.isEmpty) {
          return [
            const PopupMenuItem(enabled: false, child: Text('Looking for apps…')),
          ];
        }
        return [
          for (final app in controller.openWithApps)
            PopupMenuItem(
              value: app.path,
              child: Row(
                children: [
                  Expanded(child: Text(app.name)),
                  if (app.isDefault)
                    const Text('Default', style: TextStyle(fontSize: 11, color: PanoramaColors.muted)),
                ],
              ),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: '__choose__',
            child: Text('Choose another app…'),
          ),
        ];
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.apps, size: 16),
            SizedBox(width: 10),
            Expanded(child: Text('Open with')),
            Icon(Icons.chevron_right, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _emptyMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _item(Icons.create_new_folder_outlined, 'New folder', () {
          controller.createFolder();
          controller.hideContextMenu();
        }),
        _item(Icons.terminal, 'Open Terminal Here', () {
          controller.openTerminalHere();
        }),
        _item(Icons.content_paste, 'Paste', () {
          controller.paste();
          controller.hideContextMenu();
        }),
        const Divider(height: 1),
        _item(Icons.refresh, 'Refresh', () {
          controller.refreshActive();
          controller.hideContextMenu();
        }),
      ],
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {bool danger = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: danger ? PanoramaColors.danger : null),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: danger ? PanoramaColors.danger : null)),
          ],
        ),
      ),
    );
  }
}
