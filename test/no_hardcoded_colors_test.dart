import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('No hard-coded Colors.* usages (except Colors.transparent)', () {
    final dir = Directory('lib/src');
    expect(dir.existsSync(), true, reason: 'lib/src must exist');

    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    final blacklisted = <String>[];

    for (final file in files) {
      final content = file.readAsStringSync();
      final regex = RegExp(r'Colors\.[A-Za-z0-9_\[\]\.]+' );
      for (final match in regex.allMatches(content)) {
        final snippet = match.group(0) ?? '';
        // Allow transparent usage
        if (snippet.trim() == 'Colors.transparent') continue;
        blacklisted.add('${file.path}: $snippet');
      }
    }

    expect(blacklisted.isEmpty, true,
        reason: 'Found hard-coded Colors.* in these files:\n${blacklisted.join('\n')}');
  }, skip: false);
}
