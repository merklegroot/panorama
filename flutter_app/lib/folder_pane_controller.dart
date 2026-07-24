import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'explorer_service.dart';
import 'models.dart';

enum SortKey { name, modified, type, size }

enum ViewMode { list, grid }

enum PaneId { left, right }

class FolderPaneController extends ChangeNotifier {
  FolderPaneController(this._api);

  final ExplorerService _api;

  String path = '';
  List<FileEntry> entries = [];
  List<String> history = [];
  int historyIndex = -1;
  String? selectionAnchorPath;
  String search = '';
  SortKey sortKey = SortKey.name;
  bool sortAscending = true;
  Map<SortKey, double> columnWidths = {};
  bool loading = true;
  String error = '';
  int _refreshToken = 0;
  bool _showHidden = false;
  List<FileEntry>? _visibleCache;

  /// Selection is separate from content so row highlights can update without
  /// rebuilding the file list.
  final ValueNotifier<Set<String>> selection = ValueNotifier<Set<String>>(const {});
  final Map<String, Set<VoidCallback>> _selectionPathListeners = {};

  Set<String> get selected => selection.value;

  void addSelectionListener(String path, VoidCallback listener) {
    (_selectionPathListeners[path] ??= <VoidCallback>{}).add(listener);
  }

  void removeSelectionListener(String path, VoidCallback listener) {
    final listeners = _selectionPathListeners[path];
    if (listeners == null) return;
    listeners.remove(listener);
    if (listeners.isEmpty) _selectionPathListeners.remove(path);
  }

  List<FileEntry> get visibleEntries => _visibleCache ??= _computeVisible();

  List<FileEntry> _computeVisible() {
    final query = search.toLowerCase();
    final filtered = entries.where((entry) => entry.name.toLowerCase().contains(query)).toList()
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        var result = 0;
        switch (sortKey) {
          case SortKey.name:
            result = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          case SortKey.modified:
            result = a.modified.compareTo(b.modified);
          case SortKey.type:
            result = a.fileType.compareTo(b.fileType);
          case SortKey.size:
            result = a.size.compareTo(b.size);
        }
        return sortAscending ? result : -result;
      });
    return filtered;
  }

  void _invalidateVisible() {
    _visibleCache = null;
  }

  void _setSelection(Set<String> next, {String? anchor, bool clearAnchor = false}) {
    if (clearAnchor) {
      selectionAnchorPath = null;
    } else if (anchor != null) {
      selectionAnchorPath = anchor;
    }
    final previous = selection.value;
    if (setEquals(previous, next)) return;

    final frozen = Set<String>.unmodifiable(next);
    selection.value = frozen;

    // Only rows whose membership flipped need to rebuild.
    for (final path in previous) {
      if (!frozen.contains(path)) {
        final listeners = _selectionPathListeners[path];
        if (listeners != null) {
          for (final listener in List<VoidCallback>.from(listeners)) {
            listener();
          }
        }
      }
    }
    for (final path in frozen) {
      if (!previous.contains(path)) {
        final listeners = _selectionPathListeners[path];
        if (listeners != null) {
          for (final listener in List<VoidCallback>.from(listeners)) {
            listener();
          }
        }
      }
    }
  }

  void setShowHidden(bool value) {
    if (_showHidden == value) return;
    _showHidden = value;
    if (path.isNotEmpty) refresh();
  }

  void initPath(String initialPath) {
    path = initialPath;
    history = [initialPath];
    historyIndex = 0;
    _setSelection(const {}, clearAnchor: true);
    search = '';
    error = '';
    _invalidateVisible();
    notifyListeners();
    refresh();
  }

  void navigate(String targetPath) {
    if (targetPath.isEmpty || targetPath == path) return;
    history = [...history.sublist(0, historyIndex + 1), targetPath];
    historyIndex = history.length - 1;
    path = targetPath;
    _setSelection(const {}, clearAnchor: true);
    search = '';
    error = '';
    _invalidateVisible();
    notifyListeners();
    refresh();
  }

  void refresh() {
    _refreshToken += 1;
    _load(_refreshToken);
  }

  Future<void> _load(int token) async {
    if (path.isEmpty) return;
    loading = true;
    error = '';
    notifyListeners();
    try {
      final items = await _api.readDirectory(path, _showHidden);
      if (token != _refreshToken) return;
      entries = items;
      _invalidateVisible();
    } catch (reason) {
      if (token != _refreshToken) return;
      error = reason.toString();
    } finally {
      if (token == _refreshToken) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void goBack() {
    if (historyIndex <= 0) return;
    historyIndex -= 1;
    path = history[historyIndex];
    _setSelection(const {}, clearAnchor: true);
    _invalidateVisible();
    notifyListeners();
    refresh();
  }

  void goForward() {
    if (historyIndex >= history.length - 1) return;
    historyIndex += 1;
    path = history[historyIndex];
    _setSelection(const {}, clearAnchor: true);
    _invalidateVisible();
    notifyListeners();
    refresh();
  }

  void goUp() {
    if (path.isEmpty || path == '/' || (path.length == 3 && path[1] == ':')) return;
    final parent = path.replaceAll('\\', '/');
    final index = parent.lastIndexOf('/');
    if (index <= 0) {
      navigate('/');
      return;
    }
    navigate(parent.substring(0, index).isEmpty ? '/' : parent.substring(0, index));
  }

  void setSearch(String value) {
    search = value;
    _invalidateVisible();
    notifyListeners();
  }

  void setSortKey(SortKey key) {
    if (sortKey == key) {
      sortAscending = !sortAscending;
    } else {
      sortKey = key;
      sortAscending = true;
    }
    _invalidateVisible();
    notifyListeners();
  }

  void setColumnWidth(SortKey key, double width) {
    columnWidths = {...columnWidths, key: width};
    notifyListeners();
  }

  void setSelected(Set<String> value) {
    _setSelection(
      Set<String>.unmodifiable(value),
      clearAnchor: value.isEmpty,
      anchor: value.length == 1 ? value.first : null,
    );
  }

  void chooseEntry(
    FileEntry entry, {
    required bool additive,
    bool range = false,
  }) {
    // Fast path: plain click — no need to scan the visible list.
    if (!range && !additive) {
      _setSelection({entry.path}, anchor: entry.path);
      return;
    }

    if (additive && !range) {
      final next = {...selection.value};
      if (next.contains(entry.path)) {
        next.remove(entry.path);
      } else {
        next.add(entry.path);
      }
      _setSelection(next, anchor: entry.path);
      return;
    }

    final list = visibleEntries;
    final index = list.indexWhere((e) => e.path == entry.path);

    if (range && selectionAnchorPath != null && index >= 0) {
      final anchor = list.indexWhere((e) => e.path == selectionAnchorPath);
      if (anchor >= 0) {
        final start = math.min(anchor, index);
        final end = math.max(anchor, index);
        _setSelection({
          for (var i = start; i <= end; i++) list[i].path,
        });
        return;
      }
    }

    _setSelection({entry.path}, anchor: entry.path);
  }

  void setError(String message) {
    error = message;
    notifyListeners();
  }

  void selectAll() {
    final list = visibleEntries;
    _setSelection(
      list.map((e) => e.path).toSet(),
      anchor: list.isEmpty ? null : list.first.path,
      clearAnchor: list.isEmpty,
    );
  }

  @override
  void dispose() {
    selection.dispose();
    super.dispose();
  }
}
