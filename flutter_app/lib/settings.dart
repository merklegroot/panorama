/// Experimental features that can be toggled in Settings.
///
/// All are off by default and persist via [AppSettings].
enum ExperimentalFeature {
  previewPane(
    id: 'previewPane',
    title: 'Preview pane',
    description: 'Show a preview of the selected file beside the folder view.',
  ),
  dualPane(
    id: 'dualPane',
    title: 'Dual pane',
    description: 'Browse two folders side by side.',
  ),
  embeddedTerminal(
    id: 'embeddedTerminal',
    title: 'Embedded terminal',
    description: 'Open a terminal panel inside Panorama.',
  ),
  customizableColumns(
    id: 'customizableColumns',
    title: 'Customizable columns',
    description: 'Resize and reorder columns in details view.',
  );

  const ExperimentalFeature({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class AppSettings {
  const AppSettings({
    this.experimental = const {},
  });

  final Map<String, bool> experimental;

  static const empty = AppSettings();

  bool isEnabled(ExperimentalFeature feature) =>
      experimental[feature.id] ?? false;

  AppSettings withExperimental(ExperimentalFeature feature, bool enabled) {
    return AppSettings(
      experimental: {
        ...experimental,
        feature.id: enabled,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'experimental': {
          for (final feature in ExperimentalFeature.values)
            feature.id: isEnabled(feature),
        },
      };

  factory AppSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    final raw = json['experimental'];
    if (raw is! Map) return empty;
    final experimental = <String, bool>{};
    for (final feature in ExperimentalFeature.values) {
      final value = raw[feature.id];
      if (value is bool) experimental[feature.id] = value;
    }
    return AppSettings(experimental: experimental);
  }
}
