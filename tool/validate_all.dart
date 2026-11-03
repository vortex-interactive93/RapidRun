import 'dart:io';
import 'dart:convert';

/// Unified validation runner.
/// Executes individual validation scripts and aggregates their JSON reports
/// (when present) into a combined summary. Fails fast on first script
/// execution error but still attempts remaining to surface maximum issues.
///
/// Current included validators:
///  - validate_taco_bell_schema.dart
///  - validate_taco_bell_modifiers.dart
///
/// Exit codes from individual scripts are normalized:
///  0 -> success
///  2 -> validation failures
/// any other -> treated as infrastructure error
/// Overall exit code:
///  0 if all succeed without failures
///  2 if any have validation failures
///  1 if infrastructure error occurs (script missing/unexpected code)
Future<void> main(List<String> args) async {
  final validators = <ValidatorConfig>[
    ValidatorConfig(
      name: 'taco_bell_schema',
      command: ['dart', 'run', 'tool/validate_taco_bell_schema.dart'],
      reportPath: 'tool/_schema_validation_report.json',
      failureIndicator: (json) => (json['errorCount'] ?? 0) > 0,
    ),
    ValidatorConfig(
      name: 'taco_bell_modifiers',
      command: ['dart', 'run', 'tool/validate_taco_bell_modifiers.dart'],
      reportPath: 'tool/_modifier_validation_report.json',
      failureIndicator: (json) => (json['redundantGroups'] ?? 0) > 0,
    ),
  ];

  final results = <Map<String, dynamic>>[];
  bool infraError = false;
  bool validationFailure = false;

  for (final v in validators) {
    final res = await _runValidator(v);
    results.add(res);
    if (res['status'] == 'infra_error') infraError = true;
    if (res['status'] == 'validation_failed') validationFailure = true;
  }

  final summary = {
    'validators': results,
    'overallStatus': infraError
        ? 'infra_error'
        : (validationFailure ? 'validation_failed' : 'ok'),
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  };

  final out = File('tool/_validate_all_report.json');
  await out.writeAsString(const JsonEncoder.withIndent('  ').convert(summary));
  stdout.writeln('Unified validation complete -> ${summary['overallStatus']}');
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(summary));

  if (infraError) exit(1);
  if (validationFailure) exit(2);
}

class ValidatorConfig {
  final String name;
  final List<String> command;
  final String reportPath;
  final bool Function(dynamic json) failureIndicator;
  ValidatorConfig({
    required this.name,
    required this.command,
    required this.reportPath,
    required this.failureIndicator,
  });
}

Future<Map<String, dynamic>> _runValidator(ValidatorConfig cfg) async {
  final proc = await Process.start(cfg.command.first, cfg.command.sublist(1));
  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  proc.stdout.transform(utf8.decoder).listen(stdoutBuf.write);
  proc.stderr.transform(utf8.decoder).listen(stderrBuf.write);
  final exitCode = await proc.exitCode;

  dynamic reportJson;
  if (File(cfg.reportPath).existsSync()) {
    try {
      reportJson = jsonDecode(await File(cfg.reportPath).readAsString());
    } catch (e) {
      // ignore parse error; treat as infra problem
    }
  }

  String status;
  if (exitCode == 0) {
    status = 'ok';
  } else if (exitCode == 2) {
    status = 'validation_failed';
  } else {
    status = 'infra_error';
  }
  // Cross-check failure indicator if exit code was 0 but report shows failure.
  if (status == 'ok' &&
      reportJson != null &&
      cfg.failureIndicator(reportJson)) {
    status = 'validation_failed';
  }

  return {
    'name': cfg.name,
    'exitCode': exitCode,
    'status': status,
    'reportFound': reportJson != null,
    if (reportJson != null) 'report': reportJson,
    'stdout': stdoutBuf.toString(),
    'stderr': stderrBuf.toString(),
  };
}
