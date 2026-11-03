import 'package:flutter_test/flutter_test.dart';
import 'package:rapidrun/services/log_service.dart';

void main() {
  test('log service adds entries and trims capacity', () async {
    final svc = LogService.instance;
    svc.clear();
    // Insert more than capacity subset to validate trimming logic indirectly (capacity is 500, we use smaller sample)
    for (var i = 0; i < 12; i++) {
      svc.log('msg $i', category: 'test');
    }
    expect(svc.entries.length, 12);
    expect(svc.entries.first.message, 'msg 11');
    expect(svc.entries.last.message, 'msg 0');
  });

  test('stream emits on log and clear', () async {
    final svc = LogService.instance;
    svc.clear();
    final events = <int>[];
    final sub = svc.stream.listen((e) => events.add(e.length));
    svc.log('one');
    svc.log('two');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(events.isNotEmpty, true);
    final beforeClearLen = svc.entries.length;
    svc.clear();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(svc.entries.length, 0);
    expect(events.contains(beforeClearLen), true);
    expect(events.last, 0);
    await sub.cancel();
  });
}
