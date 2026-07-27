import 'dart:io';

import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../explorer_service.dart';
import '../models.dart';
import '../theme.dart';

const _textPreviewExtensions = {
  'txt',
  'md',
  'markdown',
  'json',
  'csv',
  'tsv',
  'xml',
  'html',
  'htm',
  'css',
  'js',
  'jsx',
  'ts',
  'tsx',
  'py',
  'rb',
  'rs',
  'go',
  'java',
  'kt',
  'swift',
  'c',
  'h',
  'cpp',
  'hpp',
  'cs',
  'sh',
  'bash',
  'zsh',
  'yaml',
  'yml',
  'toml',
  'ini',
  'cfg',
  'conf',
  'log',
  'dart',
  'sql',
  'gitignore',
  'dockerfile',
  'env',
};

class PreviewPane extends StatelessWidget {
  const PreviewPane({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller,
        controller.left.selection,
        controller.right.selection,
        controller.left,
        controller.right,
      ]),
      builder: (context, _) {
        final selected = controller.selectedEntries;
        return Container(
          width: controller.previewWidth,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            border: Border(left: BorderSide(color: PanoramaColors.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: PanoramaColors.line)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PanoramaColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hide preview',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: controller.togglePreview,
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body(selected)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(List<FileEntry> selected) {
    if (selected.isEmpty) {
      return const _EmptyPreview(
        icon: Icons.preview_outlined,
        title: 'No selection',
        subtitle: 'Select a file to preview it here.',
      );
    }
    if (selected.length > 1) {
      return _EmptyPreview(
        icon: Icons.select_all,
        title: '${selected.length} items selected',
        subtitle: 'Select a single item to see a preview.',
      );
    }
    return _SinglePreview(entry: selected.first);
  }
}

class PreviewResizeHandle extends StatelessWidget {
  const PreviewResizeHandle({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          controller.setPreviewWidth(controller.previewWidth - details.delta.dx);
        },
        child: const SizedBox(width: 6, height: double.infinity),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: PanoramaColors.muted.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PanoramaColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinglePreview extends StatelessWidget {
  const _SinglePreview({required this.entry});

  final FileEntry entry;

  bool get _isImage =>
      !entry.isDirectory && imageExtensions.contains(entry.extension);

  bool get _isText {
    if (entry.isDirectory) return false;
    if (_textPreviewExtensions.contains(entry.extension)) return true;
    // Extensionless common names.
    final lower = entry.name.toLowerCase();
    return lower == 'readme' ||
        lower == 'license' ||
        lower == 'makefile' ||
        lower == 'dockerfile' ||
        lower == 'gemfile' ||
        lower == 'procfile';
  }

  IconData get _icon {
    if (entry.isDirectory) return Icons.folder;
    if (_isImage) return Icons.image_outlined;
    if (_isText) return Icons.description_outlined;
    if (const {'zip', 'rar', '7z', 'tar', 'gz', 'dmg'}.contains(entry.extension)) {
      return Icons.archive_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      children: [
        if (_isImage)
          _ImagePreview(key: ValueKey(entry.path), path: entry.path)
        else if (_isText)
          _TextPreview(key: ValueKey(entry.path), path: entry.path)
        else
          _IconHero(icon: _icon, isDirectory: entry.isDirectory),
        const SizedBox(height: 16),
        Text(
          entry.name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: PanoramaColors.ink,
          ),
        ),
        const SizedBox(height: 14),
        _meta('Kind', entry.fileType),
        _meta('Size', formatSize(entry.size, entry.isDirectory)),
        _meta('Modified', formatModified(entry.modified)),
        if (entry.isSymbolicLink) _meta('Alias', 'Symbolic link'),
        _meta('Where', entry.path),
      ],
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PanoramaColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 13, color: PanoramaColors.ink),
          ),
        ],
      ),
    );
  }
}

class _IconHero extends StatelessWidget {
  const _IconHero({required this.icon, required this.isDirectory});

  final IconData icon;
  final bool isDirectory;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PanoramaColors.line),
      ),
      child: Icon(
        icon,
        size: 72,
        color: isDirectory ? const Color(0xFFF0C040) : const Color(0xFF55738F),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PanoramaColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        File(path),
        fit: BoxFit.contain,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, error, stackTrace) => const SizedBox(
          height: 160,
          child: Center(
            child: Icon(Icons.broken_image_outlined, size: 48, color: PanoramaColors.muted),
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatefulWidget {
  const _TextPreview({super.key, required this.path});

  final String path;

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  static const _maxBytes = 48 * 1024;
  late Future<_TextLoadResult> _future = _load(widget.path);

  @override
  void didUpdateWidget(covariant _TextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      setState(() {
        _future = _load(widget.path);
      });
    }
  }

  Future<_TextLoadResult> _load(String path) async {
    try {
      final file = File(path);
      final length = await file.length();
      final bytes = await file.openRead(0, _maxBytes).fold<List<int>>(
        <int>[],
        (prev, chunk) => prev..addAll(chunk),
      );
      // Reject likely-binary content.
      final sample = bytes.take(512);
      if (sample.any((b) => b == 0)) {
        return const _TextLoadResult(
          text: '',
          truncated: false,
          error: 'This file looks like binary data and can’t be previewed as text.',
        );
      }
      final text = String.fromCharCodes(bytes);
      return _TextLoadResult(
        text: text,
        truncated: length > _maxBytes,
      );
    } catch (e) {
      return _TextLoadResult(text: '', truncated: false, error: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TextLoadResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            height: 160,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PanoramaColors.line),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final result = snapshot.data;
        if (result == null || result.error != null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PanoramaColors.line),
            ),
            child: Text(
              result?.error ?? 'Could not load preview.',
              style: const TextStyle(fontSize: 12, color: PanoramaColors.muted),
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoramaColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    result.text.isEmpty ? '(empty file)' : result.text,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      fontFamily: 'Menlo',
                      color: PanoramaColors.ink,
                    ),
                  ),
                ),
              ),
              if (result.truncated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: PanoramaColors.sidebar,
                  child: const Text(
                    'Showing the first 48 KB',
                    style: TextStyle(fontSize: 11, color: PanoramaColors.muted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TextLoadResult {
  const _TextLoadResult({
    required this.text,
    required this.truncated,
    this.error,
  });

  final String text;
  final bool truncated;
  final String? error;
}
