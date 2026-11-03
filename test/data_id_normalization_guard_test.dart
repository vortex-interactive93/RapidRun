import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ID normalization guard (ALDI)', () async {
    // Run the normalization tool in dry-run mode and assert it reports 0 rewrites.
    final script = 'tool/fix_duplicate_product_ids.dart';
    final result = await Process.run('dart', ['run', script], runInShell: true);
    final stdoutStr = result.stdout.toString();
    final stderrStr = result.stderr.toString();
    if (result.exitCode != 0) {
      fail(
        'Normalization script failed (exit ${result.exitCode})\nSTDOUT:\n$stdoutStr\nSTDERR:\n$stderrStr',
      );
    }
    expect(
      stdoutStr.contains('IDs rewritten:     0'),
      true,
      reason:
          'Run: dart run tool/fix_duplicate_product_ids.dart --apply to normalize IDs before committing.\nSTDOUT:\n$stdoutStr',
    );
  });
}
