import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'explorer_service.dart';
import 'folder_pane_controller.dart';
import 'models.dart';

class AppController extends ChangeNotifier {
  AppController(this.api)
      : left = FolderPaneController(api),
        right = FolderPaneController(api);

  final ExplorerService api;
  final FolderPaneController left;
  final FolderPaneController right;

  List<LocationItem> locations = [];
  bool dualPane = false;
  PaneId activePaneId = PaneId.left;
  ViewMode view = ViewMode.list;
  double sidebarWidth = 180;
  bool showHidden = false;
  String? renaming;
  bool notesOpen = false;
  List<ImprovementNote> notes = [];
  String noteDraft = '';
  String notesError = '';
  bool savingNote = false;
  bool doneNotesExpanded = false;
  String? editingNoteId;
  String editingNoteBody = '';
  bool savingNoteEdit = false;
  int editAddressRequest = 0;
  Offset? contextMenuPosition;
  FileEntry? contextMenuEntry;
  PaneId contextMenuPane = PaneId.left;
  List<OpenWithApp> openWithApps = [];
  bool openWithLoading = false;

  FolderPaneController get activePane =>
      activePaneId == PaneId.left ? left : right;

  FolderPaneController get otherPane =>
      activePaneId == PaneId.left ? right : left;

  List<FileEntry> get selectedEntries =>
      activePane.entries.where((e) => activePane.selected.contains(e.path)).toList();

  List<ImprovementNote> get openNotes =>
      notes.where((n) => n.status == NoteStatus.open).toList();

  List<ImprovementNote> get doneNotes =>
      notes.where((n) => n.status == NoteStatus.done).toList();

  Future<void> init() async {
    left.addListener(notifyListeners);
    right.addListener(notifyListeners);
    try {
      locations = await api.getLocations();
      final initial =
          locations.where((l) => l.name == 'Home').map((l) => l.path).firstOrNull ??
              (locations.isNotEmpty ? locations.first.path : '/');
      left.initPath(initial);
      right.initPath(initial);
      await loadNotes();
    } catch (reason) {
      left.setError(reason.toString());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    left.removeListener(notifyListeners);
    right.removeListener(notifyListeners);
    left.dispose();
    right.dispose();
    super.dispose();
  }

  void setActivePane(PaneId id) {
    if (activePaneId == id) return;
    activePaneId = id;
    notifyListeners();
  }

  void setSidebarWidth(double width) {
    sidebarWidth = width.clamp(150, 420);
    notifyListeners();
  }

  void setView(ViewMode mode) {
    view = mode;
    notifyListeners();
  }

  void toggleShowHidden() {
    showHidden = !showHidden;
    left.setShowHidden(showHidden);
    right.setShowHidden(showHidden);
    notifyListeners();
  }

  void toggleDualPane() {
    if (!dualPane) {
      if (left.path.isNotEmpty) right.initPath(left.path);
      activePaneId = PaneId.left;
      dualPane = true;
    } else {
      activePaneId = PaneId.left;
      dualPane = false;
    }
    notifyListeners();
  }

  void refreshActive() {
    activePane.refresh();
    if (dualPane && otherPane.path == activePane.path) otherPane.refresh();
  }

  void refreshAll() {
    left.refresh();
    if (dualPane) right.refresh();
  }

  Future<void> openEntryIn(FolderPaneController pane, FileEntry entry) async {
    if (entry.isDirectory) {
      pane.navigate(entry.path);
    } else {
      try {
        await api.openPath(entry.path);
      } catch (reason) {
        pane.setError(reason.toString());
      }
    }
  }

  Future<void> createFolder() async {
    try {
      final newPath = await api.newFolder(activePane.path);
      refreshAll();
      activePane.setSelected({newPath});
      renaming = newPath;
      notifyListeners();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> submitRename(FileEntry entry, String newName) async {
    renaming = null;
    notifyListeners();
    if (newName.trim().isEmpty || newName == entry.name) return;
    try {
      await api.renameEntry(entry.path, newName.trim());
      refreshAll();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  void cancelRename() {
    renaming = null;
    notifyListeners();
  }

  void startRename(String path) {
    renaming = path;
    notifyListeners();
  }

  Future<void> removeSelected() async {
    if (activePane.selected.isEmpty) return;
    try {
      await api.trash(activePane.selected.toList());
      activePane.setSelected({});
      refreshAll();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> copySelected(bool cut) async {
    if (activePane.selected.isEmpty) return;
    await api.setClipboard(activePane.selected.toList(), cut);
  }

  Future<void> paste() async {
    try {
      await api.paste(activePane.path);
      refreshAll();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> importExternalFiles(FolderPaneController pane, List<String> paths) async {
    if (pane.path.isEmpty || paths.isEmpty) return;
    try {
      final imported = await api.importPaths(paths, pane.path);
      refreshAll();
      if (imported.isNotEmpty) pane.setSelected(imported.toSet());
    } catch (reason) {
      pane.setError(reason.toString());
    }
  }

  Future<void> loadNotes() async {
    try {
      notes = await api.listNotes();
      notesError = '';
    } catch (reason) {
      notesError = reason.toString();
    }
    notifyListeners();
  }

  void openNotesPanel() {
    doneNotesExpanded = false;
    notesOpen = true;
    notifyListeners();
    loadNotes();
  }

  void closeNotesPanel() {
    notesOpen = false;
    editingNoteId = null;
    editingNoteBody = '';
    notifyListeners();
  }

  void setNoteDraft(String value) {
    noteDraft = value;
    notifyListeners();
  }

  Future<void> submitNote() async {
    if (noteDraft.trim().isEmpty || savingNote) return;
    savingNote = true;
    notifyListeners();
    try {
      await api.addNote(noteDraft);
      noteDraft = '';
      await loadNotes();
    } catch (reason) {
      notesError = reason.toString();
    } finally {
      savingNote = false;
      notifyListeners();
    }
  }

  Future<void> toggleNoteStatus(ImprovementNote note) async {
    try {
      await api.setNoteStatus(
        note.id,
        note.status == NoteStatus.open ? NoteStatus.done : NoteStatus.open,
      );
      await loadNotes();
    } catch (reason) {
      notesError = reason.toString();
      notifyListeners();
    }
  }

  void startEditNote(ImprovementNote note) {
    editingNoteId = note.id;
    editingNoteBody = note.body;
    notesError = '';
    notifyListeners();
  }

  void cancelEditNote() {
    editingNoteId = null;
    editingNoteBody = '';
    notifyListeners();
  }

  void setEditingNoteBody(String value) {
    editingNoteBody = value;
    notifyListeners();
  }

  Future<void> saveEditNote() async {
    if (editingNoteId == null || editingNoteBody.trim().isEmpty || savingNoteEdit) {
      return;
    }
    savingNoteEdit = true;
    notifyListeners();
    try {
      await api.updateNote(editingNoteId!, editingNoteBody);
      editingNoteId = null;
      editingNoteBody = '';
      await loadNotes();
    } catch (reason) {
      notesError = reason.toString();
    } finally {
      savingNoteEdit = false;
      notifyListeners();
    }
  }

  void toggleDoneNotes() {
    doneNotesExpanded = !doneNotesExpanded;
    notifyListeners();
  }

  void requestEditAddress() {
    editAddressRequest += 1;
    notifyListeners();
  }

  Future<void> showContextMenu({
    required Offset position,
    required PaneId paneId,
    FileEntry? entry,
  }) async {
    setActivePane(paneId);
    final target = paneId == PaneId.left ? left : right;
    if (entry != null && !target.selected.contains(entry.path)) {
      target.setSelected({entry.path});
    }
    contextMenuPosition = position;
    contextMenuEntry = entry;
    contextMenuPane = paneId;
    openWithApps = [];
    openWithLoading = entry != null && !entry.isDirectory;
    notifyListeners();

    if (entry != null && !entry.isDirectory) {
      try {
        openWithApps = await api.listOpenWithApps(entry.path);
      } catch (_) {
        openWithApps = [];
      } finally {
        openWithLoading = false;
        notifyListeners();
      }
    }
  }

  void hideContextMenu() {
    if (contextMenuPosition == null) return;
    contextMenuPosition = null;
    contextMenuEntry = null;
    openWithApps = [];
    openWithLoading = false;
    notifyListeners();
  }

  Future<void> openFileWithApp(String filePath, String appPath) async {
    hideContextMenu();
    try {
      await api.openWithApp(filePath, appPath);
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> chooseAnotherApp(String filePath) async {
    hideContextMenu();
    try {
      await api.openWithChooser(filePath);
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final meta = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape && notesOpen) {
      if (editingNoteId != null) {
        cancelEditNote();
      } else {
        closeNotesPanel();
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.tab && dualPane) {
      setActivePane(activePaneId == PaneId.left ? PaneId.right : PaneId.left);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace && !meta) {
      activePane.goBack();
      return KeyEventResult.handled;
    }

    if ((event.logicalKey == LogicalKeyboardKey.delete ||
            (meta && event.logicalKey == LogicalKeyboardKey.backspace)) &&
        activePane.selected.isNotEmpty) {
      removeSelected();
      return KeyEventResult.handled;
    }

    if (meta && event.logicalKey == LogicalKeyboardKey.keyC) {
      copySelected(false);
      return KeyEventResult.handled;
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyX) {
      copySelected(true);
      return KeyEventResult.handled;
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyV) {
      paste();
      return KeyEventResult.handled;
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyL) {
      requestEditAddress();
      return KeyEventResult.handled;
    }
    if (meta && event.logicalKey == LogicalKeyboardKey.keyA) {
      activePane.selectAll();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter && selectedEntries.length == 1) {
      openEntryIn(activePane, selectedEntries.first);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
