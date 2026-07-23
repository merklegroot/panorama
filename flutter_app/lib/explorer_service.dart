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
    final trashPath = Platform.isMacOS
        ? p.join(home, '.Trash')
        : Platform.isWindows
            ? null
            : p.join(home, '.local', 'share', 'Trash', 'files');
    final candidates = <(String, String, String)>[
      ('Home', home, 'home'),
      ('Desktop', p.join(home, 'Desktop'), 'monitor'),
      ('Documents', p.join(home, 'Documents'), 'file'),
      ('Downloads', p.join(home, 'Downloads'), 'download'),
      ('Pictures', p.join(home, 'Pictures'), 'image'),
      ('Music', p.join(home, 'Music'), 'music'),
      ('Movies', p.join(home, 'Movies'), 'video'),
      if (trashPath != null) ('Trash', trashPath, 'trash'),
    ];

    final locations = <LocationItem>[];
    for (final (name, path, icon) in candidates) {
      // Trash is always listed on macOS even when Directory.exists is blocked
      // by TCC; browsing uses Finder (see readDirectory).
      if (icon == 'trash' && Platform.isMacOS) {
        locations.add(LocationItem(name: name, path: path, icon: icon));
        continue;
      }
      if (await Directory(path).exists()) {
        locations.add(LocationItem(name: name, path: path, icon: icon));
      }
    }
    return locations;
  }

  bool isTrashPath(String directoryPath) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) return false;
    final normalized = p.normalize(directoryPath);
    if (Platform.isMacOS) {
      return normalized == p.normalize(p.join(home, '.Trash'));
    }
    if (Platform.isWindows) return false;
    return normalized ==
        p.normalize(p.join(home, '.local', 'share', 'Trash', 'files'));
  }

  Future<List<FileEntry>> readDirectory(String directoryPath, bool showHidden) async {
    if (Platform.isMacOS && isTrashPath(directoryPath)) {
      return _readMacTrash(showHidden);
    }

    final dir = Directory(directoryPath);
    try {
      final entities = await dir.list(followLinks: false).toList();
      return _entriesFromEntities(entities, showHidden);
    } on PathAccessException {
      if (isTrashPath(directoryPath)) {
        // Non-macOS fallback path shouldn't hit this often; rethrow with context.
        throw Exception(
          'Can’t read Trash. Grant Full Disk Access to Panorama in System Settings.',
        );
      }
      rethrow;
    }
  }

  Future<List<FileEntry>> _entriesFromEntities(
    List<FileSystemEntity> entities,
    bool showHidden,
  ) async {
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

  /// List macOS Trash via Finder. Direct Directory.list on ~/.Trash is blocked
  /// by TCC even for unsandboxed apps without Full Disk Access.
  Future<List<FileEntry>> _readMacTrash(bool showHidden) async {
    final home = Platform.environment['HOME'] ?? '';
    final script = '''
function run() {
  const finder = Application("Finder");
  const items = finder.trash.items();
  const home = ${jsonEncode(home)};
  const out = [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    try {
      const name = item.name();
      const cls = String(item.class());
      const isDirectory = cls === "folder" || cls === "package" || cls === "disk";
      let path = "";
      try {
        const url = String(item.url());
        path = decodeURIComponent(url.replace(/^file:\\/\\//, ""));
      } catch (e) {
        path = home + "/.Trash/" + name;
      }
      let size = 0;
      try {
        const s = item.size();
        if (typeof s === "number") size = s;
      } catch (e) {}
      let modified = new Date().toISOString();
      try {
        modified = item.modificationDate().toISOString();
      } catch (e) {}
      out.push({
        name: name,
        path: path,
        isDirectory: isDirectory,
        size: size,
        modified: modified,
      });
    } catch (e) {}
  }
  return JSON.stringify(out);
}
''';

    final result = await Process.run(
      'osascript',
      ['-l', 'JavaScript', '-e', script],
    ).timeout(const Duration(seconds: 10));

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      throw Exception(
        err.isEmpty
            ? 'Can’t open Trash. Allow Panorama to control Finder if prompted.'
            : err,
      );
    }

    final stdout = (result.stdout as String).trim();
    final line = stdout.split('\n').lastWhere(
          (entry) => entry.startsWith('['),
          orElse: () => '[]',
        );

    final parsed = jsonDecode(line) as List<dynamic>;
    final entries = <FileEntry>[];
    for (final item in parsed) {
      if (item is! Map) continue;
      final name = item['name'] as String? ?? '';
      if (name.isEmpty) continue;
      if (!showHidden && name.startsWith('.')) continue;
      final isDirectory = item['isDirectory'] == true;
      final path = item['path'] as String? ?? '';
      final size = (item['size'] is num) ? (item['size'] as num).toInt() : 0;
      DateTime modified;
      try {
        modified = DateTime.parse(item['modified'] as String? ?? '');
      } catch (_) {
        modified = DateTime.now();
      }
      entries.add(FileEntry(
        name: name,
        path: path.isNotEmpty ? path : p.join(home, '.Trash', name),
        isDirectory: isDirectory,
        isSymbolicLink: false,
        size: size,
        modified: modified,
        extension: isDirectory ? '' : p.extension(name).replaceFirst('.', '').toLowerCase(),
      ));
    }
    return entries;
  }

  Future<DiskUsage?> getDiskUsage(String path) async {
    if (path.isEmpty) return null;
    try {
      if (Platform.isWindows) {
        final drive = p.split(p.normalize(path)).first;
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          "(Get-PSDrive -Name '${drive.replaceAll(':', '')}').Free; (Get-PSDrive -Name '${drive.replaceAll(':', '')}').Used",
        ]);
        if (result.exitCode != 0) return null;
        final lines = (result.stdout as String)
            .trim()
            .split(RegExp(r'\s+'))
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.length < 2) return null;
        final free = int.tryParse(lines[0]) ?? 0;
        final used = int.tryParse(lines[1]) ?? 0;
        return DiskUsage(totalBytes: free + used, freeBytes: free, mountPoint: drive);
      }

      final result = await Process.run('df', ['-k', '-P', path]);
      if (result.exitCode != 0) return null;
      final lines = (result.stdout as String).trim().split('\n');
      if (lines.length < 2) return null;
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      if (parts.length < 6) return null;
      final totalKb = int.tryParse(parts[1]) ?? 0;
      final availableKb = int.tryParse(parts[3]) ?? 0;
      return DiskUsage(
        totalBytes: totalKb * 1024,
        freeBytes: availableKb * 1024,
        mountPoint: parts[5],
      );
    } catch (_) {
      return null;
    }
  }

  Future<MachineInfo> getMachineInfo() async {
    final hostname = Platform.localHostname;
    final username = Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        '';

    if (Platform.isMacOS) {
      final swVers = await Process.run('sw_vers', []);
      final lines = (swVers.stdout as String).split('\n');
      String productName = 'macOS';
      String productVersion = '';
      for (final line in lines) {
        if (line.startsWith('ProductName:')) {
          productName = line.split(':').skip(1).join(':').trim();
        } else if (line.startsWith('ProductVersion:')) {
          productVersion = line.split(':').skip(1).join(':').trim();
        }
      }
      final arch = (await Process.run('uname', ['-m'])).stdout.toString().trim();
      final cpu = (await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string']))
          .stdout
          .toString()
          .trim();
      final memRaw =
          (await Process.run('sysctl', ['-n', 'hw.memsize'])).stdout.toString().trim();
      final memoryBytes = int.tryParse(memRaw) ?? 0;
      return MachineInfo(
        hostname: hostname,
        osName: productName,
        osVersion: productVersion,
        arch: arch,
        cpu: cpu.isEmpty ? 'Unknown' : cpu,
        memoryBytes: memoryBytes,
        username: username,
      );
    }

    if (Platform.isWindows) {
      final os = (await Process.run('cmd', ['/c', 'ver'])).stdout.toString().trim();
      final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
      final cpu = Platform.environment['PROCESSOR_IDENTIFIER'] ?? arch;
      return MachineInfo(
        hostname: hostname,
        osName: 'Windows',
        osVersion: os,
        arch: arch,
        cpu: cpu,
        memoryBytes: 0,
        username: username,
      );
    }

    final uname = (await Process.run('uname', ['-sr'])).stdout.toString().trim();
    final arch = (await Process.run('uname', ['-m'])).stdout.toString().trim();
    var cpu = '';
    try {
      final cpuinfo = await File('/proc/cpuinfo').readAsString();
      final model = cpuinfo
          .split('\n')
          .firstWhere((l) => l.startsWith('model name'), orElse: () => '');
      if (model.contains(':')) cpu = model.split(':').skip(1).join(':').trim();
    } catch (_) {}
    var memoryBytes = 0;
    try {
      final meminfo = await File('/proc/meminfo').readAsString();
      final total = meminfo
          .split('\n')
          .firstWhere((l) => l.startsWith('MemTotal:'), orElse: () => '');
      final kb = int.tryParse(total.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      memoryBytes = kb * 1024;
    } catch (_) {}
    return MachineInfo(
      hostname: hostname,
      osName: uname.split(' ').first,
      osVersion: uname.split(' ').skip(1).join(' '),
      arch: arch,
      cpu: cpu.isEmpty ? arch : cpu,
      memoryBytes: memoryBytes,
      username: username,
    );
  }

  Future<void> openTerminal(String directoryPath) async {
    final dir = directoryPath.isEmpty ? (Platform.environment['HOME'] ?? '.') : directoryPath;
    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-a', 'Terminal', dir]);
      if (result.exitCode != 0) {
        throw Exception((result.stderr as String).trim().isEmpty
            ? 'Could not open Terminal.'
            : (result.stderr as String).trim());
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.start(
        'cmd',
        ['/c', 'start', 'cmd.exe', '/k', 'cd /d $dir'],
        mode: ProcessStartMode.detached,
      );
      return;
    }
    for (final candidate in [
      ['gnome-terminal', ['--working-directory=$dir']],
      ['konsole', ['--workdir', dir]],
      ['xfce4-terminal', ['--working-directory=$dir']],
      ['x-terminal-emulator', []],
    ]) {
      final exe = candidate[0] as String;
      final args = candidate[1] as List<String>;
      try {
        final which = await Process.run('which', [exe]);
        if (which.exitCode != 0) continue;
        await Process.start(exe, args, workingDirectory: dir, mode: ProcessStartMode.detached);
        return;
      } catch (_) {
        continue;
      }
    }
    throw Exception('No terminal emulator found.');
  }

  Future<void> openNewWindow() async {
    if (Platform.isMacOS) {
      final exe = Platform.resolvedExecutable;
      final marker = '.app/';
      final index = exe.indexOf(marker);
      if (index >= 0) {
        final appPath = exe.substring(0, index + 4);
        final result = await Process.run('open', ['-n', '-a', appPath]);
        if (result.exitCode != 0) {
          final err = (result.stderr as String).trim();
          throw Exception(err.isEmpty ? 'Could not open a new window.' : err);
        }
        return;
      }
    }
    await Process.start(
      Platform.resolvedExecutable,
      const [],
      mode: ProcessStartMode.detached,
    );
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

  Future<void> deleteNote(String id) async {
    final data = await _readNotesFile();
    final notes = List<Map<String, dynamic>>.from(
      (data['notes'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)),
    );
    final next = notes.where((item) => item['id'] != id).toList();
    if (next.length == notes.length) throw Exception('Note not found.');
    data['notes'] = next;
    await _writeNotesFile(data);
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
