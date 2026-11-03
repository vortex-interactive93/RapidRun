// dart run tool/validate_names.dart --pretty
// Scans all product JSON assets and reports potential naming quality issues.
import 'dart:convert';
import 'dart:io';
import '../lib/quality/name_validator.dart';

Future<void> main(List<String> args) async {
  final pretty = args.contains('--pretty');
  final root = Directory('assets/stores');
  if (!root.existsSync()) {
    stderr.writeln('assets/stores directory not found');
    exit(1);
  }
  final allProducts = <Map<String, dynamic>>[];
  await for (final f in root.list(recursive: true)) {
    if (f is File &&
        f.path.endsWith('.json') &&
        !f.path.endsWith('.json.bak')) {
      try {
        final raw = await f.readAsString();
        final data = json.decode(raw);
        if (data is List) {
          for (final item in data) {
            if (item is Map<String, dynamic>) {
              allProducts.add(item);
            }
          }
        }
      } catch (e) {
        stderr.writeln('Failed to parse ${f.path}: $e');
      }
    }
  }
  final summary = summarizeProducts(allProducts);
  final jsonOut = formatSummaryAsJson(summary);
  if (pretty) {
    print(jsonOut);
  } else {
    print(json.encode(summary));
  }
  // Simple non-zero exit if high risk issues exceed threshold
  final issues = summary['issues'] as Map<String, dynamic>;
  final highRisk =
      (issues['only_packaging'] ?? 0) + (issues['truncated_vs_original'] ?? 0);
  if (highRisk > 0) {
    stderr.writeln('High risk name issues detected: $highRisk');
  }
}
