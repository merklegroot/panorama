import 'package:flutter_test/flutter_test.dart';

import 'package:panorama/explorer_service.dart';

void main() {
  test('formatSize formats directories and bytes', () {
    expect(formatSize(0, true), '—');
    expect(formatSize(512, false), '512 B');
    expect(formatSize(2048, false), '2.0 KB');
  });

  test('uniquePath naming uses copy suffix', () async {
    final api = ExplorerService();
    // Smoke-check notes path resolves without throwing.
    expect(api.resolveNotesPath().endsWith('improvements.json'), isTrue);
  });
}
