import 'dart:async';

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
  bool previewOpen = true;
  double previewWidth = 280;
  PaneId activePaneId = PaneId.left;
  ViewMode view = ViewMode.list;
  IconSize iconSize = IconSize.medium;
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
  bool _dualPaneUsedThisSession = false;
  bool machineInfoOpen = false;
  MachineInfoPage machineInfoPage = MachineInfoPage.overview;
  MachineInfo? machineInfo;
  bool machineInfoLoading = false;
  String machineInfoError = '';
  ProcessorInfo? processorInfo;
  bool processorInfoLoading = false;
  String processorInfoError = '';
  DiskUsage? diskUsage;
  String _diskUsageForPath = '';
  StreamSubscription<void>? _volumeWatch;
  bool terminalOpen = false;
  bool terminalCollapsed = false;
  String terminalWorkingDirectory = '';
  int terminalSession = 0;
  int terminalCwdSync = 0;
  String statusFlash = '';
  bool statusFlashError = false;
  int _statusFlashToken = 0;

  FolderPaneController get activePane =>
      activePaneId == PaneId.left ? left : right;

  FolderPaneController get otherPane =>
      activePaneId == PaneId.left ? right : left;

  List<FileEntry> get selectedEntries => activePane.entries
      .where((e) => activePane.selected.contains(e.path))
      .toList();

  List<ImprovementNote> get openNotes =>
      notes.where((n) => n.status == NoteStatus.open).toList();

  List<ImprovementNote> get doneNotes =>
      notes.where((n) => n.status == NoteStatus.done).toList();

  Future<void> init() async {
    left.addListener(_onPaneChanged);
    right.addListener(_onPaneChanged);
    try {
      locations = await api.getLocations();
      final initial =
          locations
              .where((l) => l.name == 'Home')
              .map((l) => l.path)
              .firstOrNull ??
          (locations.isNotEmpty ? locations.first.path : '/');
      left.initPath(initial);
      right.initPath(initial);
      await loadNotes();
    } catch (reason) {
      left.setError(reason.toString());
    }
    notifyListeners();
  }

  void _onPaneChanged() {
    _syncTerminalToMainPane();
    notifyListeners();
    refreshDiskUsage();
  }

  /// Keep the embedded terminal cwd aligned with the main (left) pane only.
  void _syncTerminalToMainPane() {
    if (!terminalOpen) return;
    final dir = left.path;
    if (dir.isEmpty || dir == terminalWorkingDirectory) return;
    terminalWorkingDirectory = dir;
    terminalCwdSync += 1;
  }

  /// Called when the shell's cwd changes so the main pane can follow.
  void syncMainPaneFromTerminal(String directory) {
    if (directory.isEmpty || directory == left.path) return;
    terminalWorkingDirectory = directory;
    left.navigate(directory);
  }

  void toggleTerminalCollapsed() {
    if (!terminalOpen) return;
    terminalCollapsed = !terminalCollapsed;
    notifyListeners();
  }

  void setTerminalCollapsed(bool value) {
    if (!terminalOpen || terminalCollapsed == value) return;
    terminalCollapsed = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopVolumeWatch();
    left.removeListener(_onPaneChanged);
    right.removeListener(_onPaneChanged);
    left.dispose();
    right.dispose();
    super.dispose();
  }

  void setActivePane(PaneId id) {
    if (activePaneId == id) return;
    activePaneId = id;
    notifyListeners();
    refreshDiskUsage();
  }

  void setSidebarWidth(double width) {
    sidebarWidth = width.clamp(150, 420);
    notifyListeners();
  }

  void setView(ViewMode mode) {
    view = mode;
    notifyListeners();
  }

  void setIconSize(IconSize size) {
    iconSize = size;
    view = ViewMode.grid;
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
      // Seed the right pane from the left only the first time dual pane is
      // enabled this session; later toggles keep the right pane's path.
      if (!_dualPaneUsedThisSession && left.path.isNotEmpty) {
        right.initPath(left.path);
      }
      _dualPaneUsedThisSession = true;
      activePaneId = PaneId.left;
      dualPane = true;
    } else {
      activePaneId = PaneId.left;
      dualPane = false;
    }
    notifyListeners();
  }

  void togglePreview() {
    previewOpen = !previewOpen;
    notifyListeners();
  }

  void setPreviewWidth(double width) {
    previewWidth = width.clamp(200.0, 480.0);
    notifyListeners();
  }

  Future<void> openNewWindow() async {
    try {
      await api.openNewWindow();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> openTerminalHere() async {
    final pane = contextMenuPane;
    final entry = contextMenuEntry;
    hideContextMenu();
    // Follow the main pane: if the folder was opened from the left pane
    // context menu, navigate there first so terminal sync stays consistent.
    if (pane == PaneId.left && entry != null && entry.isDirectory) {
      left.navigate(entry.path);
    }
    openTerminalPanel(directory: left.path);
  }

  void openTerminalPanel({String? directory, bool restart = false}) {
    final dir = (directory == null || directory.isEmpty)
        ? left.path
        : directory;
    if (terminalOpen && terminalWorkingDirectory == dir && !restart) {
      if (terminalCollapsed) {
        terminalCollapsed = false;
        notifyListeners();
      }
      return;
    }
    final needsNewSession =
        restart || !terminalOpen || terminalWorkingDirectory != dir;
    final opening = !terminalOpen;
    terminalWorkingDirectory = dir;
    terminalOpen = true;
    if (opening) terminalCollapsed = false;
    if (needsNewSession) {
      terminalSession += 1;
    }
    notifyListeners();
  }

  void closeTerminalPanel() {
    if (!terminalOpen) return;
    terminalOpen = false;
    notifyListeners();
  }

  void toggleTerminalPanel() {
    if (terminalOpen) {
      closeTerminalPanel();
    } else {
      openTerminalPanel(directory: left.path);
    }
  }

  void restartTerminalPanel() {
    openTerminalPanel(directory: left.path, restart: true);
  }

  Future<void> refreshDiskUsage() async {
    final path = activePane.path;
    if (path.isEmpty || path == _diskUsageForPath) return;
    _diskUsageForPath = path;
    try {
      final usage = await api.getDiskUsage(path);
      if (_diskUsageForPath != path) return;
      diskUsage = usage;
    } catch (_) {
      if (_diskUsageForPath != path) return;
      diskUsage = null;
    }
    notifyListeners();
  }

  Future<void> openMachineInfo() async {
    closeNotesPanel();
    machineInfoOpen = true;
    machineInfoPage = MachineInfoPage.overview;
    machineInfoLoading = true;
    machineInfoError = '';
    processorInfo = null;
    processorInfoError = '';
    processorInfoLoading = false;
    notifyListeners();
    try {
      machineInfo = await api.getMachineInfo();
      _startVolumeWatch();
    } catch (reason) {
      machineInfoError = reason.toString();
      _stopVolumeWatch();
    } finally {
      machineInfoLoading = false;
      notifyListeners();
    }
  }

  void closeMachineInfo() {
    if (!machineInfoOpen) return;
    _stopVolumeWatch();
    machineInfoOpen = false;
    machineInfoPage = MachineInfoPage.overview;
    processorInfo = null;
    processorInfoError = '';
    processorInfoLoading = false;
    notifyListeners();
  }

  void toggleMachineInfo() {
    if (machineInfoOpen) {
      closeMachineInfo();
    } else {
      openMachineInfo();
    }
  }

  void showMachineInfoOverview() {
    if (!machineInfoOpen) return;
    machineInfoPage = MachineInfoPage.overview;
    notifyListeners();
  }

  Future<void> showProcessorInfo() async {
    if (!machineInfoOpen) return;
    machineInfoPage = MachineInfoPage.processor;
    if (processorInfo != null && processorInfoError.isEmpty) {
      notifyListeners();
      return;
    }
    processorInfoLoading = true;
    processorInfoError = '';
    notifyListeners();
    try {
      processorInfo = await api.getProcessorInfo();
    } catch (reason) {
      processorInfoError = reason.toString();
    } finally {
      processorInfoLoading = false;
      notifyListeners();
    }
  }

  void _startVolumeWatch() {
    _stopVolumeWatch();
    _volumeWatch = api.watchVolumeChanges().listen((_) {
      unawaited(_refreshMachineInfoDisks());
    });
  }

  void _stopVolumeWatch() {
    _volumeWatch?.cancel();
    _volumeWatch = null;
  }

  Future<void> _refreshMachineInfoDisks() async {
    final current = machineInfo;
    if (!machineInfoOpen || current == null) return;
    try {
      final disks = await api.getDiskVolumes();
      if (!machineInfoOpen || machineInfo == null) return;
      final previous = machineInfo!.disks.map((d) => d.mountPoint).toSet();
      final next = disks.map((d) => d.mountPoint).toSet();
      if (previous.length == next.length && previous.containsAll(next)) {
        return;
      }
      machineInfo = MachineInfo(
        hostname: current.hostname,
        osName: current.osName,
        osVersion: current.osVersion,
        arch: current.arch,
        cpu: current.cpu,
        memoryBytes: current.memoryBytes,
        username: current.username,
        disks: disks,
      );
      notifyListeners();
    } catch (_) {
      // Keep the last successful snapshot if a refresh fails.
    }
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

  void flashStatus(String message, {bool error = false, Duration? duration}) {
    statusFlash = message;
    statusFlashError = error;
    final token = ++_statusFlashToken;
    notifyListeners();
    Future<void>.delayed(duration ?? Duration(seconds: error ? 5 : 2), () {
      if (_statusFlashToken != token) return;
      statusFlash = '';
      statusFlashError = false;
      notifyListeners();
    });
  }

  void flashError(Object error, [StackTrace? stack]) {
    debugPrint('panorama error: $error');
    if (stack != null) {
      debugPrint('$stack');
    }
    flashStatus(error.toString(), error: true);
  }

  Future<void> removeSelected() async {
    if (activePane.selected.isEmpty) return;
    try {
      if (api.isInTrash(activePane.path)) {
        await api.deletePermanently(activePane.selected.toList());
      } else {
        await api.trash(activePane.selected.toList());
      }
      activePane.setSelected({});
      refreshAll();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  bool get activePaneInTrash => api.isInTrash(activePane.path);

  Future<void> restoreSelected() async {
    if (activePane.selected.isEmpty) return;
    try {
      await api.restoreFromTrash(activePane.selected.toList());
      activePane.setSelected({});
      refreshAll();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  Future<void> deleteSelectedPermanently() async {
    if (activePane.selected.isEmpty) return;
    try {
      await api.deletePermanently(activePane.selected.toList());
      activePane.setSelected({});
      refreshAll();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  Future<void> emptyTrash() async {
    try {
      await api.emptyTrash();
      activePane.setSelected({});
      refreshAll();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  Future<void> openNativeTrash() async {
    try {
      await api.openNativeTrash();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  Future<void> openFullDiskAccessSettings() async {
    try {
      await api.openFullDiskAccessSettings();
    } catch (reason, stack) {
      flashError(reason, stack);
    }
  }

  Future<void> copySelected(bool cut) async {
    if (activePane.selected.isEmpty) return;
    await api.setClipboard(activePane.selected.toList(), cut);
  }

  Future<void> copyFullPath(String path) async {
    await Clipboard.setData(ClipboardData(text: path));
    flashStatus('Path copied');
  }

  Future<void> paste() async {
    try {
      await api.paste(activePane.path);
      refreshAll();
    } catch (reason) {
      activePane.setError(reason.toString());
    }
  }

  Future<void> importExternalFiles(
    FolderPaneController pane,
    List<String> paths,
  ) async {
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
    closeMachineInfo();
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

  Future<void> deleteNote(ImprovementNote note) async {
    try {
      if (editingNoteId == note.id) {
        cancelEditNote();
      }
      await api.deleteNote(note.id);
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
    if (editingNoteId == null ||
        editingNoteBody.trim().isEmpty ||
        savingNoteEdit) {
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

    final meta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (contextMenuPosition != null) {
        hideContextMenu();
        return KeyEventResult.handled;
      }
      if (machineInfoOpen) {
        if (machineInfoPage != MachineInfoPage.overview) {
          showMachineInfoOverview();
        } else {
          closeMachineInfo();
        }
        return KeyEventResult.handled;
      }
      if (notesOpen) {
        if (editingNoteId != null) {
          cancelEditNote();
        } else {
          closeNotesPanel();
        }
        return KeyEventResult.handled;
      }
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
      if (activePaneInTrash) {
        deleteSelectedPermanently();
      } else {
        removeSelected();
      }
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
    if (meta && event.logicalKey == LogicalKeyboardKey.keyN) {
      openNewWindow();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        selectedEntries.length == 1) {
      openEntryIn(activePane, selectedEntries.first);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
