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

  /// True when browsing Trash or a folder inside it.
  bool isInTrash(String directoryPath) {
    if (isTrashPath(directoryPath)) return true;
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return false;
    final normalized = p.normalize(directoryPath);
    if (Platform.isMacOS) {
      final root = p.normalize(p.join(home, '.Trash'));
      return normalized == root || p.isWithin(root, normalized);
    }
    if (Platform.isWindows) return false;
    final root = p.normalize(p.join(home, '.local', 'share', 'Trash', 'files'));
    return normalized == root || p.isWithin(root, normalized);
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
        path: path.isNotEmpty
            ? path.replaceFirst(RegExp(r'/+$'), '')
            : p.join(home, '.Trash', name),
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

  Future<List<DiskVolume>> getDiskVolumes() async {
    try {
      if (Platform.isWindows) return _windowsDiskVolumes();
      return _unixDiskVolumes();
    } catch (_) {
      return const [];
    }
  }

  Future<List<DiskVolume>> _windowsDiskVolumes() async {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      r'''
Get-CimInstance Win32_LogicalDisk |
  Where-Object { $_.DriveType -in 2,3,4 -and $_.Size -gt 0 } |
  ForEach-Object {
    $name = if ([string]::IsNullOrWhiteSpace($_.VolumeName)) { '' } else { $_.VolumeName }
    "{0}`t{1}`t{2}`t{3}`t{4}" -f $_.DeviceID, $name, $_.Size, $_.FreeSpace, $_.DriveType
  }
''',
    ]);
    if (result.exitCode != 0) return const [];
    final volumes = <DiskVolume>[];
    for (final line in (result.stdout as String).split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split('\t');
      if (parts.length < 4) continue;
      final total = int.tryParse(parts[2]) ?? 0;
      final free = int.tryParse(parts[3]) ?? 0;
      final driveType = parts.length >= 5 ? (int.tryParse(parts[4]) ?? 3) : 3;
      if (total <= 0) continue;
      volumes.add(DiskVolume(
        mountPoint: parts[0],
        label: parts[1],
        device: parts[0],
        totalBytes: total,
        freeBytes: free.clamp(0, total),
        // 3 = local fixed disk; collapse removable / network by default.
        isPrimary: driveType == 3,
      ));
    }
    volumes.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.mountPoint.compareTo(b.mountPoint);
    });
    return volumes;
  }

  Future<List<DiskVolume>> _unixDiskVolumes() async {
    final args = Platform.isMacOS
        ? <String>['-k', '-l', '-P']
        : <String>[
            '-k',
            '-P',
            '-x',
            'tmpfs',
            '-x',
            'devtmpfs',
            '-x',
            'squashfs',
            '-x',
            'overlay',
            '-x',
            'efivarfs',
            '-x',
            'devfs',
            '-x',
            'proc',
            '-x',
            'sysfs',
            '-x',
            'cgroup',
            '-x',
            'cgroup2',
          ];
    final result = await Process.run('df', args);
    if (result.exitCode != 0) return const [];

    final diskImages = Platform.isMacOS ? await _macDiskImageMounts() : const <String>{};

    final volumes = <DiskVolume>[];
    final seenMounts = <String>{};
    for (final line in (result.stdout as String).split('\n').skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 6) continue;
      final device = parts[0];
      final totalKb = int.tryParse(parts[1]) ?? 0;
      final availableKb = int.tryParse(parts[3]) ?? 0;
      final mount = parts.sublist(5).join(' ');
      if (totalKb <= 0) continue;
      if (!_includeUnixMount(device: device, mount: mount)) continue;
      if (!seenMounts.add(mount)) continue;
      volumes.add(DiskVolume(
        device: device,
        mountPoint: mount,
        label: _unixVolumeLabel(mount),
        totalBytes: totalKb * 1024,
        freeBytes: availableKb.clamp(0, totalKb) * 1024,
        isPrimary: _isPrimaryUnixMount(mount, diskImages),
      ));
    }

    volumes.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      if (a.mountPoint == '/' || a.mountPoint == '/System/Volumes/Data') {
        return -1;
      }
      if (b.mountPoint == '/' || b.mountPoint == '/System/Volumes/Data') {
        return 1;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return volumes;
  }

  Future<Set<String>> _macDiskImageMounts() async {
    try {
      final result = await Process.run('hdiutil', ['info']);
      if (result.exitCode != 0) return {};
      final mounts = <String>{};
      for (final line in (result.stdout as String).split('\n')) {
        // Lines look like: /dev/disk6s1\tUUID\t/Volumes/Name
        for (final part in line.split(RegExp(r'\t+'))) {
          final trimmed = part.trim();
          if (trimmed.startsWith('/Volumes/')) {
            mounts.add(trimmed);
          }
        }
      }
      return mounts;
    } catch (_) {
      return {};
    }
  }

  bool _isPrimaryUnixMount(String mount, Set<String> diskImages) {
    if (Platform.isMacOS) {
      if (mount == '/System/Volumes/Data') return true;
      // Disk images (DMGs, etc.) under /Volumes — collapse by default.
      if (diskImages.contains(mount)) return false;
      // Physical externals under /Volumes stay visible.
      if (mount.startsWith('/Volumes/')) return true;
      return false;
    }
    if (mount == '/') return true;
    if (mount == '/boot' || mount == '/boot/efi' || mount == '/efi') return true;
    if (mount.startsWith('/mnt/') ||
        mount.startsWith('/media/') ||
        mount.startsWith('/run/media/')) {
      return false;
    }
    final depth = mount.split('/').where((s) => s.isNotEmpty).length;
    return depth <= 1;
  }

  bool _includeUnixMount({required String device, required String mount}) {
    if (device == 'map' || device.startsWith('map@') || device == 'devfs') {
      return false;
    }
    if (Platform.isMacOS) {
      // Data holds user files and reports meaningful used space for the APFS
      // container; the sealed system volume at / does not.
      if (mount == '/System/Volumes/Data') return true;
      if (mount.startsWith('/Volumes/')) return true;
      return false;
    }
    if (mount == '/') return true;
    // Linux: keep top-level mounts and common data mounts.
    if (mount == '/boot' || mount == '/boot/efi' || mount == '/efi') return true;
    if (mount.startsWith('/mnt/') ||
        mount.startsWith('/media/') ||
        mount.startsWith('/run/media/')) {
      return true;
    }
    // Other real filesystems mounted at a single path segment (e.g. /home, /data).
    final depth = mount.split('/').where((s) => s.isNotEmpty).length;
    return depth <= 1;
  }

  String _unixVolumeLabel(String mount) {
    if (mount == '/' || mount == '/System/Volumes/Data') {
      return Platform.isMacOS ? 'Macintosh HD' : 'Root';
    }
    if (mount.startsWith('/Volumes/')) {
      return mount.substring('/Volumes/'.length);
    }
    return '';
  }

  Future<MachineInfo> getMachineInfo() async {
    final hostname = Platform.localHostname;
    final username = Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        '';
    final disks = await getDiskVolumes();

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
        disks: disks,
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
        disks: disks,
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
      disks: disks,
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

  /// Label for opening the OS trash UI (Finder / Recycle Bin / file manager).
  String get nativeTrashLabel {
    if (Platform.isMacOS) return 'Open in Finder';
    if (Platform.isWindows) return 'Open Recycle Bin';
    return 'Open system Trash';
  }

  /// Open the system Trash / Recycle Bin in the native file manager.
  Future<void> openNativeTrash() async {
    if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-e',
        'tell application "Finder"',
        '-e',
        'reopen',
        '-e',
        'activate',
        '-e',
        'open trash',
        '-e',
        'end tell',
      ]).timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        final err = _macOsascriptError(result);
        throw Exception(
          err.isEmpty ? 'Could not open Trash in Finder.' : err,
        );
      }
      return;
    }
    if (Platform.isWindows) {
      final result = await Process.run('explorer.exe', [
        'shell:RecycleBinFolder',
      ]);
      // explorer often returns 1 even on success
      if (result.exitCode != 0 && result.exitCode != 1) {
        throw Exception('Could not open the Recycle Bin.');
      }
      return;
    }
    var result = await Process.run('xdg-open', ['trash:///']);
    if (result.exitCode != 0) {
      final home = Platform.environment['HOME'] ?? '.';
      result = await Process.run(
        'xdg-open',
        [p.join(home, '.local', 'share', 'Trash', 'files')],
      );
    }
    if (result.exitCode != 0) {
      throw Exception('Could not open the system Trash.');
    }
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
      if (isTrashPath(p.dirname(targetPath)) || isTrashPath(targetPath)) {
        // Already in trash — permanent delete instead of nesting.
        await deletePermanently([targetPath]);
        continue;
      }
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
        await _linuxMoveToTrash(targetPath);
      }
    }
  }

  Future<void> _linuxMoveToTrash(String targetPath) async {
    final home = Platform.environment['HOME'] ?? '.';
    final filesDir = Directory(p.join(home, '.local', 'share', 'Trash', 'files'));
    final infoDir = Directory(p.join(home, '.local', 'share', 'Trash', 'info'));
    await filesDir.create(recursive: true);
    await infoDir.create(recursive: true);

    final destination = await uniquePath(filesDir.path, p.basename(targetPath));
    final type = await FileSystemEntity.type(targetPath, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(targetPath).rename(destination);
    } else {
      await File(targetPath).rename(destination);
    }

    final encodedPath = Uri.encodeComponent(targetPath).replaceAll('%2F', '/');
    final stamp = DateTime.now().toIso8601String().split('.').first;
    final infoPath = p.join(infoDir.path, '${p.basename(destination)}.trashinfo');
    await File(infoPath).writeAsString(
      '[Trash Info]\nPath=$encodedPath\nDeletionDate=$stamp\n',
    );
  }

  /// Restore items from Trash to their original locations when known.
  Future<void> restoreFromTrash(List<String> paths) async {
    if (paths.isEmpty) return;
    if (Platform.isMacOS) {
      await _macRestoreFromTrash(paths);
      return;
    }
    if (Platform.isWindows) {
      throw Exception('Restore from Recycle Bin is not supported yet.');
    }
    await _linuxRestoreFromTrash(paths);
  }

  Future<void> _macRestoreFromTrash(List<String> paths) async {
    final script = '''
function run(argv) {
  const finder = Application("Finder");
  const targets = JSON.parse(argv[0]).map(function(p) {
    return String(p).replace(/\\/\$/, "");
  });
  const items = finder.trash.items();
  const errors = [];
  for (const wanted of targets) {
    let matched = null;
    const wantedName = wanted.split("/").filter(Boolean).pop();
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      try {
        let path = decodeURIComponent(String(item.url()).replace(/^file:\\/\\/\\/?/, "/"));
        path = path.replace(/\\/\$/, "");
        if (path === wanted || String(item.name()) === wantedName) {
          matched = item;
          break;
        }
      } catch (e) {}
    }
    if (!matched) {
      errors.push(wanted);
      continue;
    }
    try {
      finder.putAway(matched);
    } catch (e) {
      errors.push(wanted + ": " + e);
    }
  }
  if (errors.length) {
    throw new Error("Could not restore: " + errors.join("; "));
  }
}
''';
    final normalized = paths.map(_stripTrailingSlashes).toList();
    final result = await Process.run(
      'osascript',
      ['-l', 'JavaScript', '-e', script, jsonEncode(normalized)],
    ).timeout(const Duration(seconds: 30));
    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      throw Exception(err.isEmpty ? 'Could not restore the selected items.' : err);
    }
  }

  Future<void> _linuxRestoreFromTrash(List<String> paths) async {
    final home = Platform.environment['HOME'] ?? '.';
    final infoDir = p.join(home, '.local', 'share', 'Trash', 'info');
    final desktop = Directory(p.join(home, 'Desktop'));
    final fallbackDir =
        await desktop.exists() ? desktop.path : home;

    for (final trashPath in paths) {
      final base = p.basename(trashPath);
      final infoFile = File(p.join(infoDir, '$base.trashinfo'));
      var destination = p.join(fallbackDir, base);

      if (await infoFile.exists()) {
        final content = await infoFile.readAsString();
        for (final line in content.split('\n')) {
          if (line.startsWith('Path=')) {
            final raw = line.substring(5).trim();
            try {
              destination = Uri.decodeComponent(raw);
            } catch (_) {
              destination = raw;
            }
            break;
          }
        }
      }

      final parent = Directory(p.dirname(destination));
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      destination = await uniquePath(p.dirname(destination), p.basename(destination));

      final type = await FileSystemEntity.type(trashPath, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(trashPath).rename(destination);
      } else if (type != FileSystemEntityType.notFound) {
        await File(trashPath).rename(destination);
      }
      if (await infoFile.exists()) {
        await infoFile.delete();
      }
    }
  }

  Future<void> deletePermanently(List<String> paths) async {
    if (paths.isEmpty) return;
    if (Platform.isMacOS) {
      await _macDeletePermanently(paths);
      return;
    }
    for (final targetPath in paths) {
      if (Platform.isLinux) {
        final home = Platform.environment['HOME'] ?? '.';
        final infoFile = File(
          p.join(home, '.local', 'share', 'Trash', 'info', '${p.basename(targetPath)}.trashinfo'),
        );
        if (await infoFile.exists()) {
          await infoFile.delete();
        }
      }
      final type = await FileSystemEntity.type(targetPath, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(targetPath).delete(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        await File(targetPath).delete();
      }
    }
  }

  String _stripTrailingSlashes(String path) {
    if (path.length <= 1) return path;
    return path.replaceFirst(RegExp(r'/+$'), '');
  }

  String _macOsascriptError(ProcessResult result) {
    final err = (result.stderr as String)
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.contains('ApplePersistence='))
        .join(' ');
    if (err.isNotEmpty) return err;
    return (result.stdout as String).trim();
  }

  bool _isUnderMacTrash(String path) {
    final normalized = _stripTrailingSlashes(path);
    final home = Platform.environment['HOME'];
    if (home != null) {
      final trash = p.join(home, '.Trash');
      if (normalized == trash || p.isWithin(trash, normalized)) {
        return true;
      }
    }
    // Volume trash: /.Trashes/<uid>/...
    final parts = p.split(normalized);
    final trashesIdx = parts.indexOf('.Trashes');
    if (trashesIdx >= 0 && trashesIdx + 1 < parts.length) {
      return true;
    }
    return false;
  }

  Future<bool> _macPathExists(String path) async {
    final result = await Process.run('/bin/test', ['-e', path]);
    return result.exitCode == 0;
  }

  /// Deep link straight to System Settings → Privacy & Security → Full Disk
  /// Access. Granting it to Panorama there is the one reliable, permanent
  /// fix for TCC blocking `~/.Trash` unlinks (see `_macDeletePermanently`).
  Future<void> openFullDiskAccessSettings() async {
    await Process.run('open', [
      'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles',
    ]);
  }

  static const String _fullDiskAccessHint =
      'Grant Panorama Full Disk Access in System Settings → Privacy & '
      'Security → Full Disk Access, then try again.';

  /// Permanently delete Trash items on macOS.
  ///
  /// Modern macOS TCC blocks unlinking `~/.Trash`, and Finder no longer
  /// exposes `put away` / permanent-delete scripting (moves out of Trash
  /// returns -5000). Try a normal `rm` first (silently works once Panorama
  /// has Full Disk Access — no prompt needed). If that fails, try an admin
  /// privilege escalation as a one-off fallback; if the item is *still*
  /// there afterwards (some macOS versions keep `~/.Trash` protected even
  /// from root), tell the user to grant Full Disk Access instead of retrying
  /// forever.
  Future<void> _macDeletePermanently(List<String> paths) async {
    final targets = paths
        .map(_stripTrailingSlashes)
        .where((path) => path.isNotEmpty)
        .toList();
    if (targets.isEmpty) return;

    final invalid = targets.where((path) => !_isUnderMacTrash(path)).toList();
    if (invalid.isNotEmpty) {
      throw Exception('Can only permanently delete items that are in Trash.');
    }

    final needPrivileged = <String>[];
    for (final path in targets) {
      await Process.run('/usr/bin/chflags', ['-R', 'nouchg,noschg', path]);
      final rm = await Process.run('/bin/rm', ['-rf', '--', path]);
      if (rm.exitCode != 0 || await _macPathExists(path)) {
        needPrivileged.add(path);
      }
    }

    if (needPrivileged.isEmpty) return;

    const script = r'''
on run argv
  set cmd to "/bin/rm -rf --"
  repeat with p in argv
    set cmd to cmd & " " & quoted form of (p as text)
  end repeat
  do shell script cmd with administrator privileges
end run
''';

    final result = await Process.run(
      'osascript',
      ['-e', script, ...needPrivileged],
    ).timeout(const Duration(seconds: 120));

    if (result.exitCode != 0) {
      final err = _macOsascriptError(result);
      // User cancelled the auth dialog, or auth failed.
      if (err.toLowerCase().contains('user canceled') ||
          err.toLowerCase().contains('user cancelled') ||
          err.contains('(-128)')) {
        throw Exception('Permanent delete was cancelled.');
      }
      throw Exception(
        err.isEmpty
            ? 'Couldn’t permanently delete. $_fullDiskAccessHint'
            : 'Couldn’t permanently delete: $err',
      );
    }

    // Some macOS versions keep `~/.Trash` protected even from an
    // administrator shell — confirm the items are actually gone rather than
    // trusting osascript's exit code.
    final stillThere = <String>[];
    for (final path in needPrivileged) {
      if (await _macPathExists(path)) stillThere.add(p.basename(path));
    }
    if (stillThere.isNotEmpty) {
      throw Exception('Couldn’t permanently delete. $_fullDiskAccessHint');
    }
  }

  Future<void> emptyTrash() async {
    if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-e',
        'tell application "Finder" to empty the trash',
      ]).timeout(const Duration(seconds: 120));
      if (result.exitCode != 0) {
        final err = (result.stderr as String).trim();
        throw Exception(err.isEmpty ? 'Could not empty the Trash.' : err);
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Clear-RecycleBin -Force -ErrorAction SilentlyContinue',
      ]);
      return;
    }

    final home = Platform.environment['HOME'] ?? '.';
    final filesDir = Directory(p.join(home, '.local', 'share', 'Trash', 'files'));
    final infoDir = Directory(p.join(home, '.local', 'share', 'Trash', 'info'));
    for (final dir in [filesDir, infoDir]) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        try {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else {
            await entity.delete();
          }
        } catch (_) {}
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
