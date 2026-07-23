import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'models.dart';

class ExplorerService {
  ClipboardState _clipboard = const ClipboardState();
  String? _notesPath;

  Future<List<LocationItem>> getLocations() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final candidates = <(String, String, String)>[
      ('Home', home, 'home'),
      ('Desktop', p.join(home, 'Desktop'), 'monitor'),
      ('Documents', p.join(home, 'Documents'), 'file'),
      ('Downloads', p.join(home, 'Downloads'), 'download'),
      ('Pictures', p.join(home, 'Pictures'), 'image'),
      ('Music', p.join(home, 'Music'), 'music'),
      ('Movies', p.join(home, 'Movies'), 'video'),
      (
        'Trash',
        Platform.isMacOS
            ? p.join(home, '.Trash')
            : p.join(home, '.local', 'share', 'Trash', 'files'),
        'trash',
      ),
    ];

    final locations = <LocationItem>[];
    for (final (name, path, icon) in candidates) {
      if (await Directory(path).exists()) {
        locations.add(LocationItem(name: name, path: path, icon: icon));
      }
    }
    return locations;
  }

  Future<List<FileEntry>> readDirectory(String directoryPath, bool showHidden) async {
    final dir = Directory(directoryPath);
    final entities = await dir.list(followLinks: false).toList();
    final entries = <FileEntry>[];

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (!showHidden && name.startsWith('.')) continue;

      try {
        final stat = await entity.stat();
        final isLink = stat.type == FileSystemEntityType.link;
        final isDirectory = entity is Directory ||
            (isLink && await FileSystemEntity.isDirectory(entity.path));

        entries.add(FileEntry(
          name: name,
          path: entity.path,
          isDirectory: isDirectory,
          isSymbolicLink: isLink,
          size: stat.size,
          modified: stat.modified,
          extension: isDirectory ? '' : p.extension(name).replaceFirst('.', '').toLowerCase(),
        ));
      } catch (_) {
        // Skip unreadable entries.
      }
    }

    return entries;
  }

  Future<void> openPath(String targetPath) async {
    if (Platform.isMacOS) {
      final result = await Process.run('open', [targetPath]);
      if (result.exitCode != 0) {
        throw Exception((result.stderr as String).trim().isEmpty
            ? 'Could not open path.'
            : (result.stderr as String).trim());
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', targetPath]);
      return;
    }
    await Process.run('xdg-open', [targetPath]);
  }

  Future<void> reveal(String targetPath) async {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', targetPath]);
      return;
    }
    if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', targetPath]);
      return;
    }
    await Process.run('xdg-open', [p.dirname(targetPath)]);
  }

  Future<List<OpenWithApp>> listOpenWithApps(String targetPath) async {
    if (!Platform.isMacOS || targetPath.isEmpty) return [];

    const script = r'''
ObjC.import('AppKit');
ObjC.import('Foundation');
function preferred(appPath) {
  return /^(?:\/System)?\/Applications\//.test(appPath)
    || appPath.indexOf('/System/Library/') === 0
    || /\/Users\/[^/]+\/Applications\//.test(appPath);
}
function junk(appPath) {
  return appPath.indexOf('/Caches/') !== -1
    || appPath.indexOf('/Sparkle/') !== -1
    || appPath.indexOf('/Downloads/') !== -1
    || appPath.indexOf('/.Trash/') !== -1;
}
function run(argv) {
  const filePath = argv[0];
  const url = $.NSURL.fileURLWithPath(filePath);
  const workspace = $.NSWorkspace.sharedWorkspace;
  const fm = $.NSFileManager.defaultManager;
  const seen = {};
  const apps = [];

  function add(appURL, isDefault) {
    if (!appURL) return;
    try {
      if (appURL.isNil && appURL.isNil()) return;
    } catch (e) {}
    const appPath = ObjC.unwrap(appURL.path);
    if (!appPath || junk(appPath)) return;
    const key = String(appPath).split('/').pop().toLowerCase();
    if (seen[key]) return;
    if (!isDefault && !preferred(appPath)) return;
    seen[key] = true;
    apps.push({
      name: ObjC.unwrap(fm.displayNameAtPath(appPath)),
      path: appPath,
      isDefault: !!isDefault,
    });
  }

  const defaultApp = workspace.URLForApplicationToOpenURL(url);
  add(defaultApp, true);
  const all = workspace.URLsForApplicationsToOpenURL(url);
  const count = ObjC.unwrap(all.count);
  for (let i = 0; i < count && apps.length < 10; i++) {
    add(all.objectAtIndex(i), false);
  }
  if (apps.length < 3) {
    for (let i = 0; i < count && apps.length < 10; i++) {
      const appURL = all.objectAtIndex(i);
      const appPath = ObjC.unwrap(appURL.path);
      if (!appPath || junk(appPath)) continue;
      const key = appPath.split('/').pop().toLowerCase();
      if (seen[key]) continue;
      seen[key] = true;
      apps.push({
        name: ObjC.unwrap(fm.displayNameAtPath(appPath)),
        path: appPath,
        isDefault: false,
      });
    }
  }
  return JSON.stringify(apps);
}
''';

    try {
      final result = await Process.run(
        'osascript',
        ['-l', 'JavaScript', '-e', script, targetPath],
      ).timeout(const Duration(seconds: 5));
      final stdout = (result.stdout as String).trim();
      final line = stdout.split('\n').firstWhere(
            (entry) => entry.startsWith('['),
            orElse: () => '[]',
          );
      final parsed = jsonDecode(line) as List<dynamic>;
      return parsed
          .map((item) => OpenWithApp(
                name: item['name'] as String,
                path: item['path'] as String,
                isDefault: item['isDefault'] == true,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> openWithApp(String targetPath, String appPath) async {
    if (!Platform.isMacOS) {
      await openPath(targetPath);
      return;
    }
    final result = await Process.run('open', ['-a', appPath, targetPath]);
    if (result.exitCode != 0) {
      throw Exception((result.stderr as String).trim().isEmpty
          ? 'Could not open with that app.'
          : (result.stderr as String).trim());
    }
  }

  Future<bool> openWithChooser(String targetPath) async {
    if (!Platform.isMacOS) {
      await openPath(targetPath);
      return true;
    }
    final app = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Applications', extensions: ['app']),
      ],
      initialDirectory: '/Applications',
      confirmButtonText: 'Open',
    );
    if (app == null) return false;
    await openWithApp(targetPath, app.path);
    return true;
  }

  Future<String?> chooseFolder() async {
    return getDirectoryPath(confirmButtonText: 'Open');
  }

  Future<String> newFolder(String parentPath) async {
    final folderPath = await uniquePath(parentPath, 'New folder');
    await Directory(folderPath).create();
    return folderPath;
  }

  Future<String> renameEntry(String oldPath, String newName) async {
    if (newName.isEmpty || newName.contains('/') || newName.contains('\u0000')) {
      throw Exception('That name is not valid.');
    }
    final destination = p.join(p.dirname(oldPath), newName);
    final type = await FileSystemEntity.type(oldPath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(oldPath).rename(destination);
    } else {
      await File(oldPath).rename(destination);
    }
    return destination;
  }

  Future<void> trash(List<String> paths) async {
    for (final targetPath in paths) {
      if (Platform.isMacOS) {
        final escaped = targetPath.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
        final result = await Process.run('osascript', [
          '-e',
          'tell application "Finder" to delete POSIX file "$escaped"',
        ]);
        if (result.exitCode != 0) {
          // Fallback: move into ~/.Trash
          final home = Platform.environment['HOME']!;
          final trashDir = Directory(p.join(home, '.Trash'));
          final destination = await uniquePath(trashDir.path, p.basename(targetPath));
          final type = await FileSystemEntity.type(targetPath, followLinks: false);
          if (type == FileSystemEntityType.directory) {
            await Directory(targetPath).rename(destination);
          } else {
            await File(targetPath).rename(destination);
          }
        }
      } else if (Platform.isWindows) {
        // Best-effort: move to Recycle via PowerShell
        final escaped = targetPath.replaceAll("'", "''");
        await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('$escaped','OnlyErrorDialogs','SendToRecycleBin')",
        ]);
      } else {
        final home = Platform.environment['HOME'] ?? '.';
        final trashDir = Directory(p.join(home, '.local', 'share', 'Trash', 'files'));
        await trashDir.create(recursive: true);
        final destination = await uniquePath(trashDir.path, p.basename(targetPath));
        final type = await FileSystemEntity.type(targetPath, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await Directory(targetPath).rename(destination);
        } else {
          await File(targetPath).rename(destination);
        }
      }
    }
  }

  Future<ClipboardState> setClipboard(List<String> paths, bool cut) async {
    _clipboard = ClipboardState(paths: List.unmodifiable(paths), cut: cut);
    return _clipboard;
  }

  ClipboardState getClipboard() => _clipboard;

  Future<List<String>> paste(String destinationDirectory) async {
    final pasted = <String>[];
    for (final source in _clipboard.paths) {
      final destination = await uniquePath(destinationDirectory, p.basename(source));
      if (_clipboard.cut) {
        final type = await FileSystemEntity.type(source, followLinks: false);
        if (type == FileSystemEntityType.directory) {
          await Directory(source).rename(destination);
        } else {
          await File(source).rename(destination);
        }
      } else {
        await _copyRecursive(source, destination);
      }
      pasted.add(destination);
    }
    if (_clipboard.cut) _clipboard = const ClipboardState();
    return pasted;
  }

  Future<List<String>> importPaths(List<String> sourcePaths, String destinationDirectory) async {
    final destinationRoot = p.normalize(destinationDirectory);
    final imported = <String>[];
    for (final source in sourcePaths) {
      if (source.isEmpty) continue;
      final resolvedSource = p.normalize(source);
      if (resolvedSource == destinationRoot) continue;
      if (destinationRoot == resolvedSource ||
          destinationRoot.startsWith('$resolvedSource${Platform.pathSeparator}')) {
        throw Exception('Can’t copy “${p.basename(resolvedSource)}” into itself.');
      }
      if (!await FileSystemEntity.type(resolvedSource, followLinks: false)
          .then((t) => t != FileSystemEntityType.notFound)) {
        continue;
      }
      final destination = await uniquePath(destinationRoot, p.basename(resolvedSource));
      await _copyRecursive(resolvedSource, destination);
      imported.add(destination);
    }
    return imported;
  }

  Future<void> _copyRecursive(String source, String destination) async {
    final type = await FileSystemEntity.type(source, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(destination).create(recursive: true);
      await for (final entity in Directory(source).list(followLinks: false)) {
        final name = p.basename(entity.path);
        await _copyRecursive(entity.path, p.join(destination, name));
      }
    } else {
      await File(source).copy(destination);
    }
  }

  Future<String> uniquePath(String directory, String originalName) async {
    final extension = p.extension(originalName);
    final stem = p.basenameWithoutExtension(originalName);
    var candidate = p.join(directory, originalName);
    var number = 1;
    while (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.notFound) {
      final suffix = number == 1 ? ' copy' : ' copy $number';
      candidate = p.join(directory, '$stem$suffix$extension');
      number += 1;
    }
    return candidate;
  }

  String resolveNotesPath() {
    if (_notesPath != null) return _notesPath!;

    Directory? walk(Directory start) {
      var dir = start;
      for (var i = 0; i < 16; i++) {
        final packageJson = File(p.join(dir.path, 'package.json'));
        final flutterApp = Directory(p.join(dir.path, 'flutter_app'));
        final notesDir = Directory(p.join(dir.path, 'notes'));
        final readme = File(p.join(dir.path, 'README.md'));
        if (packageJson.existsSync() ||
            (flutterApp.existsSync() && (notesDir.existsSync() || readme.existsSync())) ||
            File(p.join(dir.path, 'notes', 'improvements.json')).existsSync()) {
          return dir;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return null;
    }

    final fromCwd = walk(Directory.current);
    final fromExe = walk(File(Platform.resolvedExecutable).parent);
    final repo = fromCwd ?? fromExe ?? Directory.current.parent;
    _notesPath = p.join(repo.path, 'notes', 'improvements.json');
    return _notesPath!;
  }

  Future<Map<String, dynamic>> _readNotesFile() async {
    final file = File(resolveNotesPath());
    try {
      final raw = await file.readAsString();
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final notes = parsed['notes'];
      return notes is List ? parsed : {'notes': <dynamic>[]};
    } on PathNotFoundException {
      return {'notes': <dynamic>[]};
    } on FileSystemException {
      return {'notes': <dynamic>[]};
    }
  }

  Future<void> _writeNotesFile(Map<String, dynamic> data) async {
    final target = resolveNotesPath();
    await Directory(p.dirname(target)).create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    await File(target).writeAsString('${encoder.convert(data)}\n');
  }

  Future<List<ImprovementNote>> listNotes() async {
    final data = await _readNotesFile();
    final notes = data['notes'] as List<dynamic>? ?? [];
    return notes
        .whereType<Map>()
        .map((item) => ImprovementNote.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ImprovementNote> addNote(String body, {String? folderPath}) async {
    final text = body.trim();
    if (text.isEmpty) throw Exception('Note text is required.');
    final data = await _readNotesFile();
    final notes = List<dynamic>.from(data['notes'] as List? ?? []);
    final note = ImprovementNote(
      id: 'note_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}_${Random().nextInt(1 << 24).toRadixString(36)}',
      body: text,
      status: NoteStatus.open,
      createdAt: DateTime.now().toUtc(),
      folderPath: folderPath,
    );
    notes.insert(0, note.toJson());
    data['notes'] = notes;
    await _writeNotesFile(data);
    return note;
  }

  Future<ImprovementNote> updateNote(String id, String body) async {
    final text = body.trim();
    if (text.isEmpty) throw Exception('Note text is required.');
    final data = await _readNotesFile();
    final notes = List<Map<String, dynamic>>.from(
      (data['notes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final index = notes.indexWhere((item) => item['id'] == id);
    if (index < 0) throw Exception('Note not found.');
    notes[index]['body'] = text;
    data['notes'] = notes;
    await _writeNotesFile(data);
    return ImprovementNote.fromJson(notes[index]);
  }

  Future<ImprovementNote> setNoteStatus(String id, NoteStatus status) async {
    final data = await _readNotesFile();
    final notes = List<Map<String, dynamic>>.from(
      (data['notes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final index = notes.indexWhere((item) => item['id'] == id);
    if (index < 0) throw Exception('Note not found.');
    notes[index]['status'] = status == NoteStatus.open ? 'open' : 'done';
    notes[index]['completedAt'] =
        status == NoteStatus.done ? DateTime.now().toUtc().toIso8601String() : null;
    data['notes'] = notes;
    await _writeNotesFile(data);
    return ImprovementNote.fromJson(notes[index]);
  }
}

/// Image extensions that can be previewed via Image.file.
const imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
};

String formatSize(int bytes, bool isDirectory) {
  if (isDirectory) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  return '${size < 10 ? size.toStringAsFixed(1) : size.round()} ${units[unit]}';
}

String formatModified(DateTime date) {
  final local = date.toLocal();
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, ${local.year}, $hour:$minute $period';
}

bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
