class FileEntry {
  const FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.isSymbolicLink,
    required this.size,
    required this.modified,
    required this.extension,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymbolicLink;
  final int size;
  final DateTime modified;
  final String extension;

  String get fileType {
    if (isDirectory) return 'Folder';
    if (extension.isEmpty) return 'File';
    return '${extension.toUpperCase()} file';
  }
}

class LocationItem {
  const LocationItem({
    required this.name,
    required this.path,
    required this.icon,
  });

  final String name;
  final String path;
  final String icon;
}

enum NoteStatus { open, done }

class ImprovementNote {
  const ImprovementNote({
    required this.id,
    required this.body,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.folderPath,
  });

  final String id;
  final String body;
  final NoteStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? folderPath;

  ImprovementNote copyWith({
    String? body,
    NoteStatus? status,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return ImprovementNote(
      id: id,
      body: body ?? this.body,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      folderPath: folderPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'status': status == NoteStatus.open ? 'open' : 'done',
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'folderPath': folderPath,
      };

  factory ImprovementNote.fromJson(Map<String, dynamic> json) {
    return ImprovementNote(
      id: json['id'] as String,
      body: json['body'] as String,
      status: json['status'] == 'done' ? NoteStatus.done : NoteStatus.open,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      folderPath: json['folderPath'] as String?,
    );
  }
}

class OpenWithApp {
  const OpenWithApp({
    required this.name,
    required this.path,
    this.isDefault = false,
  });

  final String name;
  final String path;
  final bool isDefault;
}

class ClipboardState {
  const ClipboardState({this.paths = const [], this.cut = false});

  final List<String> paths;
  final bool cut;
}
