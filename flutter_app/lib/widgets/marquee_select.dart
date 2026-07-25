import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';

/// Rubber-band (marquee) multi-select over a scrollable file list or grid.
class MarqueeSelectArea extends StatefulWidget {
  const MarqueeSelectArea({
    super.key,
    required this.entries,
    required this.layout,
    required this.onMarqueeSelection,
    required this.onMarqueeStarted,
    required this.child,
  });

  final List<FileEntry> entries;
  final MarqueeLayout layout;
  final void Function(Set<String> paths, {required bool additive}) onMarqueeSelection;
  final VoidCallback onMarqueeStarted;
  final Widget Function(ScrollController controller, bool marqueeActive) child;

  @override
  State<MarqueeSelectArea> createState() => _MarqueeSelectAreaState();
}

class _MarqueeSelectAreaState extends State<MarqueeSelectArea> {
  final ScrollController _scrollController = ScrollController();
  int? _pointer;
  Offset? _origin;
  Offset? _current;
  bool _active = false;
  bool _additive = false;

  static const _threshold = 4.0;

  Rect? get _rect {
    final a = _origin;
    final b = _current;
    if (a == null || b == null || !_active) return null;
    return Rect.fromPoints(a, b);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _end() {
    if (_pointer == null && !_active) return;
    setState(() {
      _pointer = null;
      _origin = null;
      _current = null;
      _active = false;
    });
  }

  void _onDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _origin = event.localPosition;
    _current = event.localPosition;
    _active = false;
    _additive = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || _origin == null) return;
    final next = event.localPosition;
    final distance = (next - _origin!).distance;
    final becameActive = !_active && distance >= _threshold;
    if (becameActive) {
      _active = true;
      widget.onMarqueeStarted();
    }
    if (!_active) return;

    setState(() => _current = next);
    _applySelection();
  }

  void _onUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _end();
  }

  void _applySelection() {
    final rect = _rect;
    if (rect == null || !mounted) return;
    final size = context.size;
    if (size == null) return;
    final scroll = _scrollController.hasClients ? _scrollController.offset : 0.0;
    final paths = widget.layout
        .hitTest(
          marquee: rect,
          viewport: size,
          scrollOffset: scroll,
          entries: widget.entries,
        )
        .toSet();
    widget.onMarqueeSelection(paths, additive: _additive);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onUp,
      child: Stack(
        children: [
          Positioned.fill(
            child: widget.child(_scrollController, _active),
          ),
          if (rect != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _MarqueePainter(rect),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

abstract class MarqueeLayout {
  const MarqueeLayout();

  Iterable<String> hitTest({
    required Rect marquee,
    required Size viewport,
    required double scrollOffset,
    required List<FileEntry> entries,
  });
}

class ListMarqueeLayout extends MarqueeLayout {
  const ListMarqueeLayout({this.itemExtent = 32});

  final double itemExtent;

  @override
  Iterable<String> hitTest({
    required Rect marquee,
    required Size viewport,
    required double scrollOffset,
    required List<FileEntry> entries,
  }) sync* {
    if (entries.isEmpty || itemExtent <= 0) return;
    final top = marquee.top + scrollOffset;
    final bottom = marquee.bottom + scrollOffset;
    final first = math.max(0, (top / itemExtent).floor());
    final last = math.min(entries.length - 1, (bottom / itemExtent).ceil());
    for (var i = first; i <= last; i++) {
      final itemTop = i * itemExtent - scrollOffset;
      final itemRect = Rect.fromLTWH(0, itemTop, viewport.width, itemExtent);
      if (itemRect.overlaps(marquee)) {
        yield entries[i].path;
      }
    }
  }
}

class GridMarqueeLayout extends MarqueeLayout {
  const GridMarqueeLayout({
    this.maxCrossAxisExtent = 120,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 0.85,
    this.padding = const EdgeInsets.all(12),
  });

  final double maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets padding;

  @override
  Iterable<String> hitTest({
    required Rect marquee,
    required Size viewport,
    required double scrollOffset,
    required List<FileEntry> entries,
  }) sync* {
    if (entries.isEmpty) return;
    final crossExtent = viewport.width - padding.horizontal;
    if (crossExtent <= 0) return;

    final crossCount = math.max(
      1,
      ((crossExtent + crossAxisSpacing) / (maxCrossAxisExtent + crossAxisSpacing))
          .floor(),
    );
    final childWidth =
        (crossExtent - (crossCount - 1) * crossAxisSpacing) / crossCount;
    final childHeight = childWidth / childAspectRatio;

    for (var i = 0; i < entries.length; i++) {
      final row = i ~/ crossCount;
      final col = i % crossCount;
      final left = padding.left + col * (childWidth + crossAxisSpacing);
      final top =
          padding.top + row * (childHeight + mainAxisSpacing) - scrollOffset;
      final itemRect = Rect.fromLTWH(left, top, childWidth, childHeight);
      if (itemRect.overlaps(marquee)) {
        yield entries[i].path;
      }
    }
  }
}

class _MarqueePainter extends CustomPainter {
  _MarqueePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = PanoramaColors.blue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = PanoramaColors.blue.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  @override
  bool shouldRepaint(covariant _MarqueePainter oldDelegate) =>
      oldDelegate.rect != rect;
}
