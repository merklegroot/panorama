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
  Set<String> selected = {};
  String search = '';
  SortKey sortKey = SortKey.name;
  bool sortAscending = true;
  Map<SortKey, double> columnWidths = {};
  bool loading = true;
  String error = '';
  int _refreshToken = 0;
  bool _showHidden = false;

  List<FileEntry> get visibleEntries {
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

  void setShowHidden(bool value) {
    if (_showHidden == value) return;
    _showHidden = value;
    if (path.isNotEmpty) refresh();
  }

  void initPath(String initialPath) {
    path = initialPath;
    history = [initialPath];
    historyIndex = 0;
    selected = {};
    search = '';
    error = '';
    notifyListeners();
    refresh();
  }

  void navigate(String targetPath) {
    if (targetPath.isEmpty || targetPath == path) return;
    history = [...history.sublist(0, historyIndex + 1), targetPath];
    historyIndex = history.length - 1;
    path = targetPath;
    selected = {};
    search = '';
    error = '';
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
    selected = {};
    notifyListeners();
    refresh();
  }

  void goForward() {
    if (historyIndex >= history.length - 1) return;
    historyIndex += 1;
    path = history[historyIndex];
    selected = {};
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
    notifyListeners();
  }

  void setSortKey(SortKey key) {
    if (sortKey == key) {
      sortAscending = !sortAscending;
    } else {
      sortKey = key;
      sortAscending = true;
    }
    notifyListeners();
  }

  void setColumnWidth(SortKey key, double width) {
    columnWidths = {...columnWidths, key: width};
    notifyListeners();
  }

  void setSelected(Set<String> value) {
    selected = value;
    notifyListeners();
  }

  void chooseEntry(FileEntry entry, {required bool additive}) {
    if (additive) {
      final next = {...selected};
      if (next.contains(entry.path)) {
        next.remove(entry.path);
      } else {
        next.add(entry.path);
      }
      selected = next;
    } else {
      selected = {entry.path};
    }
    notifyListeners();
  }

  void setError(String message) {
    error = message;
    notifyListeners();
  }

  void selectAll() {
    selected = visibleEntries.map((e) => e.path).toSet();
    notifyListeners();
  }
}
