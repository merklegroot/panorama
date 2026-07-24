import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

import '../app_controller.dart';
import '../theme.dart';

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key, required this.controller});

  final AppController controller;

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  late final Terminal _terminal;
  late final TerminalController _terminalController;
  Pty? _pty;
  String? _cwd;
  int _startedSession = -1;
  int _lastCwdSync = -1;
  String? _error;

  AppController get app => widget.controller;

  @override
  void initState() {
    super.initState();
    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureSession();
    });
  }

  @override
  void didUpdateWidget(covariant TerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSession();
    _syncCwdIfNeeded();
  }

  @override
  void dispose() {
    _killPty();
    super.dispose();
  }

  void _killPty() {
    final pty = _pty;
    _pty = null;
    if (pty == null) return;
    try {
      pty.kill();
    } catch (_) {}
  }

  String get _shell {
    if (Platform.isWindows) return 'cmd.exe';
    return Platform.environment['SHELL'] ?? '/bin/zsh';
  }

  void _ensureSession() {
    final dir = app.terminalWorkingDirectory;
    final session = app.terminalSession;
    if (_pty != null && _startedSession == session) {
      _syncCwdIfNeeded();
      return;
    }

    _killPty();
    _cwd = dir;
    _startedSession = session;
    _lastCwdSync = app.terminalCwdSync;
    _error = null;

    try {
      final pty = Pty.start(
        _shell,
        workingDirectory: dir.isEmpty ? null : dir,
        columns: _terminal.viewWidth > 0 ? _terminal.viewWidth : 80,
        rows: _terminal.viewHeight > 0 ? _terminal.viewHeight : 24,
      );
      _pty = pty;

      pty.output.cast<List<int>>().transform(const Utf8Decoder()).listen(
        _terminal.write,
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        },
      );

      pty.exitCode.then((code) {
        if (!mounted || _pty != pty) return;
        _terminal.write('\r\n[process exited: $code]\r\n');
      });

      _terminal.onOutput = (data) {
        _pty?.write(const Utf8Encoder().convert(data));
      };

      _terminal.onResize = (w, h, pw, ph) {
        _pty?.resize(h, w);
      };

      if (mounted) setState(() {});
    } catch (reason) {
      if (!mounted) return;
      setState(() => _error = reason.toString());
    }
  }

  void _syncCwdIfNeeded() {
    if (_pty == null) return;
    if (app.terminalCwdSync == _lastCwdSync) return;
    _lastCwdSync = app.terminalCwdSync;
    final dir = app.terminalWorkingDirectory;
    if (dir.isEmpty || dir == _cwd) {
      _cwd = dir;
      if (mounted) setState(() {});
      return;
    }
    _cwd = dir;
    _sendCd(dir);
    if (mounted) setState(() {});
  }

  void _sendCd(String dir) {
    final pty = _pty;
    if (pty == null) return;
    final command = Platform.isWindows
        ? 'cd /d "${dir.replaceAll('"', '')}"\r\n'
        : 'cd ${_shellEscape(dir)}\n';
    pty.write(Uint8List.fromList(utf8.encode(command)));
  }

  String _shellEscape(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  @override
  Widget build(BuildContext context) {
    final pathLabel = app.terminalWorkingDirectory.isEmpty
        ? 'Terminal'
        : app.terminalWorkingDirectory;

    return Container(
      height: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF1B1F24),
        border: Border(top: BorderSide(color: PanoramaColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            color: const Color(0xFF242A31),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 14, color: Color(0xFF9AA4B2)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pathLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9AA4B2)),
                  ),
                ),
                IconButton(
                  tooltip: 'Restart shell',
                  visualDensity: VisualDensity.compact,
                  onPressed: app.restartTerminalPanel,
                  icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF9AA4B2)),
                ),
                IconButton(
                  tooltip: 'Close terminal',
                  visualDensity: VisualDensity.compact,
                  onPressed: app.closeTerminalPanel,
                  icon: const Icon(Icons.close, size: 16, color: Color(0xFF9AA4B2)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
                    ),
                  )
                : TerminalView(
                    _terminal,
                    controller: _terminalController,
                    autofocus: true,
                    backgroundOpacity: 0,
                    theme: TerminalThemes.defaultTheme,
                    textStyle: const TerminalStyle(
                      fontSize: 12,
                      fontFamily: 'Menlo',
                      fontFamilyFallback: ['Monaco', 'Consolas', 'Courier New', 'monospace'],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
