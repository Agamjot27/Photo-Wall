import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:photo_wall/core/images/load_scheduler.dart';

void main() {
  test(
    'never runs more than three jobs and favors urgent queued work',
    () async {
      final scheduler = LoadScheduler();
      final gates = [for (var i = 0; i < 3; i++) Completer<void>()];
      final started = <String>[];
      final initial = [
        for (var i = 0; i < 3; i++)
          scheduler.schedule(() async {
            started.add('initial-$i');
            await gates[i].future;
          }),
      ];
      final normal = scheduler.schedule(() async => started.add('normal'));
      final urgent = scheduler.schedule(
        () async => started.add('urgent'),
        urgent: true,
      );
      expect(scheduler.activeCount, 3);
      expect(scheduler.queuedCount, 2);
      gates[0].complete();
      await initial[0].future;
      await urgent.future;
      expect(started[3], 'urgent');
      gates[1].complete();
      await initial[1].future;
      await normal.future;
      gates[2].complete();
      await initial[2].future;
      expect(scheduler.activeCount, 0);
    },
  );

  test(
    'cancelled queued work never starts and failures release permits',
    () async {
      final scheduler = LoadScheduler(maxActive: 1);
      final gate = Completer<void>();
      final active = scheduler.schedule(() => gate.future);
      var invoked = false;
      final cancelled = scheduler.schedule(() async {
        invoked = true;
      });
      final cancellation = expectLater(
        cancelled.future,
        throwsA(isA<LoadCancelled>()),
      );
      cancelled.cancel();
      await cancellation;
      expect(invoked, isFalse);
      gate.complete();
      await active.future;
      final failed = scheduler.schedule<void>(
        () async => throw StateError('fail'),
      );
      await expectLater(failed.future, throwsStateError);
      expect(scheduler.activeCount, 0);
      expect(scheduler.queuedCount, 0);
    },
  );

  test('newly queued grid work runs before older offscreen work', () async {
    final scheduler = LoadScheduler(maxActive: 1);
    final gate = Completer<void>();
    final started = <String>[];
    final active = scheduler.schedule(() async {
      await gate.future;
    });
    final older = scheduler.schedule(() async => started.add('older'));
    final newer = scheduler.schedule(() async => started.add('newer'));
    gate.complete();
    await Future.wait([active.future, older.future, newer.future]);
    expect(started, ['newer', 'older']);
  });
}
