import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Color Palette Compliance & Token Enforcement', () {
    test('Zero forbidden blue hexes exist in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final forbiddenHexes = [
        '#1a56db',
        '#2563eb',
        '#1e40af',
        '#3b82f6',
        '#36618e',
        '#9cc2f0',
        '0xff1a56db',
        '0xff2563eb',
        '0xff1e40af',
        '0xff3b82f6',
        '0xff36618e',
        '0xff9cc2f0',
      ];

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      final violations = <String>[];

      for (var file in dartFiles) {
        final content = file.readAsStringSync().toLowerCase();
        for (var hex in forbiddenHexes) {
          if (content.contains(hex)) {
            violations.add('${file.path} contains forbidden blue token $hex');
          }
        }
        if (content.contains('colors.blue')) {
          violations.add('${file.path} contains Colors.blue');
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Found old blue palette tokens in lib/:\n${violations.join('\n')}',
      );
    });

    test(
      'Screens do not contain hard-coded color literals (excluding test/mock widgets)',
      () {
        final screensDir = Directory('lib/screens');
        expect(screensDir.existsSync(), isTrue);

        final screenFiles = screensDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));

        final hardcodedColorRegex = RegExp(r'Color\(0x[0-9a-fA-F]{8}\)');
        final violations = <String>[];

        for (var file in screenFiles) {
          final content = file.readAsStringSync();
          final matches = hardcodedColorRegex.allMatches(content);
          for (var match in matches) {
            violations.add(
              '${file.path} contains hardcoded color: ${match.group(0)}',
            );
          }
        }

        expect(
          violations,
          isEmpty,
          reason:
              'Screens must use AppColors tokens:\n${violations.join('\n')}',
        );
      },
    );
  });
}
