import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../settings.dart';
import '../theme.dart';

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: controller.closeSettings,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.18),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Material(
                elevation: 12,
                color: const Color(0xFFF7F8FA),
                child: SizedBox(
                  width: 380,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Settings',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Preferences for Panorama.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: PanoramaColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: controller.closeSettings,
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                            children: [
                              const Text(
                                'Experimental',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: PanoramaColors.muted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'These features are unfinished or may change. '
                                'They stay off until you turn them on.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: PanoramaColors.muted,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              for (final feature in ExperimentalFeature.values)
                                _ExperimentalToggle(
                                  feature: feature,
                                  enabled: controller.isExperimentalEnabled(feature),
                                  onChanged: (value) {
                                    controller.setExperimentalFeature(
                                      feature,
                                      value,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExperimentalToggle extends StatelessWidget {
  const _ExperimentalToggle({
    required this.feature,
    required this.enabled,
    required this.onChanged,
  });

  final ExperimentalFeature feature;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PanoramaColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PanoramaColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PanoramaColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
