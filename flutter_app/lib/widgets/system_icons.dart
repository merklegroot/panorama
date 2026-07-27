import 'package:flutter/material.dart';

import '../theme.dart';

/// System / hardware icons inspired by the hudsse project: vendor-aware
/// branding with distinct colors for Apple, Intel, AMD, ARM, and OS families.

class SystemIcons {
  const SystemIcons._();

  static Widget hostname({double size = 18}) {
    return Icon(Icons.computer_outlined, size: size, color: PanoramaColors.muted);
  }

  static Widget user({double size = 18}) {
    return Icon(Icons.person_outline, size: size, color: PanoramaColors.muted);
  }

  static Widget memory({double size = 18}) {
    return Icon(Icons.memory_outlined, size: size, color: const Color(0xFF7C5CBF));
  }

  static Widget os(String osName, {double size = 18}) {
    final lower = osName.toLowerCase();
    if (lower.contains('mac') || lower.contains('darwin')) {
      return Icon(Icons.apple, size: size, color: const Color(0xFF555555));
    }
    if (lower.contains('windows')) {
      return Icon(Icons.window, size: size, color: const Color(0xFF0078D4));
    }
    if (lower.contains('linux') ||
        lower.contains('ubuntu') ||
        lower.contains('debian') ||
        lower.contains('fedora') ||
        lower.contains('arch')) {
      return Icon(Icons.terminal, size: size, color: const Color(0xFFE95420));
    }
    return Icon(Icons.terminal, size: size, color: PanoramaColors.muted);
  }

  /// Vendor-aware CPU mark, matching hudsse's CPUIcon detection.
  static Widget cpu(String name, {String arch = '', double size = 18}) {
    final lower = '${name.toLowerCase()} ${arch.toLowerCase()}';

    if (lower.contains('intel')) {
      return _BrandPair(
        size: size,
        manufacturer: const _LetterMark('i', Color(0xFF0071C5)),
        type: Icon(Icons.developer_board_outlined, size: size, color: const Color(0xFF0071C5)),
      );
    }
    if (lower.contains('amd') || lower.contains('ryzen') || lower.contains('epyc')) {
      return _BrandPair(
        size: size,
        manufacturer: const _LetterMark('A', Color(0xFFED1C24)),
        type: Icon(Icons.developer_board_outlined, size: size, color: const Color(0xFFED1C24)),
      );
    }
    if (lower.contains('apple m') ||
        RegExp(r'\bapple m\d').hasMatch(lower) ||
        (lower.contains('apple') &&
            (lower.contains('arm') ||
                lower.contains('m1') ||
                lower.contains('m2') ||
                lower.contains('m3') ||
                lower.contains('m4') ||
                lower.contains('m5')))) {
      return _BrandPair(
        size: size,
        manufacturer: Icon(Icons.apple, size: size, color: const Color(0xFF3A3A3A)),
        type: Icon(Icons.memory, size: size, color: const Color(0xFF6D7785)),
      );
    }
    if (lower.contains('qualcomm') || lower.contains('snapdragon')) {
      return _BrandPair(
        size: size,
        manufacturer: const _LetterMark('Q', Color(0xFF3253DC)),
        type: Icon(Icons.developer_board_outlined, size: size, color: const Color(0xFF3253DC)),
      );
    }
    if (lower.contains('arm') ||
        lower.contains('cortex') ||
        lower.contains('aarch64') ||
        lower.contains('arm64')) {
      return _BrandPair(
        size: size,
        manufacturer: const _LetterMark('a', Color(0xFF0091BD)),
        type: Icon(Icons.developer_board_outlined, size: size, color: const Color(0xFF0091BD)),
      );
    }
    return Icon(Icons.memory, size: size, color: PanoramaColors.muted);
  }
}

class _BrandPair extends StatelessWidget {
  const _BrandPair({
    required this.size,
    required this.manufacturer,
    required this.type,
  });

  final double size;
  final Widget manufacturer;
  final Widget type;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: size, height: size, child: manufacturer),
        SizedBox(width: size * 0.2),
        SizedBox(width: size, height: size, child: type),
      ],
    );
  }
}

class _LetterMark extends StatelessWidget {
  const _LetterMark(this.letter, this.color);

  final String letter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

/// Value row with an optional leading system icon (hudsse SystemDetailField layout).
class SystemValueLine extends StatelessWidget {
  const SystemValueLine({
    super.key,
    required this.value,
    this.icon,
    this.style,
  });

  final String value;
  final Widget? icon;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            value,
            style: style ?? const TextStyle(fontSize: 14, color: PanoramaColors.ink),
          ),
        ),
      ],
    );
  }
}
