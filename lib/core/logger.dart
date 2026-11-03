/// Simple structured logger to centralize log formatting and allow
/// future redirection (e.g. Crashlytics, remote aggregation) without
/// touching call sites.  Intentionally minimal now.
///
/// Usage:
///   log.i('cart', 'Merge complete', ctx: {'local': 3, 'remote': 2});
///
/// Keep PII out of context maps; scrub sensitive values before logging.
class Log {
  const Log._();
  static final Log instance = Log._();

  void d(String cat, String msg, {Map<String, Object?>? ctx}) =>
      _emit('DEBUG', cat, msg, ctx);
  void i(String cat, String msg, {Map<String, Object?>? ctx}) =>
      _emit('INFO', cat, msg, ctx);
  void w(String cat, String msg, {Map<String, Object?>? ctx}) =>
      _emit('WARN', cat, msg, ctx);
  void e(
    String cat,
    String msg, {
    Map<String, Object?>? ctx,
    Object? err,
    StackTrace? st,
  }) {
    final m = err != null ? '$msg | err=${err.runtimeType}: $err' : msg;
    _emit('ERROR', cat, m, ctx, st: st);
  }

  void _emit(
    String level,
    String cat,
    String msg,
    Map<String, Object?>? ctx, {
    StackTrace? st,
  }) {
    final ts = DateTime.now().toIso8601String();
    final ctxStr = (ctx == null || ctx.isEmpty)
        ? ''
        : ' ' + ctx.entries.map((e) => '${e.key}=${_fmt(e.value)}').join(' ');
    // Using print keeps it visible in flutter test & run output.
    // Format: 2025-08-22T12:34:56.123Z [LEVEL][cat] message k=v
    // (No trailing newline artifacts.)
    // ignore: avoid_print
    print('$ts [$level][$cat] $msg$ctxStr');
    if (st != null) {
      // ignore: avoid_print
      print(st);
    }
  }

  String _fmt(Object? v) {
    if (v == null) return 'null';
    final s = v.toString();
    if (s.contains(' ')) return '"$s"';
    return s;
  }
}

// Convenience top-level alias
final log = Log.instance;
